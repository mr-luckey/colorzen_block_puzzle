import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:colorzen_block_puzzle/core/config/ads_config.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/ads_remote_config.dart';

/// One on-screen banner placement. Collapses on no-fill. Disposes on leave.
class BannerAdBar extends StatefulWidget {
  const BannerAdBar({
    super.key,
    required this.adsRemoved,
    this.placement = AdsPlacements.home,
  });

  final bool adsRemoved;
  final String placement;

  @override
  State<BannerAdBar> createState() => _BannerAdBarState();
}

class _BannerAdBarState extends State<BannerAdBar> with WidgetsBindingObserver {
  BannerAd? _ad;
  var _loading = false;

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
    if (_bannersAllowed && !_loading && _ad == null) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant BannerAdBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_bannersAllowed) {
      _disposeAd();
    } else if (widget.adsRemoved != oldWidget.adsRemoved ||
        widget.placement != oldWidget.placement) {
      _disposeAd();
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
      return;
    }
    if (_ad == null && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!_bannersAllowed || _loading || _ad != null) return;
    _loading = true;

    await sl<AdService>().init();
    if (!mounted || !_bannersAllowed) {
      _loading = false;
      return;
    }

    final width = MediaQuery.sizeOf(context).width.truncate();
    try {
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (size == null || !mounted) {
        _loading = false;
        return;
      }

      final loaded = await sl<AdService>().loadBanner(
        placement: widget.placement,
        size: size,
      );
      if (!mounted || !_bannersAllowed) {
        loaded?.dispose();
        _loading = false;
        return;
      }
      setState(() {
        _ad = loaded;
        _loading = false;
      });
    } catch (_) {
      _loading = false;
    }
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_bannersAllowed) return const SizedBox.shrink();
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
