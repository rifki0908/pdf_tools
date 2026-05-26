import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class CompressPdfScreen extends StatefulWidget {
  const CompressPdfScreen({super.key});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  File? _input;
  bool _busy = false;
  String? _resultPath;
  int? _originalBytes;
  int? _compressedBytes;
  CompressionLevel _level = CompressionLevel.medium;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    setState(() {
      _input = file;
      _originalBytes = file.lengthSync();
      _resultPath = null;
      _compressedBytes = null;
    });
  }

  Future<void> _compress() async {
    final input = _input;
    if (input == null) return;
    setState(() => _busy = true);
    try {
      final out = await PdfService.compressPdf(input, level: _level);
      final outFile = File(out);
      if (!mounted) return;
      setState(() {
        _resultPath = out;
        _compressedBytes = outFile.lengthSync();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Compressed: ${out.split('/').last}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final reduction = (_originalBytes != null && _compressedBytes != null)
        ? (1 - _compressedBytes! / _originalBytes!) * 100
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 64,
                            color: _input == null ? Colors.grey : Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _input == null
                                ? 'No file selected'
                                : _input!.path.split('/').last,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (_originalBytes != null) ...[
                            const SizedBox(height: 4),
                            Text('Original: ${_fmtSize(_originalBytes!)}'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Compression Level',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<CompressionLevel>(
                    segments: const [
                      ButtonSegment(
                        value: CompressionLevel.low,
                        label: Text('Low'),
                        icon: Icon(Icons.high_quality),
                      ),
                      ButtonSegment(
                        value: CompressionLevel.medium,
                        label: Text('Medium'),
                        icon: Icon(Icons.tune),
                      ),
                      ButtonSegment(
                        value: CompressionLevel.high,
                        label: Text('High'),
                        icon: Icon(Icons.compress),
                      ),
                    ],
                    selected: {_level},
                    onSelectionChanged: _busy
                        ? null
                        : (s) => setState(() => _level = s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _levelDescription(_level),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (_resultPath != null && _compressedBytes != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 48,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Compressed: ${_fmtSize(_compressedBytes!)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (reduction != null && reduction > 0)
                              Text(
                                'Reduced by ${reduction.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                ),
                              )
                            else
                              const Text(
                                'No size reduction (already optimized).',
                                style: TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open'),
                                    onPressed: () =>
                                        OpenFilex.open(_resultPath!),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.share),
                                    label: const Text('Share'),
                                    onPressed: () => Share.shareXFiles(
                                      [XFile(_resultPath!)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Pick PDF'),
                    onPressed: _busy ? null : _pickPdf,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.compress),
                    label: const Text('Compress'),
                    onPressed: _busy || _input == null ? null : _compress,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _levelDescription(CompressionLevel level) {
    switch (level) {
      case CompressionLevel.low:
        return 'Fastest. Mild compression. Best quality.';
      case CompressionLevel.medium:
        return 'Balanced compression and quality. Recommended.';
      case CompressionLevel.high:
        return 'Maximum compression. Slower. May reduce image quality.';
    }
  }
}
