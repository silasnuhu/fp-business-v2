import 'package:flutter/foundation.dart';
import 'package:whoxa/utils/preference_key/constant/app_config.dart';

/// Picks the ad unit for the current platform and build mode. The IDs
/// themselves (test and real) live in [AppConfig].
class AdConfig {
  AdConfig._();

  /// Banner ad unit for the current platform/build mode, or null if ads are
  /// not supported or the real ID has not been configured yet.
  static String? get bannerAdUnitId => _pick(
    android: AppConfig.androidBannerAdUnitId,
    ios: AppConfig.iosBannerAdUnitId,
    androidTest: AppConfig.androidTestBannerAdUnitId,
    iosTest: AppConfig.iosTestBannerAdUnitId,
  );

  /// Interstitial ad unit (same rules as [bannerAdUnitId]).
  static String? get interstitialAdUnitId => _pick(
    android: AppConfig.androidInterstitialAdUnitId,
    ios: AppConfig.iosInterstitialAdUnitId,
    androidTest: AppConfig.androidTestInterstitialAdUnitId,
    iosTest: AppConfig.iosTestInterstitialAdUnitId,
  );

  static String? _pick({
    required String android,
    required String ios,
    required String androidTest,
    required String iosTest,
  }) {
    final String id;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        id = AppConfig.useTestAds ? androidTest : android;
        break;
      case TargetPlatform.iOS:
        id = AppConfig.useTestAds ? iosTest : ios;
        break;
      default:
        return null;
    }
    return id.startsWith('YOUR_') ? null : id;
  }
}
