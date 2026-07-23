import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class GameEngine {
  static bool canPlace(
    List<List<BlockColor?>> grid,
    Piece piece,
    int row,
    int col,
  ) {
    for (final (dr, dc) in piece.occupiedCells) {
      final r = row + dr;
      final c = col + dc;
      if (r < 0 ||
          c < 0 ||
          r >= AppConstants.gridSize ||
          c >= AppConstants.gridSize) {
        return false;
      }
      if (grid[r][c] != null) return false;
    }
    return true;
  }

  static List<List<BlockColor?>> place(
    List<List<BlockColor?>> grid,
    Piece piece,
    int row,
    int col,
  ) {
    final next = grid.map((r) => List<BlockColor?>.from(r)).toList();
    for (final (dr, dc) in piece.occupiedCells) {
      next[row + dr][col + dc] = piece.color;
    }
    return next;
  }

  static bool hasAnyValidPlacement(
    List<List<BlockColor?>> grid,
    Piece piece,
  ) {
    for (var r = 0; r < AppConstants.gridSize; r++) {
      for (var c = 0; c < AppConstants.gridSize; c++) {
        if (canPlace(grid, piece, r, c)) return true;
      }
    }
    return false;
  }

  static bool isGameOver(
    List<List<BlockColor?>> grid,
    List<Piece?> tray,
  ) {
    final pieces = tray.whereType<Piece>().toList();
    if (pieces.isEmpty) return false;
    for (final piece in pieces) {
      if (hasAnyValidPlacement(grid, piece)) return false;
    }
    return true;
  }

  /// Finds first valid placement for [piece], or null.
  static (int, int)? findHint(
    List<List<BlockColor?>> grid,
    Piece piece,
  ) {
    for (var r = 0; r < AppConstants.gridSize; r++) {
      for (var c = 0; c < AppConstants.gridSize; c++) {
        if (canPlace(grid, piece, r, c)) return (r, c);
      }
    }
    return null;
  }
}
