import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

enum CompressionLevel { low, medium, high }

class PdfService {
  /// Convert images into a single PDF (one image per page, fitted to page).
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
    final outDir = await _outputDir();
    final outPath =
        '${outDir.path}/images_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(outPath);
    await file.writeAsBytes(await doc.save());
    return outPath;
  }

  /// Merge multiple PDFs in order using Syncfusion's PdfDocument.
  static Future<String> mergePdfs(List<File> pdfs) async {
    final merged = sf.PdfDocument();
    // Syncfusion's PdfDocumentBase requires removing the default empty page.
    // The freshly created PdfDocument has zero pages, so this is fine.
    for (final f in pdfs) {
      final source = sf.PdfDocument(inputBytes: await f.readAsBytes());
      sf.PdfDocumentBase.merge(merged, [source]);
      source.dispose();
    }
    final bytes = await merged.save();
    merged.dispose();
    final outDir = await _outputDir();
    final outPath =
        '${outDir.path}/merged_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(outPath);
    await file.writeAsBytes(bytes);
    return outPath;
  }

  /// Compress a PDF using Syncfusion's compression + image downsampling.
  ///
  /// The Syncfusion library handles content-stream compression automatically.
  /// We additionally walk every page and re-encode raster images at lower
  /// quality to actually shrink the file.
  static Future<String> compressPdf(
    File input, {
    CompressionLevel level = CompressionLevel.medium,
  }) async {
    final original = await input.readAsBytes();
    final doc = sf.PdfDocument(inputBytes: original);

    // Set compression policy. Syncfusion will use Flate on content streams.
    doc.compressionLevel = sf.PdfCompressionLevel.best;
    if (level == CompressionLevel.high) {
      doc.compressionLevel = sf.PdfCompressionLevel.best;
    } else if (level == CompressionLevel.medium) {
      doc.compressionLevel = sf.PdfCompressionLevel.normal;
    } else {
      doc.compressionLevel = sf.PdfCompressionLevel.normal;
    }

    final imgQuality = switch (level) {
      CompressionLevel.low => 88,
      CompressionLevel.medium => 65,
      CompressionLevel.high => 40,
    };
    final maxLongEdge = switch (level) {
      CompressionLevel.low => 1800,
      CompressionLevel.medium => 1280,
      CompressionLevel.high => 960,
    };

    // Re-encode embedded images on every page.
    for (var i = 0; i < doc.pages.count; i++) {
      final page = doc.pages[i];
      final extractor = sf.PdfImageExtractor(doc);
      final extracted = extractor.extractImages(i);
      if (extracted == null || extracted.isEmpty) continue;

      // Replace each image with a compressed JPEG.
      // Note: Syncfusion's image-replace API is index-based per page.
      for (var j = 0; j < extracted.length; j++) {
        try {
          final src = img.decodeImage(extracted[j]);
          if (src == null) continue;
          final resized = (src.width > src.height && src.width > maxLongEdge)
              ? img.copyResize(src, width: maxLongEdge)
              : (src.height > maxLongEdge
                  ? img.copyResize(src, height: maxLongEdge)
                  : src);
          final encoded = Uint8List.fromList(
            img.encodeJpg(resized, quality: imgQuality),
          );
          page.replaceImage(j, sf.PdfBitmap(encoded));
        } catch (_) {
          // Some image types (e.g. masked indexed images) are not replaceable;
          // skip them and let stream compression do what it can.
        }
      }
    }

    final bytes = await doc.save();
    doc.dispose();

    final outDir = await _outputDir();
    final outPath =
        '${outDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final outFile = File(outPath);
    // If our pass produced a LARGER file than the original (rare, but possible
    // for already-optimized PDFs), keep the original to avoid bloat.
    final finalBytes = bytes.length < original.length ? bytes : original;
    await outFile.writeAsBytes(finalBytes);
    return outPath;
  }

  static Future<Directory> _outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory('${base.path}/PdfTools');
    if (!await out.exists()) await out.create(recursive: true);
    return out;
  }
}
