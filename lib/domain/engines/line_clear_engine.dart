import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class LineClearEngine {
  LineClearResult detectAndClear(List<List<BlockColor?>> grid) {
    final rows = <int>[];
    final cols = <int>[];
    final bonuses = <bool>[];

    for (var r = 0; r < AppConstants.gridSize; r++) {
      if (grid[r].every((c) => c != null)) {
        rows.add(r);
        bonuses.add(_isUniform(grid[r]));
      }
    }

    for (var c = 0; c < AppConstants.gridSize; c++) {
      final column = List.generate(AppConstants.gridSize, (r) => grid[r][c]);
      if (column.every((cell) => cell != null)) {
        cols.add(c);
        bonuses.add(_isUniform(column));
      }
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
