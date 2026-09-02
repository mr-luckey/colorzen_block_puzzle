import 'dart:math';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/piece_shapes.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:intl/intl.dart';

enum _ShapeFamily { any, odds, fat }

class PieceGenerator {
  PieceGenerator({Random? random}) : _random = random ?? Random();

  Random _random;
  final List<BlockColor> _recentColors = [];
  final List<int> _recentShapes = [];

  /// Infinite conveyor stream index (1, 2, 3…).
  int _streamIndex = 0;

  /// Next stream index that should carry a bomb (7 or 8 gap).
  late int _nextBombIndex = _firstBombIndex();

  /// Optional board fill 0–1 — fuller board → slightly smaller chunky pieces.
  double _boardFillRatio = 0;

  /// Block Blast-style rectangles: 2×2, 2×3, 2×4, 3×2, 3×3, 4×2, 4×4.
  static const _rect2x2 = 11;
  static const _rect2x3 = 23;
  static const _rect3x2 = 29;
  static const _rect3x3 = 28;
  static const _rect2x4 = 32;
  static const _rect4x2 = 33;
  static const _rect4x4 = 34;

  /// Fat rectangles — don't serve two of these back-to-back.
  static const _fatRects = [
    _rect2x2,
    _rect2x3,
    _rect3x2,
    _rect2x4,
    _rect4x2,
    _rect3x3,
    _rect4x4,
  ];

  /// Everything except giant squares / slabs — L, T, I, tromino, 2-block.
  static const _oddsAndEnds = [
    1, 2, 3, 4, 5, 6, 7, 8, // 2–3 blocks
    9, 10, 12, 13, 14, 15, 16, 17, 18, 19, // tetrominoes (not 2×2)
    20, 21, 22, 24, 25, 26, 27, 30, 31,
  ];

  void setSeed(int seed) {
    _random = Random(seed);
    _resetStream();
  }

  void useSystemRandom() {
    _random = Random();
    _resetStream();
  }

  void _resetStream() {
    _recentColors.clear();
    _recentShapes.clear();
    _streamIndex = 0;
    _nextBombIndex = _firstBombIndex();
  }

  /// Kept for call sites — generator no longer scans the live grid.
  void setBoard(List<List<BlockColor?>> _) {}

  void setBoardFillRatio(double ratio) {
    _boardFillRatio = ratio.clamp(0.0, 1.0);
  }

  /// First bomb appears early on the belt so player sees it without waiting.
  int _firstBombIndex() => 3 + _random.nextInt(2); // 3 or 4

  int _rollBombGap() =>
      AppConstants.bombEveryMin +
      _random.nextInt(
        AppConstants.bombEveryMax - AppConstants.bombEveryMin + 1,
      );

  static int seedFromDate(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return key.hashCode;
  }

  List<Piece> generateSet({int count = 3}) {
    return List.generate(count, (_) => nextConveyorPiece());
  }

  /// Next piece for the horizontal conveyor loop.
  /// Every 7–8 pieces one normal shape also carries a bomb badge.
  ///
  /// Must stay cheap — the tray ticker calls this on vsync.
  Piece nextConveyorPiece() {
    _streamIndex++;
    final withBomb = _streamIndex == _nextBombIndex;
    if (withBomb) {
      _nextBombIndex = _streamIndex + _rollBombGap();
    }

    final base = _generateNormalPiece();
    if (!withBomb) return base;

    return base.copyWith(isBomb: true);
  }

  Piece _generateNormalPiece() {
    int shapeIndex;
    if (_fatStreak >= 2 && _random.nextDouble() < 0.45) {
      shapeIndex = _pickWeighted(forceFamily: _ShapeFamily.odds);
    } else {
      shapeIndex = _pickWeighted();
    }

    if (_wasRecent(shapeIndex, lookback: 1)) {
      shapeIndex = _pickWeighted(
        forceFamily: _fatRects.contains(shapeIndex)
            ? _ShapeFamily.odds
            : _ShapeFamily.any,
      );
    }

    final color = _pickColor();
    _recentShapes.add(shapeIndex);
    _recentColors.add(color);
    if (_recentShapes.length > 12) {
      _recentShapes.removeAt(0);
    }
    if (_recentColors.length > 9) {
      _recentColors.removeAt(0);
    }
    return Piece(
      shape: kPieceShapes[shapeIndex]
          .map((r) => List<bool>.from(r))
          .toList(),
      color: color,
      shapeIndex: shapeIndex,
      id: _streamIndex,
    );
  }

  int get _fatStreak {
    var n = 0;
    for (var i = _recentShapes.length - 1; i >= 0; i--) {
      if (!_fatRects.contains(_recentShapes[i])) break;
      n++;
    }
    return n;
  }

  bool _wasRecent(int shapeIndex, {int lookback = 2}) {
    if (_recentShapes.isEmpty) return false;
    final start = max(0, _recentShapes.length - lookback);
    return _recentShapes.sublist(start).contains(shapeIndex);
  }

  /// Weighted bag over the full shape library — true random mix.
  int _pickWeighted({_ShapeFamily forceFamily = _ShapeFamily.any}) {
    var total = 0;
    final weights = <int, int>{};
    for (var i = 0; i < kPieceShapes.length; i++) {
      var w = i < kShapeWeights.length ? kShapeWeights[i] : 4;
      switch (forceFamily) {
        case _ShapeFamily.odds:
          if (_fatRects.contains(i)) w = 0;
          break;
        case _ShapeFamily.fat:
          if (!_fatRects.contains(i)) w = (w * 0.25).round();
          break;
        case _ShapeFamily.any:
          break;
      }
      if (forceFamily == _ShapeFamily.any &&
          _fatStreak >= 2 &&
          _fatRects.contains(i)) {
        w = (w * 0.55).round();
      }
      // Sparse board → slightly more 2×2 / 3×3 / 4×4 to set up empties.
      if (_boardFillRatio < 0.32 && _fatRects.contains(i)) {
        w = (w * 1.35).round();
      }
      if (w <= 0) continue;
      weights[i] = w;
      total += w;
    }
    if (total <= 0) {
      return _oddsAndEnds[_random.nextInt(_oddsAndEnds.length)];
    }
    var tick = _random.nextInt(total);
    for (final e in weights.entries) {
      tick -= e.value;
      if (tick < 0) return e.key;
    }
    return _oddsAndEnds.first;
  }

  BlockColor _pickColor() {
    if (_recentColors.length >= 8) {
      final missing = BlockColor.values
          .where((c) => !_recentColors.contains(c))
          .toList();
      if (missing.isNotEmpty) {
        return missing[_random.nextInt(missing.length)];
      }
    }
    return BlockColor.values[_random.nextInt(BlockColor.values.length)];
  }
}
