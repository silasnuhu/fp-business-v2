import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:whoxa/ads/ad_config.dart';
import 'package:whoxa/ads/ad_free_state.dart';
import 'package:whoxa/utils/logger.dart';

/// Anchored adaptive banner. Loads once for the lifetime of its State and
/// collapses to zero height while loading or if the ad fails.
final ConsoleAppLogger _logger = ConsoleAppLogger.forModule('GoogleMobileAds');

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  /// Height currently occupied by the banner (0 while loading/failed). Lets
  /// screens that float widgets above the bottom nav (e.g. the AI FAB) stay
  /// clear of the ad.
  static final ValueNotifier<double> heightNotifier = ValueNotifier<double>(0);

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  AdSize? _loadedSize;
  bool _loadStarted = false;

  // "No fill" is usually transient, so retry with a growing delay.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 20),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 300),
  ];
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    AdFreeState.isAdFree.addListener(_onAdFreeChanged);
  }

  /// Premium users: drop the ad right away. Ad-free ended: load again.
  void _onAdFreeChanged() {
    if (!mounted) return;
    if (AdFreeState.isAdFree.value) {
      _retryTimer?.cancel();
      _bannerAd?.dispose();
      BannerAdWidget.heightNotifier.value = 0;
      setState(() {
        _bannerAd = null;
        _isLoaded = false;
      });
    } else if (_bannerAd == null) {
      _retryCount = 0;
      _loadAd();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs MediaQuery for the width, so it can't live in initState.
    if (!_loadStarted) {
      _loadStarted = true;
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (AdFreeState.isAdFree.value) return;
    final adUnitId = AdConfig.bannerAdUnitId;
    if (adUnitId == null) {
      _logger.e('❌AdMob Banner: no ad unit configured, skipping');
      return;
    }

    try {
      final width = MediaQuery.of(context).size.width.truncate();
      // Standard anchored adaptive (50-90dp). The "large" variant can be up
      // to 15% of the screen height and gets far fewer fills.
      final orientation = MediaQuery.of(context).orientation;
      // ignore: deprecated_member_use
      final size = await AdSize.getAnchoredAdaptiveBannerAdSize(
        orientation,
        width,
      );
      if (!mounted) return;
      if (size == null) {
        _logger.e('❌AdMob Banner: unable to get adaptive banner size');
        return;
      }

      final ad = BannerAd(
        adUnitId: adUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) async {
            if (!mounted) {
              ad.dispose();
              return;
            }
            // The creative can be shorter than the requested size; use the
            // real size so no empty strip is left above the tab bar.
            final platformSize = await (ad as BannerAd).getPlatformAdSize();
            if (!mounted) return;
            setState(() {
              _loadedSize = platformSize ?? size;
              _isLoaded = true;
            });
            BannerAdWidget.heightNotifier.value =
                (_loadedSize ?? size).height.toDouble();
          },
          onAdFailedToLoad: (ad, error) {
            _logger.e('❌AdMob Banner failed to load: $error');
            ad.dispose();
            BannerAdWidget.heightNotifier.value = 0;
            if (mounted) {
              setState(() {
                _bannerAd = null;
                _isLoaded = false;
              });
              _scheduleRetry();
            }
          },
        ),
      );
      _bannerAd = ad;
      await ad.load();
    } catch (e) {
      _logger.e('❌AdMob Banner error: $e');
    }
  }

  void _scheduleRetry() {
    if (_retryCount >= _retryDelays.length) return;
    final delay = _retryDelays[_retryCount++];
    _logger.e('❌AdMob Banner: retrying in ${delay.inSeconds}s');
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (mounted) _loadAd();
    });
  }

  @override
  void dispose() {
    AdFreeState.isAdFree.removeListener(_onAdFreeChanged);
    _retryTimer?.cancel();
    _bannerAd?.dispose();
    // Deferred: listeners must not rebuild while the tree is being torn down.
    scheduleMicrotask(() => BannerAdWidget.heightNotifier.value = 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (AdFreeState.isAdFree.value || !_isLoaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: (_loadedSize ?? ad.size).width.toDouble(),
      height: (_loadedSize ?? ad.size).height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
