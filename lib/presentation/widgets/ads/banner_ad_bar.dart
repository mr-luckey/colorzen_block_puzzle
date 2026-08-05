import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:colorzen_block_puzzle/core/constants/admob_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/ad_unit_memory.dart';
import 'package:colorzen_block_puzzle/services/ads_remote_config.dart';
import 'package:colorzen_block_puzzle/services/network_status.dart';

/// Adaptive banner: tries up to 5 unit IDs one-by-one until one loads.
/// Remembers the last working ID and tries it first next time.
/// Offline / timeout → [SizedBox.shrink] (no permanent spinner).
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({
    super.key,
    required this.adsRemoved,
  });

  final bool adsRemoved;

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar>
    with WidgetsBindingObserver {
  final ValueNotifier<BannerAd?> _ad = ValueNotifier(null);
  final ValueNotifier<bool> _failed = ValueNotifier(false);
  var _loading = false;

  static const _adLoadTimeout = Duration(seconds: 8);
  static const _spinnerMax = Duration(seconds: 3);

  Timer? _spinnerCap;

  bool get _bannersAllowed =>
      !widget.adsRemoved && AdsRemoteConfig.instance.bannerAdsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannersAllowed &&
        !_loading &&
        _ad.value == null &&
        !_failed.value) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant BannerAdBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_bannersAllowed) {
      _disposeAd();
      _failed.value = true;
    } else if (widget.adsRemoved != oldWidget.adsRemoved && _bannersAllowed) {
      _failed.value = false;
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // ignore: discarded_futures
    _onResumed();
  }

  Future<void> _onResumed() async {
    await AdsRemoteConfig.instance.refreshIfNeeded();
    if (!mounted) return;
    if (!_bannersAllowed) {
      _disposeAd();
      _failed.value = true;
      return;
    }
    if (_ad.value == null && !_loading) {
      _failed.value = false;
      _load();
    }
  }

  void _armSpinnerCap() {
    _spinnerCap?.cancel();
    _spinnerCap = Timer(_spinnerMax, () {
      if (!mounted) return;
      // Hide loading chrome even if waterfall is still running.
      if (_ad.value == null) {
        _failed.value = true;
      }
    });
  }

  Future<void> _load() async {
    if (!_bannersAllowed || _loading || _ad.value != null) return;
    _loading = true;
    _failed.value = false;

    // No internet → don't show spinner / don't hammer AdMob.
    if (!await hasInternetConnection()) {
      markNetworkOffline();
      if (mounted) _failed.value = true;
      _loading = false;
      return;
    }

    // Ensure SDK is ready (deferred from splash — may still be initializing).
    await sl<AdService>().init();
    if (!mounted || !_bannersAllowed) {
      _loading = false;
      return;
    }

    _armSpinnerCap();

    final width = MediaQuery.sizeOf(context).width.truncate();
    try {
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
        width,
      );
      if (size == null || !mounted) {
        _failed.value = true;
        _loading = false;
        return;
      }

      final ids = AdUnitMemory.bannerOrder(AdMobConstants.bannerIds);
      for (final id in ids) {
        if (!mounted || !_bannersAllowed || _ad.value != null) break;
        if (!await hasInternetConnection()) {
          markNetworkOffline();
          break;
        }

        final completer = Completer<BannerAd?>();
        final banner = BannerAd(
          size: size,
          adUnitId: id,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!completer.isCompleted) completer.complete(ad as BannerAd);
            },
            onAdFailedToLoad: (ad, error) {
              ad.dispose();
              final msg = error.message.toLowerCase();
              if (error.code == 0 ||
                  error.code == 2 ||
                  msg.contains('network') ||
                  msg.contains('internal error') ||
                  msg.contains('unable to resolve') ||
                  msg.contains('unknown host')) {
                markNetworkOffline();
              }
              if (!completer.isCompleted) completer.complete(null);
            },
          ),
        );
        try {
          await banner.load();
        } catch (_) {
          banner.dispose();
          if (!completer.isCompleted) completer.complete(null);
        }

        BannerAd? loaded;
        try {
          loaded = await completer.future.timeout(
            _adLoadTimeout,
            onTimeout: () {
              banner.dispose();
              return null;
            },
          );
        } catch (_) {
          loaded = null;
        }

        if (loaded != null) {
          if (!mounted || !_bannersAllowed) {
            loaded.dispose();
            break;
          }
          // ignore: discarded_futures
          AdUnitMemory.rememberBanner(id);
          _spinnerCap?.cancel();
          _failed.value = false;
          _ad.value = loaded;
          _loading = false;
          return;
        }
      }

      _failed.value = true;
    } catch (_) {
      _failed.value = true;
    }
    _spinnerCap?.cancel();
    _loading = false;
  }

  void _disposeAd() {
    _ad.value?.dispose();
    _ad.value = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _spinnerCap?.cancel();
    _disposeAd();
    _ad.dispose();
    _failed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bannersAllowed) return const SizedBox.shrink();

    return ValueListenableBuilder<BannerAd?>(
      valueListenable: _ad,
      builder: (context, ad, _) {
        if (ad == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: _failed,
            builder: (context, failed, _) {
              // Failed / offline / timed out → collapse (no empty strip).
              if (failed) return const SizedBox.shrink();
              // Brief loader only while a real attempt is in flight.
              return const SizedBox(
                height: 50,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
          );
        }
        return ColoredBox(
          color: Colors.black.withValues(alpha: 0.35),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      },
    );
  }
}
