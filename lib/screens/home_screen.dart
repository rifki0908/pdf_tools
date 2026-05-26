import 'package:flutter/material.dart';

import 'image_to_pdf.dart';
import 'merge_pdf.dart';
import 'split_pdf.dart';
import 'compress_pdf.dart';
import 'pdf_to_image.dart';
import 'pdf_to_word.dart';
import 'word_to_pdf.dart';
import 'lock_pdf.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _open(BuildContext context, Widget destination) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Tools',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _ToolCard(
            icon: Icons.merge_type,
            label: 'Merge PDF',
            color: Colors.green,
            onTap: () => _open(context, const MergePdfScreen()),
          ),
          _ToolCard(
            icon: Icons.call_split,
            label: 'Split PDF',
            color: Colors.purple,
            onTap: () => _open(context, const SplitPdfScreen()),
          ),
          _ToolCard(
            icon: Icons.compress,
            label: 'Compress PDF',
            color: Colors.orange,
            onTap: () => _open(context, const CompressPdfScreen()),
          ),
          _ToolCard(
            icon: Icons.image,
            label: 'PDF to Image',
            color: Colors.teal,
            onTap: () => _open(context, const PdfToImageScreen()),
          ),
          _ToolCard(
            icon: Icons.photo_library,
            label: 'Image to PDF',
            color: Colors.blue,
            onTap: () => _open(context, const ImageToPdfScreen()),
          ),
          _ToolCard(
            icon: Icons.description,
            label: 'PDF to Word',
            color: Colors.indigo,
            onTap: () => _open(context, const PdfToWordScreen()),
          ),
          _ToolCard(
            icon: Icons.text_snippet,
            label: 'Word to PDF',
            color: Colors.brown,
            onTap: () => _open(context, const WordToPdfScreen()),
          ),
          _ToolCard(
            icon: Icons.lock,
            label: 'Lock PDF',
            color: Colors.redAccent,
            onTap: () => _open(context, const LockPdfScreen()),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
