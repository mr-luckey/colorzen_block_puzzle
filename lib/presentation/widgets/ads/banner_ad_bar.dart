import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:colorzen_block_puzzle/core/constants/admob_constants.dart';
import 'package:colorzen_block_puzzle/services/ad_unit_memory.dart';

/// Adaptive banner: tries up to 5 unit IDs one-by-one until one loads.
/// Remembers the last working ID and tries it first next time.
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({
    super.key,
    required this.adsRemoved,
  });

  final bool adsRemoved;

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> {
  final ValueNotifier<BannerAd?> _ad = ValueNotifier(null);
  final ValueNotifier<bool> _failed = ValueNotifier(false);
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.adsRemoved &&
        !_loading &&
        _ad.value == null &&
        !_failed.value) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant BannerAdBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adsRemoved && !oldWidget.adsRemoved) {
      _disposeAd();
    } else if (!widget.adsRemoved && oldWidget.adsRemoved) {
      _failed.value = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (widget.adsRemoved || _loading || _ad.value != null) return;
    _loading = true;
    _failed.value = false;
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
        if (!mounted || widget.adsRemoved || _ad.value != null) break;

        final completer = Completer<BannerAd?>();
        final banner = BannerAd(
          size: size,
          adUnitId: id,
          request: const AdRequest(),
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!completer.isCompleted) completer.complete(ad as BannerAd);
            },
            onAdFailedToLoad: (ad, _) {
              ad.dispose();
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

        final loaded = await completer.future;
        if (loaded != null) {
          if (!mounted || widget.adsRemoved) {
            loaded.dispose();
            break;
          }
          // ignore: discarded_futures
          AdUnitMemory.rememberBanner(id);
          _ad.value = loaded;
          _loading = false;
          return;
        }
      }

      _failed.value = true;
    } catch (_) {
      _failed.value = true;
    }
    _loading = false;
  }

  void _disposeAd() {
    _ad.value?.dispose();
    _ad.value = null;
  }

  @override
  void dispose() {
    _disposeAd();
    _ad.dispose();
    _failed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.adsRemoved) return const SizedBox.shrink();

    return ValueListenableBuilder<BannerAd?>(
      valueListenable: _ad,
      builder: (context, ad, _) {
        if (ad == null) {
          return ValueListenableBuilder<bool>(
            valueListenable: _failed,
            builder: (context, failed, _) {
              if (failed) return const SizedBox.shrink();
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
