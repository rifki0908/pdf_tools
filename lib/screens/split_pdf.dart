import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  File? _input;
  int? _pageCount;
  bool _busy = false;
  String? _resultPath;
  final _startCtrl = TextEditingController(text: '1');
  final _endCtrl = TextEditingController(text: '1');

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (r == null || r.files.single.path == null) return;
    final f = File(r.files.single.path!);
    final n = await PdfService.pageCount(f);
    setState(() {
      _input = f;
      _pageCount = n;
      _startCtrl.text = '1';
      _endCtrl.text = n.toString();
      _resultPath = null;
    });
  }

  Future<void> _split() async {
    if (_input == null || _pageCount == null) return;
    final start = int.tryParse(_startCtrl.text);
    final end = int.tryParse(_endCtrl.text);
    if (start == null || end == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Invalid page numbers')));
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await PdfService.splitPdf(_input!, start, end);
      if (!mounted) return;
      setState(() => _resultPath = out);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved: ${out.split('/').last}')));
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
      appBar: AppBar(title: const Text('Split PDF')),
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
                          Icon(Icons.call_split,
                              size: 64,
                              color: _input == null
                                  ? Colors.grey
                                  : Colors.purple),
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
                          if (_pageCount != null) ...[
                            const SizedBox(height: 4),
                            Text('Total pages: $_pageCount'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_pageCount != null) ...[
                    const SizedBox(height: 16),
                    const Text('Page Range',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'From',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'To',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
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
                            const Text('Split successful',
                                style: TextStyle(fontWeight: FontWeight.bold)),
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
                        : const Icon(Icons.call_split),
                    label: const Text('Split'),
                    onPressed:
                        _busy || _input == null ? null : _split,
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
