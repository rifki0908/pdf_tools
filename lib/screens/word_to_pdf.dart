import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class WordToPdfScreen extends StatefulWidget {
  const WordToPdfScreen({super.key});

  @override
  State<WordToPdfScreen> createState() => _WordToPdfScreenState();
}

class _WordToPdfScreenState extends State<WordToPdfScreen> {
  File? _input;
  bool _busy = false;
  String? _resultPath;

  Future<void> _pickDocx() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (r == null || r.files.single.path == null) return;
    setState(() {
      _input = File(r.files.single.path!);
      _resultPath = null;
    });
  }

  Future<void> _convert() async {
    if (_input == null) return;
    setState(() => _busy = true);
    try {
      final out = await PdfService.wordToPdf(_input!);
      if (!mounted) return;
      setState(() => _resultPath = out);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${out.split('/').last}')),
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
      appBar: AppBar(title: const Text('Word to PDF')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Only .docx files are supported. Text-only conversion. Layout, images, and rich formatting are not preserved.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.text_snippet,
                              size: 64,
                              color: _input == null
                                  ? Colors.grey
                                  : Colors.brown),
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
                        ],
                      ),
                    ),
                  ),
                  if (_resultPath != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.green.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 48, color: Colors.green),
                            const SizedBox(height: 8),
                            Text(_resultPath!.split('/').last,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
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
                                        [XFile(_resultPath!)]),
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
                    label: const Text('Pick .docx'),
                    onPressed: _busy ? null : _pickDocx,
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
                        : const Icon(Icons.picture_as_pdf),
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
