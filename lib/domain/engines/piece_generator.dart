import 'dart:math';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/constants/piece_shapes.dart';
import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
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

  /// Snapshot of the live board — used to pick line-clearing shapes.
  List<List<BlockColor?>>? _board;

  /// Optional board fill 0–1 — fuller board → more small pieces.
  double _boardFillRatio = 0;

  /// Small / gap-fitters — prefer these over bulky 4s & 6s.
  static const _gapFitters = [0, 1, 2, 3, 4, 5, 6, 7, 8];
  static const _smallWide = [0, 1, 3, 5, 6, 7, 8];
  static const _wideTwo = [1];
  static const _square2x2 = [11];
  static const _rect2x3 = [23];
  static const _wideFour = [9, 11, 12, 18, 19];
  static const _wideSix = [23, 30];
  static const _tallRare = [2, 4, 10, 29, 31];

  /// Shapes tried for clear-assist, ordered small → medium (skip huge fillers).
  static const _assistShapes = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, // 1–3 blocks
    9, 10, 11, 12, 18, 19, // useful 4s (I, O, T, S/Z)
    13, 14, 15, 16, 17, // L/J tetrominoes
    23, 30, 29, 31, // 6s only when gap is large
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

  /// Keep generator aware of the current board for clear-assist picks.
  void setBoard(List<List<BlockColor?>> grid) {
    _board = grid.map((r) => List<BlockColor?>.from(r)).toList();
  }

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
    // Ultimate goal: give the shape that completes a near-full line ASAP.
    // Bulky 4/6 fillers are secondary — they pack the board without clears.
    final assistChance = _assistProbability();
    int? shapeIndex;
    if (_random.nextDouble() < assistChance) {
      shapeIndex = _pickClearAssistShape();
    }
    shapeIndex ??= _pickFallbackShape();

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

  /// Higher when board has near-complete lines; lower on empty board.
  double _assistProbability() {
    if (_board == null || _boardFillRatio < 0.05) return 0.15;
    final near = _nearCompleteLines();
    if (near.isEmpty) {
      // Sparse board — light assist / mostly variety.
      return _boardFillRatio > 0.25 ? 0.35 : 0.20;
    }
    final closest = near.first.emptyCount;
    if (closest <= 2) return 0.88; // almost done — hand the missing shape
    if (closest <= 3) return 0.78;
    if (closest <= 4) return 0.65;
    return 0.45;
  }

  /// Pick a shape that can clear at least one near-complete row/col.
  /// Prefers the fewest-empty lines and the smallest fitting shapes.
  int? _pickClearAssistShape() {
    final grid = _board;
    if (grid == null) return null;

    final lines = _nearCompleteLines();
    if (lines.isEmpty) return _pickProgressFiller(grid);

    final clearing = <int>[];
    // Focus on the closest 5 lines so we don't stall scanning.
    for (final line in lines.take(5)) {
      for (final shapeIndex in _assistShapes) {
        final blocks = _blockCount(shapeIndex);
        // Skip oversized pieces for tiny gaps — they fill without helping.
        if (blocks > line.emptyCount + 2) continue;
        // Huge 6-blocks only when gap is genuinely large.
        if (blocks >= 6 && line.emptyCount < 4) continue;

        if (_shapeClearsLine(grid, shapeIndex, line)) {
          clearing.add(shapeIndex);
        }
      }
      if (clearing.isNotEmpty) break; // serve the neediest line first
    }

    if (clearing.isEmpty) return _pickProgressFiller(grid);

    // Prefer smaller shapes among those that clear.
    clearing.sort((a, b) => _blockCount(a).compareTo(_blockCount(b)));
    final bestSize = _blockCount(clearing.first);
    final best = clearing.where((i) => _blockCount(i) <= bestSize + 1).toList();
    return best[_random.nextInt(best.length)];
  }

  /// No immediate clear — drop a small piece that fills cells on the
  /// neediest near-line so the next assist can finish it.
  int? _pickProgressFiller(List<List<BlockColor?>> grid) {
    final lines = _nearCompleteLines();
    if (lines.isEmpty) return null;
    final line = lines.first;
    final fits = <int>[];
    for (final shapeIndex in _gapFitters) {
      if (_shapeTouchesLine(grid, shapeIndex, line)) {
        fits.add(shapeIndex);
      }
    }
    if (fits.isEmpty) return null;
    return fits[_random.nextInt(fits.length)];
  }

  List<_NearLine> _nearCompleteLines() {
    final grid = _board;
    if (grid == null) return const [];
    final n = AppConstants.gridSize;
    final lines = <_NearLine>[];

    for (var r = 0; r < n; r++) {
      var empty = 0;
      for (var c = 0; c < n; c++) {
        if (grid[r][c] == null) empty++;
      }
      // 1–5 empties = worth assisting; 0 = already full (shouldn't happen).
      if (empty >= 1 && empty <= 5) {
        lines.add(_NearLine(isRow: true, index: r, emptyCount: empty));
      }
    }
    for (var c = 0; c < n; c++) {
      var empty = 0;
      for (var r = 0; r < n; r++) {
        if (grid[r][c] == null) empty++;
      }
      if (empty >= 1 && empty <= 5) {
        lines.add(_NearLine(isRow: false, index: c, emptyCount: empty));
      }
    }

    lines.sort((a, b) => a.emptyCount.compareTo(b.emptyCount));
    return lines;
  }

  bool _shapeClearsLine(
    List<List<BlockColor?>> grid,
    int shapeIndex,
    _NearLine line,
  ) {
    final piece = _tempPiece(shapeIndex);
    final n = AppConstants.gridSize;
    final maxR = n - piece.rows;
    final maxC = n - piece.cols;
    if (maxR < 0 || maxC < 0) return false;

    for (var r = 0; r <= maxR; r++) {
      for (var c = 0; c <= maxC; c++) {
        // Skip placements that don't touch this line.
        if (!_placementTouchesLine(piece, r, c, line)) continue;
        if (!GameEngine.canPlace(grid, piece, r, c)) continue;
        final (rows, cols) =
            LineClearEngine.wouldClearAfterPlace(grid, piece, r, c);
        if (line.isRow && rows.contains(line.index)) return true;
        if (!line.isRow && cols.contains(line.index)) return true;
      }
    }
    return false;
  }

  bool _shapeTouchesLine(
    List<List<BlockColor?>> grid,
    int shapeIndex,
    _NearLine line,
  ) {
    final piece = _tempPiece(shapeIndex);
    final n = AppConstants.gridSize;
    final maxR = n - piece.rows;
    final maxC = n - piece.cols;
    if (maxR < 0 || maxC < 0) return false;

    for (var r = 0; r <= maxR; r++) {
      for (var c = 0; c <= maxC; c++) {
        if (!_placementTouchesLine(piece, r, c, line)) continue;
        if (!GameEngine.canPlace(grid, piece, r, c)) continue;
        // Must cover at least one empty cell on that line.
        for (final (dr, dc) in piece.occupiedCells) {
          final rr = r + dr;
          final cc = c + dc;
          if (line.isRow && rr == line.index && grid[rr][cc] == null) {
            return true;
          }
          if (!line.isRow && cc == line.index && grid[rr][cc] == null) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _placementTouchesLine(Piece piece, int row, int col, _NearLine line) {
    for (final (dr, dc) in piece.occupiedCells) {
      final rr = row + dr;
      final cc = col + dc;
      if (line.isRow && rr == line.index) return true;
      if (!line.isRow && cc == line.index) return true;
    }
    return false;
  }

  Piece _tempPiece(int shapeIndex) {
    return Piece(
      shape: kPieceShapes[shapeIndex],
      color: BlockColor.color0,
      shapeIndex: shapeIndex,
    );
  }

  int _blockCount(int shapeIndex) {
    var n = 0;
    for (final row in kPieceShapes[shapeIndex]) {
      for (final cell in row) {
        if (cell) n++;
      }
    }
    return n;
  }

  /// Random fallback — lean small/wide; keep bulky 4/6 uncommon.
  int _pickFallbackShape() {
    final roll = _random.nextDouble();
    final crowdedBoost = _boardFillRatio * 0.10;
    if (roll < 0.22 + crowdedBoost) {
      // small gap-fitters (1–3)
      return _pickFrom(_smallWide);
    } else if (roll < 0.38 + crowdedBoost) {
      return _pickFrom(_wideTwo);
    } else if (roll < 0.54) {
      return _pickFrom(_square2x2);
    } else if (roll < 0.68) {
      return _pickFrom(_wideFour);
    } else if (roll < 0.80) {
      // horizontal tromino / small L
      return _pickFrom(const [3, 5, 6, 7, 8]);
    } else if (roll < 0.88) {
      return _pickFrom(_rect2x3);
    } else if (roll < 0.94) {
      return _pickFrom(_wideSix);
    } else {
      return _pickFrom(_tallRare);
    }
  }

  int _pickFrom(List<int> indices) {
    return indices[_random.nextInt(indices.length)];
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

class _NearLine {
  const _NearLine({
    required this.isRow,
    required this.index,
    required this.emptyCount,
  });

  final bool isRow;
  final int index;
  final int emptyCount;
}
