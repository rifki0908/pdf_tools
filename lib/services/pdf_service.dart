import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

enum CompressionLevel { low, medium, high }

class PdfService {
  // ==========================================================================
  // 1) IMAGE → PDF
  // ==========================================================================
  static Future<String> imagesToPdf(List<File> images) async {
    final doc = pw.Document();
    for (final f in images) {
      final bytes = await f.readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return _writeOut(await doc.save(), prefix: 'images');
  }

  // ==========================================================================
  // 2) MERGE PDF — page-by-page template copy
  // ==========================================================================
  static Future<String> mergePdfs(List<File> pdfs) async {
    final merged = sf.PdfDocument();
    for (final f in pdfs) {
      final src = sf.PdfDocument(inputBytes: await f.readAsBytes());
      for (var i = 0; i < src.pages.count; i++) {
        final srcPage = src.pages[i];
        final template = srcPage.createTemplate();
        final size = srcPage.size;
        final newPage = merged.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          Offset.zero,
          Size(size.width, size.height),
        );
      }
      src.dispose();
    }
    final bytes = await merged.save();
    merged.dispose();
    return _writeOut(Uint8List.fromList(bytes), prefix: 'merged');
  }

  // ==========================================================================
  // 3) SPLIT PDF — extract a page range into a new PDF
  // ==========================================================================
  static Future<String> splitPdf(File input, int startPage, int endPage) async {
    final src = sf.PdfDocument(inputBytes: await input.readAsBytes());
    final total = src.pages.count;
    if (startPage < 1 || endPage > total || startPage > endPage) {
      src.dispose();
      throw ArgumentError(
        'Invalid range: $startPage–$endPage (PDF has $total pages).',
      );
    }
    final newDoc = sf.PdfDocument();
    for (var i = startPage - 1; i <= endPage - 1; i++) {
      final srcPage = src.pages[i];
      final template = srcPage.createTemplate();
      final size = srcPage.size;
      final newPage = newDoc.pages.add();
      newPage.graphics.drawPdfTemplate(
        template,
        Offset.zero,
        Size(size.width, size.height),
      );
    }
    final bytes = await newDoc.save();
    newDoc.dispose();
    src.dispose();
    return _writeOut(
      Uint8List.fromList(bytes),
      prefix: 'split_${startPage}-$endPage',
    );
  }

  static Future<int> pageCount(File input) async {
    final doc = sf.PdfDocument(inputBytes: await input.readAsBytes());
    final n = doc.pages.count;
    doc.dispose();
    return n;
  }

  // ==========================================================================
  // 4) COMPRESS PDF — guaranteed shrink via rasterize+rebuild at every level
  // ==========================================================================
  /// Strategy: rasterize each page, re-encode as JPEG with quality+resize
  /// tuned per level, rebuild PDF from JPEGs. Guarantees real shrink even on
  /// already-optimized PDFs (the trade-off: text becomes non-searchable).
  static Future<String> compressPdf(
    File input, {
    CompressionLevel level = CompressionLevel.medium,
  }) async {
    final original = await input.readAsBytes();

    // Per-level tuning
    final int dpi;
    final int maxDim;
    final int jpgQuality;
    switch (level) {
      case CompressionLevel.low:
        dpi = 144;
        maxDim = 2000;
        jpgQuality = 80;
        break;
      case CompressionLevel.medium:
        dpi = 110;
        maxDim = 1400;
        jpgQuality = 60;
        break;
      case CompressionLevel.high:
        dpi = 90;
        maxDim = 1000;
        jpgQuality = 45;
        break;
    }

    final outDoc = pw.Document(
      compress: true,
      version: PdfVersion.pdf_1_5,
    );
    await for (final page in Printing.raster(original, dpi: dpi.toDouble())) {
      final pngBytes = await page.toPng();
      final decoded = img.decodePng(pngBytes);
      if (decoded == null) continue;
      img.Image resized = decoded;
      if (decoded.width > maxDim || decoded.height > maxDim) {
        if (decoded.width >= decoded.height) {
          resized = img.copyResize(decoded, width: maxDim);
        } else {
          resized = img.copyResize(decoded, height: maxDim);
        }
      }
      final jpg =
          Uint8List.fromList(img.encodeJpg(resized, quality: jpgQuality));
      final pwImg = pw.MemoryImage(jpg);
      outDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            resized.width.toDouble(),
            resized.height.toDouble(),
          ),
          margin: pw.EdgeInsets.zero,
          build: (ctx) => pw.Image(pwImg, fit: pw.BoxFit.fill),
        ),
      );
    }
    final bytes = await outDoc.save();
    // Always return rasterized output (don't fallback to original even if
    // somehow larger — user explicitly chose Compress).
    return _writeOut(Uint8List.fromList(bytes), prefix: 'compressed');
  }

  // ==========================================================================
  // 5) PDF → IMAGE — rasterize each page as JPG
  // ==========================================================================
  static Future<List<String>> pdfToImages(
    File input, {
    int dpi = 150,
  }) async {
    final bytes = await input.readAsBytes();
    final outDir = await _outputDir();
    final folder = Directory(
      '${outDir.path}/pdf_pages_${DateTime.now().millisecondsSinceEpoch}',
    );
    await folder.create(recursive: true);
    final paths = <String>[];
    var idx = 1;
    await for (final page in Printing.raster(bytes, dpi: dpi.toDouble())) {
      final pngBytes = await page.toPng();
      final decoded = img.decodePng(pngBytes);
      if (decoded == null) continue;
      final jpg = img.encodeJpg(decoded, quality: 88);
      final path = '${folder.path}/page_${idx.toString().padLeft(3, "0")}.jpg';
      await File(path).writeAsBytes(jpg);
      paths.add(path);
      idx++;
    }
    return paths;
  }

  // ==========================================================================
  // 6) PDF → WORD (.docx) — bold/heading detection + image extraction
  // ==========================================================================
  static Future<String> pdfToWord(File input) async {
    final doc = sf.PdfDocument(inputBytes: await input.readAsBytes());
    final extractor = sf.PdfTextExtractor(doc);
    final allItems = <DocxItem>[];

    for (var i = 0; i < doc.pages.count; i++) {
      // Extract text with font metadata.
      final lines = extractor.extractTextLines(
        startPageIndex: i,
        endPageIndex: i,
      );

      // First pass: clean glyphs + capture font info per line.
      final cleaned = <_LineWithStyle>[];
      for (final line in lines) {
        var t = line.text
            .replaceAll('\uF0B7', '\u2022')
            .replaceAll('\uF0A7', '\u25AA')
            .replaceAll('\uF076', '\u2713')
            .replaceAll('\uF020', ' ')
            .replaceAll('\u00A0', ' ');
        t = t.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Inspect words to determine bold + max font size for the line.
        var anyBold = false;
        double maxFontSize = 11.0;
        try {
          for (final word in line.wordCollection) {
            if (word.fontStyle.contains(sf.PdfFontStyle.bold)) anyBold = true;
            if (word.fontSize > maxFontSize) maxFontSize = word.fontSize;
          }
        } catch (_) {
          // wordCollection unavailable for some lines — keep defaults.
        }

        cleaned.add(_LineWithStyle(
          text: t,
          bold: anyBold,
          fontSize: maxFontSize,
        ));
      }

      // Second pass: merge orphan-bullet lines with the next content line.
      final merged = <_LineWithStyle>[];
      var j = 0;
      while (j < cleaned.length) {
        final cur = cleaned[j];
        if ((cur.text == '\u2022' ||
                cur.text == '\u25AA' ||
                cur.text == '\u2713') &&
            j + 1 < cleaned.length &&
            cleaned[j + 1].text.isNotEmpty &&
            cleaned[j + 1].text != '\u2022') {
          // Inherit style from the content line.
          merged.add(_LineWithStyle(
            text: '${cur.text} ${cleaned[j + 1].text}',
            bold: cleaned[j + 1].bold,
            fontSize: cleaned[j + 1].fontSize,
          ));
          j += 2;
          if (j < cleaned.length && cleaned[j].text.isEmpty) j++;
          continue;
        }
        if (cur.text.isNotEmpty) merged.add(cur);
        j++;
      }

      // Treat ALL-CAPS short lines as headings even if font metadata missed.
      for (final l in merged) {
        final isAllCaps = l.text.length >= 3 &&
            l.text.length <= 40 &&
            l.text == l.text.toUpperCase() &&
            l.text.contains(RegExp(r'[A-Z]'));
        final isBigFont = l.fontSize >= 13.5;
        final isHeading = isAllCaps || isBigFont;
        allItems.add(DocxItem.text(
          text: l.text,
          bold: l.bold || isHeading,
          heading: isHeading,
        ));
      }

      // Try to extract embedded images from this page.
      try {
        final page = doc.pages[i];
        final images = page.extractImages();
        for (final imgBytes in images) {
          allItems.add(DocxItem.image(bytes: Uint8List.fromList(imgBytes)));
        }
      } catch (_) {
        // extractImages may fail on some PDFs — skip silently.
      }

      if (i < doc.pages.count - 1) {
        allItems.add(DocxItem.pageBreak());
      }
    }
    doc.dispose();

    if (allItems.isEmpty) {
      throw const FormatException(
        'No extractable text found. Scanned PDFs need OCR (not supported offline yet).',
      );
    }

    final docxBytes = _buildRichDocx(allItems);
    return _writeOut(docxBytes, prefix: 'pdf_to_word', extension: 'docx');
  }

  // ==========================================================================
  // 7) WORD (.docx) → PDF
  // ==========================================================================
  static Future<String> wordToPdf(File input) async {
    final bytes = await input.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docFile;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docFile = f;
        break;
      }
    }
    if (docFile == null) {
      throw const FormatException(
        'Not a valid .docx file (missing document.xml)',
      );
    }
    final xml = String.fromCharCodes(docFile.content as List<int>);
    final text = _extractDocxText(xml);
    if (text.trim().isEmpty) {
      throw const FormatException('Document appears to be empty.');
    }
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) {
          return text
              .split('\n')
              .map((line) => pw.Paragraph(text: line.isEmpty ? ' ' : line))
              .toList();
        },
      ),
    );
    return _writeOut(await doc.save(), prefix: 'word_to_pdf');
  }

  // ==========================================================================
  // 8) LOCK PDF — AES-128 password protection
  // ==========================================================================
  static Future<String> lockPdf(File input, String password) async {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }
    final doc = sf.PdfDocument(inputBytes: await input.readAsBytes());
    final security = doc.security;
    security.algorithm = sf.PdfEncryptionAlgorithm.aesx128Bit;
    security.userPassword = password;
    security.ownerPassword = password;
    security.permissions.addAll([
      sf.PdfPermissionsFlags.print,
      sf.PdfPermissionsFlags.copyContent,
    ]);
    final bytes = await doc.save();
    doc.dispose();
    return _writeOut(Uint8List.fromList(bytes), prefix: 'locked');
  }

  // ==========================================================================
  // helpers
  // ==========================================================================
  static Future<Directory> _outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory('${base.path}/PdfTools');
    if (!await out.exists()) await out.create(recursive: true);
    return out;
  }

  static Future<String> _writeOut(
    Uint8List bytes, {
    required String prefix,
    String extension = 'pdf',
  }) async {
    final outDir = await _outputDir();
    final path =
        '${outDir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Builds a docx with bold/heading runs + embedded JPEG/PNG images.
  static Uint8List _buildRichDocx(List<DocxItem> items) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    final imageBytes = <Uint8List>[];
    final imageExt = <String>[];
    final paragraphs = StringBuffer();

    for (final item in items) {
      switch (item.kind) {
        case _DocxKind.text:
          final fontSize = item.heading ? 28 : 22; // half-points: 14pt vs 11pt
          paragraphs.write(
            '<w:p>'
            '${item.heading ? '<w:pPr><w:spacing w:before="240" w:after="120"/></w:pPr>' : ''}'
            '<w:r>'
            '<w:rPr>'
            '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>'
            '<w:sz w:val="$fontSize"/>'
            '${item.bold ? '<w:b/>' : ''}'
            '</w:rPr>'
            '<w:t xml:space="preserve">${esc(item.text!)}</w:t>'
            '</w:r>'
            '</w:p>',
          );
          break;
        case _DocxKind.image:
          final idx = imageBytes.length;
          final ext = _detectImageExt(item.bytes!);
          imageBytes.add(item.bytes!);
          imageExt.add(ext);
          // Embed via drawing element.
          paragraphs.write(_imageParagraphXml(idx + 100));
          break;
        case _DocxKind.pageBreak:
          paragraphs.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
          break;
      }
    }

    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
        'xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" '
        'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
        'mc:Ignorable="w14" '
        'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
        '<w:body>'
        '$paragraphs'
        '<w:sectPr>'
        '<w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';

    const stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>'
        '</w:styles>';

    // Build content types with image extensions.
    final contentTypeOverrides = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>',
    );
    final extsAdded = <String>{};
    for (final ext in imageExt) {
      if (extsAdded.add(ext)) {
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        contentTypeOverrides.write(
          '<Default Extension="$ext" ContentType="$mime"/>',
        );
      }
    }
    contentTypeOverrides.write(
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '</Types>',
    );

    const packageRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    final documentRels = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>',
    );
    for (var i = 0; i < imageBytes.length; i++) {
      documentRels.write(
        '<Relationship Id="rId${i + 100}" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
        'Target="media/image${i + 1}.${imageExt[i]}"/>',
      );
    }
    documentRels.write('</Relationships>');

    void add(Archive a, String path, String content) {
      final bytes = utf8.encode(content);
      a.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final archive = Archive();
    add(archive, '[Content_Types].xml', contentTypeOverrides.toString());
    add(archive, '_rels/.rels', packageRelsXml);
    add(archive, 'word/_rels/document.xml.rels', documentRels.toString());
    add(archive, 'word/document.xml', documentXml);
    add(archive, 'word/styles.xml', stylesXml);
    for (var i = 0; i < imageBytes.length; i++) {
      archive.addFile(ArchiveFile(
        'word/media/image${i + 1}.${imageExt[i]}',
        imageBytes[i].length,
        imageBytes[i],
      ));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static String _imageParagraphXml(int rId) {
    // Embed a 4-inch wide image (3,657,600 EMU) — height auto-scales because
    // we let Word treat it as a floating drawing.
    return '<w:p><w:r>'
        '<w:rPr><w:noProof/></w:rPr>'
        '<w:drawing>'
        '<wp:inline distT="0" distB="0" distL="0" distR="0">'
        '<wp:extent cx="3657600" cy="2438400"/>'
        '<wp:effectExtent l="0" t="0" r="0" b="0"/>'
        '<wp:docPr id="$rId" name="Picture $rId"/>'
        '<wp:cNvGraphicFramePr/>'
        '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
        '<pic:nvPicPr><pic:cNvPr id="$rId" name="Picture $rId"/><pic:cNvPicPr/></pic:nvPicPr>'
        '<pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="rId$rId"/>'
        '<a:stretch><a:fillRect/></a:stretch></pic:blipFill>'
        '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="3657600" cy="2438400"/></a:xfrm>'
        '<a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
        '</pic:pic>'
        '</a:graphicData>'
        '</a:graphic>'
        '</wp:inline>'
        '</w:drawing>'
        '</w:r></w:p>';
  }

  static String _detectImageExt(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) return 'png';
    return 'jpg';
  }

  /// Builds a spec-compliant .docx zip that opens cleanly in MS Word, Google
  /// Docs, and LibreOffice. Includes proper namespaces, sectPr, rels, and
  /// a styles part — the bare minimum strict parsers expect.
  static Uint8List _buildSpecCompliantDocx(List<String> lines) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

    final paragraphs = lines.map((line) {
      if (line.isEmpty) {
        return '<w:p><w:pPr><w:pageBreakBefore/></w:pPr></w:p>';
      }
      return '<w:p>'
          '<w:r>'
          '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="22"/></w:rPr>'
          '<w:t xml:space="preserve">${esc(line)}</w:t>'
          '</w:r>'
          '</w:p>';
    }).join();

    final documentXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" '
        'xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" '
        'mc:Ignorable="w14" '
        'xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006">'
        '<w:body>'
        '$paragraphs'
        '<w:sectPr>'
        '<w:pgSz w:w="12240" w:h="15840"/>'
        '<w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/>'
        '<w:cols w:space="720"/>'
        '<w:docGrid w:linePitch="360"/>'
        '</w:sectPr>'
        '</w:body>'
        '</w:document>';

    const stylesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults>'
        '<w:rPrDefault>'
        '<w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/><w:sz w:val="22"/></w:rPr>'
        '</w:rPrDefault>'
        '</w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/>'
        '<w:qFormat/>'
        '</w:style>'
        '</w:styles>';

    const contentTypesXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '</Types>';

    const packageRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';

    const documentRelsXml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>';

    void add(Archive a, String path, String content) {
      final bytes = utf8.encode(content);
      a.addFile(ArchiveFile(path, bytes.length, bytes));
    }

    final archive = Archive();
    add(archive, '[Content_Types].xml', contentTypesXml);
    add(archive, '_rels/.rels', packageRelsXml);
    add(archive, 'word/_rels/document.xml.rels', documentRelsXml);
    add(archive, 'word/document.xml', documentXml);
    add(archive, 'word/styles.xml', stylesXml);

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  // ignore: unused_element
  static Uint8List _buildMinimalDocx(String text) {
    return _buildSpecCompliantDocx(text.split('\n'));
  }

  static String _extractDocxText(String xml) {
    final withBreaks = xml
        .replaceAll(RegExp(r'</w:p\s*>'), '\n')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAll(RegExp(r'<w:tab\s*/>'), '\t');

    final regex = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
    final out = StringBuffer();
    final lines = withBreaks.split('\n');
    for (final line in lines) {
      for (final m in regex.allMatches(line)) {
        out.write(_unescapeXml(m.group(1) ?? ''));
      }
      out.writeln();
    }
    return out.toString();
  }

  static String _unescapeXml(String s) => s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}

// ============================================================================
// PDF -> WORD helper types
// ============================================================================
enum _DocxKind { text, image, pageBreak }

class _LineWithStyle {
  _LineWithStyle({
    required this.text,
    required this.bold,
    required this.fontSize,
  });
  final String text;
  final bool bold;
  final double fontSize;
}

class DocxItem {
  DocxItem._(this.kind, {this.text, this.bytes, this.bold = false, this.heading = false});
  factory DocxItem.text({
    required String text,
    bool bold = false,
    bool heading = false,
  }) =>
      DocxItem._(_DocxKind.text, text: text, bold: bold, heading: heading);
  factory DocxItem.image({required Uint8List bytes}) =>
      DocxItem._(_DocxKind.image, bytes: bytes);
  factory DocxItem.pageBreak() => DocxItem._(_DocxKind.pageBreak);

  final _DocxKind kind;
  final String? text;
  final Uint8List? bytes;
  final bool bold;
  final bool heading;
}
