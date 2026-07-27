import 'dart:math' as math;

import 'package:hive_flutter/hive_flutter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/hive_constants.dart';

/// Random in-app review prompts while the user is playing.
abstract class ReviewService {
  /// Bump launch counter (call once per cold start).
  Future<void> recordAppOpen();

  /// Whether a soft "rate us" dialog should show right now.
  Future<bool> shouldShowPrompt();

  /// Mark that the prompt was shown (starts cooldown).
  Future<void> markPromptShown();

  /// User chose "Never" — stop asking.
  Future<void> markDeclinedForever();

  /// User chose to rate — open Play review UI / store listing.
  Future<void> requestReview();
}

class InAppReviewService implements ReviewService {
  InAppReviewService({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;
  final InAppReview _inAppReview = InAppReview.instance;

  static const _keyLastPromptMs = 'last_prompt_ms';
  static const _keyDeclined = 'declined_forever';
  static const _keyRated = 'rated';
  static const _keyLaunchCount = 'launch_count';

  /// Don't ask again for this many days after a soft dismiss.
  static const _cooldownDays = 5;

  /// Chance to show when eligible (while using the app).
  static const _showChance = 0.28;

  /// Wait until the user has opened the app a few times.
  static const _minLaunches = 3;

  Box<dynamic> get _box => Hive.box(HiveBoxNames.engagement);

  @override
  Future<void> recordAppOpen() async {
    final count = (_box.get(_keyLaunchCount) as int?) ?? 0;
    await _box.put(_keyLaunchCount, count + 1);
  }

  @override
  Future<bool> shouldShowPrompt() async {
    if (_box.get(_keyDeclined) == true || _box.get(_keyRated) == true) {
      return false;
    }

    final launches = (_box.get(_keyLaunchCount) as int?) ?? 0;
    if (launches < _minLaunches) return false;

    final lastMs = _box.get(_keyLastPromptMs) as int?;
    if (lastMs != null) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
      if (elapsed < Duration(days: _cooldownDays).inMilliseconds) {
        return false;
      }
    }

    return _random.nextDouble() < _showChance;
  }

  @override
  Future<void> markPromptShown() async {
    await _box.put(
      _keyLastPromptMs,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  Future<void> markDeclinedForever() async {
    await _box.put(_keyDeclined, true);
    await markPromptShown();
  }

  @override
  Future<void> requestReview() async {
    await _box.put(_keyRated, true);
    await markPromptShown();
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        return;
      }
    } catch (_) {
      // Fall through to store listing.
    }
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=${AppConstants.packageId}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
