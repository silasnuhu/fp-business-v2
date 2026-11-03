import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whoxa/ads/ad_config.dart';
import 'package:whoxa/ads/ad_free_state.dart';
import 'package:whoxa/utils/logger.dart';

/// Preloads a single interstitial and shows it on request. Never throws and
/// never blocks the caller: if no ad is ready, [showIfReady] just returns.
final ConsoleAppLogger _logger = ConsoleAppLogger.forModule(
  'GoogleMobileAdsInterstitial',
);

class InterstitialAdService {
  InterstitialAdService._();
  static final InterstitialAdService instance = InterstitialAdService._();

  InterstitialAd? _ad;
  bool _isLoading = false;

  void load() {
    if (AdFreeState.isAdFree.value) return;
    if (_ad != null || _isLoading) return;
    final adUnitId = AdConfig.interstitialAdUnitId;
    if (adUnitId == null) {
      _logger.e('❌ AdMob Interstitial: no ad unit configured, skipping');
      return;
    }

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _ad = ad;
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _logger.e('❌AdMob Interstitial failed to load: $error');
        },
      ),
    );
  }

  /// Shows the preloaded ad if there is one, then preloads the next.
  /// [onShown] runs once the ad is on screen; [onClosed] runs after it is
  /// dismissed (or failed to show).
  bool showIfReady({VoidCallback? onShown, VoidCallback? onClosed}) {
    if (AdFreeState.isAdFree.value) return false;
    final ad = _ad;
    if (ad == null) {
      load();
      return false;
    }
    _ad = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) => onShown?.call(),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        load();
        onClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logger.e('❌AdMob Interstitial failed to show: $error');
        ad.dispose();
        load();
        onClosed?.call();
      },
    );
    ad.show();
    return true;
  }
}
