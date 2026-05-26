import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'image_to_pdf.dart';
import 'merge_pdf.dart';
import 'compress_pdf.dart';
import '../widgets/banner_ad_widget.dart';
import '../services/ads_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InterstitialAd? _interstitial;

  @override
  void initState() {
    super.initState();
    AdsService.loadInterstitial(
      onLoaded: (ad) => setState(() => _interstitial = ad),
    );
  }

  @override
  void dispose() {
    _interstitial?.dispose();
    super.dispose();
  }

  void _open(Widget destination) {
    final ad = _interstitial;
    if (ad != null) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitial = null;
          AdsService.loadInterstitial(
            onLoaded: (next) => setState(() => _interstitial = next),
          );
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => destination),
            );
          }
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          _interstitial = null;
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => destination),
            );
          }
        },
      );
      ad.show();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => destination),
      );
    }
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
      body: Column(
        children: [
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _ToolCard(
                  icon: Icons.image,
                  label: 'Image to PDF',
                  color: Colors.blue,
                  onTap: () => _open(const ImageToPdfScreen()),
                ),
                _ToolCard(
                  icon: Icons.merge_type,
                  label: 'Merge PDF',
                  color: Colors.green,
                  onTap: () => _open(const MergePdfScreen()),
                ),
                _ToolCard(
                  icon: Icons.compress,
                  label: 'Compress PDF',
                  color: Colors.orange,
                  onTap: () => _open(const CompressPdfScreen()),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 56, color: color),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
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
