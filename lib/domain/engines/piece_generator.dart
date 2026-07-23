import 'dart:math';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/piece_shapes.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:intl/intl.dart';

class PieceGenerator {
  PieceGenerator({Random? random}) : _random = random ?? Random();

  Random _random;
  final List<BlockColor> _recentColors = [];
  final List<int> _recentShapes = [];

  /// Infinite conveyor stream index (1, 2, 3…).
  int _streamIndex = 0;

  /// Next stream index that should carry a bomb (7 or 8 gap).
  late int _nextBombIndex = _firstBombIndex();

  static const _smallShapeIndices = [0, 1, 2, 3, 4, 5, 6, 7, 8];

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
  Piece nextConveyorPiece() {
    _streamIndex++;
    final withBomb = _streamIndex == _nextBombIndex;
    if (withBomb) {
      _nextBombIndex = _streamIndex + _rollBombGap();
    }

    final base = _generateNormalPiece();
    if (!withBomb) return base;

    // Same random shape — only one cell is the bomb when placed.
    return base.copyWith(isBomb: true);
  }

  Piece _generateNormalPiece() {
    final shapeIndex = _random.nextDouble() < 0.28
        ? _pickFrom(_smallShapeIndices)
        : _pickShape();
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

  int _pickFrom(List<int> indices) {
    final weights = indices.map((i) {
      if (i == 0) return 40;
      if (i <= 2) return 28;
      return 22;
    }).toList();
    final total = weights.fold<int>(0, (a, b) => a + b);
    var roll = _random.nextInt(total);
    for (var i = 0; i < indices.length; i++) {
      roll -= weights[i];
      if (roll < 0) return indices[i];
    }
    return indices.first;
  }

  int _pickShape() {
    assert(kShapeWeights.length == kPieceShapes.length);
    final weights = List<int>.from(kShapeWeights);
    for (var i = 0; i < weights.length; i++) {
      final count = _recentShapes.where((s) => s == i).length;
      if (count >= 2) {
        weights[i] = i == 0 ? (weights[i] ~/ 3) : 0;
      }
    }
    final total = weights.fold<int>(0, (a, b) => a + b);
    if (total <= 0) {
      return _random.nextInt(kPieceShapes.length);
    }
    var roll = _random.nextInt(total);
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return 0;
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
