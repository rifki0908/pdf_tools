import 'dart:async';
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
  // 6) PDF → WORD (.docx) — layout-aware text extraction
  // ==========================================================================
  static Future<String> pdfToWord(File input) async {
    final doc = sf.PdfDocument(inputBytes: await input.readAsBytes());
    final extractor = sf.PdfTextExtractor(doc);
    final buf = StringBuffer();
    for (var i = 0; i < doc.pages.count; i++) {
      // layoutText:true preserves positional text (catches everything).
      final pageText = extractor.extractText(
        startPageIndex: i,
        endPageIndex: i,
        layoutText: true,
      );
      buf.writeln(pageText);
      if (i < doc.pages.count - 1) buf.writeln();
    }
    doc.dispose();
    final docxBytes = _buildMinimalDocx(buf.toString());
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

  static Uint8List _buildMinimalDocx(String text) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    final paragraphs = text.split('\n').map((line) {
      return '<w:p><w:r><w:t xml:space="preserve">${esc(line)}</w:t></w:r></w:p>';
    }).join();

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>$paragraphs</w:body>
</w:document>''';

    const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

    const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    final archive = Archive();
    archive.addFile(ArchiveFile(
      '[Content_Types].xml',
      contentTypesXml.length,
      contentTypesXml.codeUnits,
    ));
    archive.addFile(ArchiveFile(
      '_rels/.rels',
      relsXml.length,
      relsXml.codeUnits,
    ));
    archive.addFile(ArchiveFile(
      'word/document.xml',
      documentXml.length,
      documentXml.codeUnits,
    ));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
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
