import 'dart:io';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized AdMob unit IDs.
///
/// During development we use Google's official TEST IDs so ads always render
/// without violating policy. Replace with your real AdMob unit IDs before
/// publishing to Play Store / App Store.
class AdsService {
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

  static void loadInterstitial({
    required void Function(InterstitialAd) onLoaded,
  }) {
    InterstitialAd.load(
      adUnitId: interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: onLoaded,
        onAdFailedToLoad: (_) {},
      ),
    );
  }
}
