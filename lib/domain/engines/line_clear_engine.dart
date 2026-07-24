import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class LineClearEngine {
  /// Rows/cols that would clear after placing [piece] — no grid allocation.
  static (List<int> rows, List<int> cols) wouldClearAfterPlace(
    List<List<BlockColor?>> board,
    Piece piece,
    int row,
    int col,
  ) {
    final n = AppConstants.gridSize;
    final placed = piece.occupiedCells
        .map((o) => (row + o.$1, col + o.$2))
        .toList(growable: false);

    bool occupied(int r, int c) {
      if (board[r][c] != null) return true;
      for (final p in placed) {
        if (p.$1 == r && p.$2 == c) return true;
      }
      return false;
    }

    final rows = <int>[];
    final cols = <int>[];
    final touchedRows = <int>{};
    final touchedCols = <int>{};
    for (final p in placed) {
      touchedRows.add(p.$1);
      touchedCols.add(p.$2);
    }

    for (final r in touchedRows) {
      if (r < 0 || r >= n) continue;
      var full = true;
      for (var c = 0; c < n; c++) {
        if (!occupied(r, c)) {
          full = false;
          break;
        }
      }
      if (full) rows.add(r);
    }

    for (final c in touchedCols) {
      if (c < 0 || c >= n) continue;
      var full = true;
      for (var r = 0; r < n; r++) {
        if (!occupied(r, c)) {
          full = false;
          break;
        }
      }
      if (full) cols.add(c);
    }

    rows.sort();
    cols.sort();
    return (rows, cols);
  }

  /// Rows/cols that are fully occupied — no grid mutation (drag preview).
  static (List<int> rows, List<int> cols) detectFullLines(
    List<List<BlockColor?>> grid,
  ) {
    final rows = <int>[];
    final cols = <int>[];

    for (var r = 0; r < AppConstants.gridSize; r++) {
      if (grid[r].every((c) => c != null)) rows.add(r);
    }

    for (var c = 0; c < AppConstants.gridSize; c++) {
      var full = true;
      for (var r = 0; r < AppConstants.gridSize; r++) {
        if (grid[r][c] == null) {
          full = false;
          break;
        }
      }
      if (full) cols.add(c);
    }

    return (rows, cols);
  }

  LineClearResult detectAndClear(List<List<BlockColor?>> grid) {
    final (rows, cols) = detectFullLines(grid);
    final bonuses = <bool>[];

    for (final r in rows) {
      bonuses.add(_isUniform(grid[r]));
    }
    for (final c in cols) {
      final column = List.generate(AppConstants.gridSize, (r) => grid[r][c]);
      bonuses.add(_isUniform(column));
    }

    final next = grid.map((r) => List<BlockColor?>.from(r)).toList();
    for (final r in rows) {
      for (var c = 0; c < AppConstants.gridSize; c++) {
        next[r][c] = null;
      }
    }
    for (final c in cols) {
      for (var r = 0; r < AppConstants.gridSize; r++) {
        next[r][c] = null;
      }
    }

    return LineClearResult(
      grid: next,
      clearedRows: rows,
      clearedCols: cols,
      colorBonusFlags: bonuses,
    );
  }

  bool _isUniform(List<BlockColor?> cells) {
    final first = cells.first;
    return cells.every((c) => c == first);
  }
}
