import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob with safe init guard.
///
/// During development we use Google's official TEST IDs so ads always render
/// without violating policy. Replace with your real AdMob unit IDs before
/// publishing to Play Store / App Store.
class AdsService {
  static bool _initialized = false;
  static bool _initializing = false;

  static Future<void> ensureInitialized() async {
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
    } catch (e) {
      debugPrint('AdMob init failed: $e');
    } finally {
      _initializing = false;
    }
  }

  static String get bannerUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716';
    }
    return '';
  }

  static String get interstitialUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    return '';
  }

  static Future<void> loadInterstitial({
    required void Function(InterstitialAd) onLoaded,
  }) async {
    await ensureInitialized();
    if (!_initialized) return;
    try {
      InterstitialAd.load(
        adUnitId: interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: onLoaded,
          onAdFailedToLoad: (e) => debugPrint('Interstitial fail: $e'),
        ),
      );
    } catch (e) {
      debugPrint('Interstitial load threw: $e');
    }
  }
}
