import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';
import '../widgets/banner_ad_widget.dart';

class MergePdfScreen extends StatefulWidget {
  const MergePdfScreen({super.key});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  final List<File> _pdfs = [];
  bool _busy = false;
  String? _resultPath;

  Future<void> _pickPdfs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null) return;
    setState(() {
      _pdfs.addAll(
        result.paths.where((p) => p != null).map((p) => File(p!)),
      );
    });
  }

  Future<void> _merge() async {
    if (_pdfs.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least 2 PDFs to merge.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final outPath = await PdfService.mergePdfs(_pdfs);
      if (!mounted) return;
      setState(() => _resultPath = outPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Merged: ${outPath.split('/').last}')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merge PDF')),
      body: Column(
        children: [
          Expanded(
            child: _pdfs.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Tap "Add PDFs" to select.\nDrag to reorder. Then tap Merge.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _pdfs.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _pdfs.removeAt(oldIndex);
                        _pdfs.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _pdfs[index];
                      return Card(
                        key: ValueKey(file.path),
                        child: ListTile(
                          leading: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.red,
                            size: 32,
                          ),
                          title: Text(
                            file.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Position ${index + 1}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _pdfs.removeAt(index));
                                },
                              ),
                              const Icon(Icons.drag_handle),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_resultPath != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                      onPressed: () => OpenFilex.open(_resultPath!),
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
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add PDFs'),
                    onPressed: _busy ? null : _pickPdfs,
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
                        : const Icon(Icons.merge_type),
                    label: const Text('Merge'),
                    onPressed: _busy || _pdfs.length < 2 ? null : _merge,
                  ),
                ),
              ],
            ),
          ),
          const BannerAdWidget(),
        ],
      ),
    );
  }
}
