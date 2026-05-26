import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class LockPdfScreen extends StatefulWidget {
  const LockPdfScreen({super.key});

  @override
  State<LockPdfScreen> createState() => _LockPdfScreenState();
}

class _LockPdfScreenState extends State<LockPdfScreen> {
  File? _input;
  bool _busy = false;
  bool _obscure = true;
  String? _resultPath;
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (r == null || r.files.single.path == null) return;
    setState(() {
      _input = File(r.files.single.path!);
      _resultPath = null;
    });
  }

  Future<void> _lock() async {
    if (_input == null) return;
    final pw = _pwCtrl.text.trim();
    final confirm = _pwConfirmCtrl.text.trim();
    if (pw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password required')));
      return;
    }
    if (pw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _busy = true);
    try {
      final out = await PdfService.lockPdf(_input!, pw);
      if (!mounted) return;
      setState(() => _resultPath = out);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Locked: ${out.split('/').last}')),
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
      appBar: AppBar(title: const Text('Lock PDF')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.lock,
                              size: 64,
                              color: _input == null
                                  ? Colors.grey
                                  : Colors.redAccent),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pwCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pwConfirmCtrl,
                    obscureText: _obscure,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.amber.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'If you forget this password, the PDF cannot be recovered. AES-128 encryption.',
                              style: TextStyle(fontSize: 12),
                            ),
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
                        : const Icon(Icons.lock),
                    label: const Text('Lock'),
                    onPressed: _busy || _input == null ? null : _lock,
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
