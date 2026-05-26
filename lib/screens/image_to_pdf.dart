import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../services/pdf_service.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});

  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  String? _resultPath;

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.map((x) => File(x.path))));
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _busy = true);
    try {
      final outPath = await PdfService.imagesToPdf(_images);
      if (!mounted) return;
      setState(() => _resultPath = outPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF saved: ${outPath.split('/').last}')),
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
      appBar: AppBar(title: const Text('Image to PDF')),
      body: Column(
        children: [
          Expanded(
            child: _images.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Tap "Add Images" to select photos.\nThey will be combined into one PDF.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _images.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (newIndex > oldIndex) newIndex -= 1;
                        final item = _images.removeAt(oldIndex);
                        _images.insert(newIndex, item);
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = _images[index];
                      return Card(
                        key: ValueKey(file.path),
                        child: ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              file,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            file.path.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('Page ${index + 1}'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setState(() => _images.removeAt(index));
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
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Images'),
                    onPressed: _busy ? null : _pickImages,
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
                        : const Icon(Icons.picture_as_pdf),
                    label: const Text('Convert'),
                    onPressed: _busy || _images.isEmpty ? null : _convert,
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
