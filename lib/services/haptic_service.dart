import 'package:flutter/services.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

abstract class HapticService {
  void light();
  void medium();
  void heavy();
  void selection();
  void invalidShake();
}

class FlutterHapticService implements HapticService {
  FlutterHapticService({required this.settingsProvider});

  final AppSettings Function() settingsProvider;

  bool get _enabled => settingsProvider().hapticEnabled;

  @override
  void light() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  @override
  void medium() {
    if (_enabled) HapticFeedback.mediumImpact();
  }

  @override
  void heavy() {
    if (_enabled) HapticFeedback.heavyImpact();
  }

  @override
  void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  @override
  void invalidShake() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (_enabled) HapticFeedback.selectionClick();
    });
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (_enabled) HapticFeedback.selectionClick();
    });
  }
}
