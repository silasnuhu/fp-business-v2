import 'package:flutter/foundation.dart';

/// Local developer switch for the demo-login experience (prefilled demo
/// phone number on the login screen + demo OTP on the OTP screen).
///
/// This is independent of the remote `demo_credential` project-config flag
/// (see `ProjectConfigRepository`) — the NEW backend's `/settings` endpoint
/// doesn't send that field yet, so `demoCredential` stays `false` in
/// practice. Flip [isDemo] to `false` before a production release.
class AppConfig {
  AppConfig._();

  static const bool isDemo = false;

  // ── Google AdMob ad unit IDs ──────────────────────────────────────────
  // Used by `lib/ads/ad_config.dart`. Debug/profile builds use the *test*
  // IDs, release builds use the *real* IDs (see [useTestAds]).

  /// True in debug/profile, false in release. Never serve real ads while
  /// developing — clicking your own real ads can get the account banned.
  static bool get useTestAds => !kReleaseMode;

  // Real (production) ad units — replace the iOS placeholders when ready.
  static const String androidBannerAdUnitId =
      'ca-app-pub-6670291550647945/7920409468';
  static const String iosBannerAdUnitId =
      'ca-app-pub-6670291550647945/2803814158';
  static const String androidInterstitialAdUnitId =
      'ca-app-pub-6670291550647945/8547009706';
  static const String iosInterstitialAdUnitId =
      'ca-app-pub-6670291550647945/6543662895';

  // Google's official test ad units.
  static const String androidTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/9214589741';
  static const String iosTestBannerAdUnitId =
      'ca-app-pub-3940256099942544/2435281174';
  static const String androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  /// Credentials shown/prefilled by the demo-login UI on the login & OTP
  /// screens. Kept here as the single source of truth so the UI and the
  /// demo-account detection below can't drift apart.
  static const String demoCountryCode = "+1";
  static const String demoPhoneNumber = "2025551001";

  /// The NEW backend has no server-side "demo account" concept (no
  /// `is_demo` field on the user), so this is the only signal we have:
  /// treat a login as a demo account when the number entered matches the
  /// demo credentials shown on the login screen. Digits-only comparison
  /// so formatting differences (spaces, dashes, leading "+") don't matter.
  static bool isDemoLogin(String countryCode, String phoneNumber) {
    String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly(phoneNumber) == digitsOnly(demoPhoneNumber) &&
        digitsOnly(countryCode) == digitsOnly(demoCountryCode);
  }
}
