class ScoreCalculator {
  static int baseForLines(int lines) {
    if (lines <= 0) return 0;
    return switch (lines) {
      1 => 100,
      2 => 300,
      3 => 600,
      4 => 1200,
      5 => 1800,
      6 => 2800,
      7 => 4000,
      8 => 5500,
      _ => 8000 + (lines - 9).clamp(0, 12) * 800,
    };
  }

  /// [colorBonusFlags] length must equal lines cleared.
  /// Combo applies when consecutiveClearMoves >= 3 (after this clear).
  static int calculate({
    required int linesCleared,
    required List<bool> colorBonusFlags,
    required int consecutiveClearMovesAfter,
    required bool scoringEnabled,
    double modeMultiplier = 1.0,
  }) {
    if (!scoringEnabled || linesCleared <= 0) return 0;

    final base = baseForLines(linesCleared);
    final share = base / linesCleared;
    var sum = 0.0;
    for (var i = 0; i < linesCleared; i++) {
      final bonus = i < colorBonusFlags.length && colorBonusFlags[i];
      sum += share * (bonus ? 2.0 : 1.0);
    }

    final comboActive = consecutiveClearMovesAfter >= 3;
    final multiplier = (comboActive ? 1.5 : 1.0) * modeMultiplier;
    return (sum * multiplier).round();
  }
}
