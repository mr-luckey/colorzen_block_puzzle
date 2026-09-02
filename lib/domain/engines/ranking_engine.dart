import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Move-driven survival ranking helpers.
class RankingEngine {
  /// Max idle gap that still counts toward survive time between two moves.
  /// Standing still longer than this does NOT grow ranking time.
  static const maxActiveGapMs = 12000;

  static int tickActiveSurvive({
    required int previousActiveMs,
    required int? lastMoveEpochMs,
    required int nowMs,
  }) {
    if (lastMoveEpochMs == null) return previousActiveMs;
    final gap = nowMs - lastMoveEpochMs;
    if (gap <= 0) return previousActiveMs;
    final credited = gap > maxActiveGapMs ? maxActiveGapMs : gap;
    return previousActiveMs + credited;
  }

  static MovePraise praiseFor({
    required int linesCleared,
    required int consecutiveClearMoves,
    required bool hadColorBonus,
    required int scoreGained,
    bool allClear = false,
  }) {
    if (allClear) return MovePraise.allClear;
    if (linesCleared <= 0 && scoreGained <= 0) return MovePraise.none;
    if (linesCleared >= 6 || consecutiveClearMoves >= 5) {
      return MovePraise.legendary;
    }
    if (linesCleared >= 4) return MovePraise.legendary;
    if (consecutiveClearMoves >= 3 || linesCleared >= 3 || hadColorBonus) {
      return MovePraise.awesome;
    }
    if (linesCleared >= 2) return MovePraise.great;
    if (linesCleared >= 1) return MovePraise.nice;
    return MovePraise.none;
  }

  static String praiseLabel(MovePraise praise) => switch (praise) {
        MovePraise.none => '',
        MovePraise.nice => 'NICE!',
        MovePraise.great => 'GREAT!',
        MovePraise.awesome => 'AWESOME!',
        MovePraise.legendary => 'LEGENDARY!',
        MovePraise.allClear => 'ALL CLEAR!',
      };

  /// Block Blast-style line-count shout for 4 / 6 / 9 bursts.
  static String lineCountLabel(int lines) {
    if (lines >= 9) return '9 LINES!';
    if (lines >= 6) return '$lines LINES!';
    if (lines >= 4) return '$lines LINES!';
    return '';
  }

  static String bigClearTitle(int lines, {required bool allClear}) {
    if (allClear) return 'ALL CLEAR!';
    return switch (lines) {
      4 => 'FANTASTIC!',
      5 => 'INCREDIBLE!',
      6 => 'UNBELIEVABLE!',
      7 => 'OUTSTANDING!',
      8 => 'SENSATIONAL!',
      _ when lines >= 9 => 'PERFECT!',
      _ => '',
    };
  }

  static RankTier tierFor({
    required int movesMade,
    required int activeSurviveMs,
  }) {
    final points = movesMade * 100 + (activeSurviveMs ~/ 1000);
    if (points >= 8000) return RankTier.legend;
    if (points >= 4000) return RankTier.champion;
    if (points >= 1800) return RankTier.survivor;
    if (points >= 600) return RankTier.climber;
    return RankTier.rookie;
  }

  static String tierLabel(RankTier tier) => switch (tier) {
        RankTier.rookie => 'Rookie',
        RankTier.climber => 'Climber',
        RankTier.survivor => 'Survivor',
        RankTier.champion => 'Champion',
        RankTier.legend => 'Legend',
      };

  static String formatSurvive(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    if (m <= 0) return '${s}s';
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  static RankingBoard insertRun(RankingBoard board, RankingEntry entry) {
    final next = [...board.entries, entry]
      ..sort((a, b) {
        final byPoints = b.rankPoints.compareTo(a.rankPoints);
        if (byPoints != 0) return byPoints;
        final byMoves = b.movesMade.compareTo(a.movesMade);
        if (byMoves != 0) return byMoves;
        return b.activeSurviveMs.compareTo(a.activeSurviveMs);
      });
    return RankingBoard(entries: next.take(30).toList());
  }
}
