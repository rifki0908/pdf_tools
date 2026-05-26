import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  File? _input;
  bool _busy = false;
  List<String> _imagePaths = [];

  Future<void> _pickPdf() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (r == null || r.files.single.path == null) return;
    setState(() {
      _input = File(r.files.single.path!);
      _imagePaths = [];
    });
  }

  Future<void> _convert() async {
    if (_input == null) return;
    setState(() => _busy = true);
    try {
      final paths = await PdfService.pdfToImages(_input!);
      if (!mounted) return;
      setState(() => _imagePaths = paths);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated ${paths.length} images')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Image')),
      body: Column(
        children: [
          Expanded(
            child: _imagePaths.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.picture_as_pdf,
                            size: 80,
                            color:
                                _input == null ? Colors.grey : Colors.teal,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _input == null
                                ? 'No PDF selected'
                                : _input!.path.split('/').last,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Each page becomes one JPG image.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _imagePaths.length,
                    itemBuilder: (ctx, i) {
                      final p = _imagePaths[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => OpenFilex.open(p),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.file(File(p), fit: BoxFit.cover),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  color: Colors.black54,
                                  child: Text(
                                    'Page ${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_imagePaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: Text('Share all (${_imagePaths.length} images)'),
                onPressed: () => Share.shareXFiles(
                  _imagePaths.map((p) => XFile(p)).toList(),
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
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.image),
                    label: const Text('Convert'),
                    onPressed:
                        _busy || _input == null ? null : _convert,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
