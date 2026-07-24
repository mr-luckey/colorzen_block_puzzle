import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_grid.dart';

/// Holds live drag state without rebuilding the whole game tree every frame.
class PieceDragController {
  PieceDragController();

  final ValueNotifier<Offset?> finger = ValueNotifier(null);
  final ValueNotifier<Piece?> piece = ValueNotifier(null);
  final ValueNotifier<GhostState?> ghost = ValueNotifier(null);

  /// Reused ghost mask — avoids allocating 9×9 every pointer move.
  final List<List<bool>> _maskScratch =
      List.generate(9, (_) => List.filled(9, false));

  int? trayIndex;
  bool get isDragging => piece.value != null;

  /// Piece floats above the finger (classic puzzle feel).
  static const double fingerLift = 72;
  /// Visual scale while dragging (tray stays small; board snap stays 1.0).
  static const double pickupScale = 1.42;

  void start({
    required Piece p,
    required int index,
    required Offset global,
  }) {
    trayIndex = index;
    piece.value = p;
    finger.value = global;
  }

  void update(Offset global) {
    finger.value = global;
  }

  void clear() {
    trayIndex = null;
    piece.value = null;
    finger.value = null;
    ghost.value = null;
  }

  void setGhost({
    required List<List<bool>>? mask,
    required Color? color,
    required bool valid,
    required int? row,
    required int? col,
    List<int> previewClearRows = const [],
    List<int> previewClearCols = const [],
  }) {
    if (mask == null) {
      if (ghost.value != null) ghost.value = null;
      return;
    }
    final prev = ghost.value;
    // Skip notify when ghost target didn't change (drag jitter).
    if (prev != null &&
        prev.valid == valid &&
        prev.row == (row ?? 0) &&
        prev.col == (col ?? 0) &&
        prev.color == color &&
        listEquals(prev.previewClearRows, previewClearRows) &&
        listEquals(prev.previewClearCols, previewClearCols)) {
      return;
    }
    ghost.value = GhostState(
      mask: mask,
      color: color,
      valid: valid,
      row: row ?? 0,
      col: col ?? 0,
      previewClearRows: previewClearRows,
      previewClearCols: previewClearCols,
    );
  }

  void dispose() {
    finger.dispose();
    piece.dispose();
    ghost.dispose();
  }
}

class GhostState {
  const GhostState({
    required this.mask,
    required this.color,
    required this.valid,
    required this.row,
    required this.col,
    this.previewClearRows = const [],
    this.previewClearCols = const [],
  });

  final List<List<bool>> mask;
  final Color? color;
  final bool valid;
  final int row;
  final int col;
  /// Rows that would clear if this ghost were placed.
  final List<int> previewClearRows;
  /// Columns that would clear if this ghost were placed.
  final List<int> previewClearCols;

  bool get wouldClearLine =>
      previewClearRows.isNotEmpty || previewClearCols.isNotEmpty;
}

/// Accurate placement math: floating piece top-left → board cells.
class DragMath {
  static Size piecePixelSize(Piece piece) {
    final stride = BoardSnap.stride;
    final gap = BoardSnap.gap;
    final w = piece.cols * BoardSnap.cell + (piece.cols - 1) * gap;
    final h = piece.rows * BoardSnap.cell + (piece.rows - 1) * gap;
    // Keep stride available for overlays that use uniform spacing.
    assert(stride > 0);
    return Size(w, h);
  }

  /// Top-left of the floating piece in global coordinates.
  static Offset pieceTopLeftGlobal(Offset finger, Piece piece) {
    final size = piecePixelSize(piece);
    return Offset(
      finger.dx - size.width / 2,
      finger.dy - PieceDragController.fingerLift - size.height / 2,
    );
  }

  static (int row, int col)? rawAnchor({
    required Offset globalFinger,
    required Piece piece,
  }) {
    final box =
        BoardSnap.cellsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;

    final topLeft = pieceTopLeftGlobal(globalFinger, piece);
    final local = box.globalToLocal(topLeft);
    final stride = BoardSnap.stride;

    // Snap using cell centers — more forgiving than pure top-left.
    final half = BoardSnap.cell / 2;
    var col = ((local.dx + half) / stride).floor();
    var row = ((local.dy + half) / stride).floor();

    // Allow slight out-of-range for invalid ghost, but keep usable.
    if (row < -2 || col < -2 || row > 10 || col > 10) return null;
    return (row, col);
  }

  /// Prefer exact guess; if invalid, magnet-snap to nearest valid spot.
  static (int row, int col)? anchorFor({
    required List<List<BlockColor?>> board,
    required Offset globalFinger,
    required Piece piece,
  }) {
    final guessed = rawAnchor(globalFinger: globalFinger, piece: piece);
    if (guessed == null) return null;
    final (gr, gc) = guessed;

    if (GameEngine.canPlace(board, piece, gr, gc)) {
      return guessed;
    }

    // Magnetic assist: search nearby valid cells (feels forgiving + fun).
    (int, int)? best;
    var bestDist = 1 << 30;
    for (var dr = -2; dr <= 2; dr++) {
      for (var dc = -2; dc <= 2; dc++) {
        final r = gr + dr;
        final c = gc + dc;
        if (!GameEngine.canPlace(board, piece, r, c)) continue;
        final dist = dr * dr + dc * dc;
        if (dist < bestDist) {
          bestDist = dist;
          best = (r, c);
        }
      }
    }
    // Magnetic assist within ~2.5 cells — forgiving, still predictable.
    return bestDist <= 8 ? best : guessed;
  }

  static void applyGhost({
    required PieceDragController drag,
    required List<List<BlockColor?>> board,
    required Piece piece,
    required ColorPalette palette,
    required Offset globalFinger,
  }) {
    final anchor = anchorFor(
      board: board,
      globalFinger: globalFinger,
      piece: piece,
    );
    if (anchor == null) {
      drag.setGhost(
        mask: null,
        color: null,
        valid: false,
        row: null,
        col: null,
      );
      return;
    }

    final (row, col) = anchor;
    final valid = GameEngine.canPlace(board, piece, row, col);
    final mask = drag._maskScratch;
    for (var r = 0; r < 9; r++) {
      mask[r].fillRange(0, 9, false);
    }
    var anyOnBoard = false;

    for (final (dr, dc) in piece.occupiedCells) {
      final r = row + dr;
      final c = col + dc;
      if (r >= 0 && c >= 0 && r < 9 && c < 9) {
        mask[r][c] = true;
        anyOnBoard = true;
      }
    }

    if (!anyOnBoard) {
      drag.setGhost(
        mask: null,
        color: null,
        valid: false,
        row: null,
        col: null,
      );
      return;
    }

    var previewRows = const <int>[];
    var previewCols = const <int>[];
    if (valid) {
      final previewGrid = GameEngine.place(board, piece, row, col);
      final clears = LineClearEngine.detectFullLines(previewGrid);
      previewRows = clears.$1;
      previewCols = clears.$2;
    }

    drag.setGhost(
      mask: mask,
      color: palette.blockColor(piece.color),
      valid: valid,
      row: row,
      col: col,
      previewClearRows: previewRows,
      previewClearCols: previewCols,
    );
  }
}

class DragOverlayHost extends StatefulWidget {
  const DragOverlayHost({
    super.key,
    required this.controller,
    required this.palette,
    required this.child,
  });

  final PieceDragController controller;
  final ColorPalette palette;
  final Widget child;

  @override
  State<DragOverlayHost> createState() => _DragOverlayHostState();
}

class _DragOverlayHostState extends State<DragOverlayHost> {
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    widget.controller.piece.addListener(_syncOverlay);
    widget.controller.finger.addListener(_onFinger);
  }

  @override
  void didUpdateWidget(covariant DragOverlayHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.piece.removeListener(_syncOverlay);
      oldWidget.controller.finger.removeListener(_onFinger);
      widget.controller.piece.addListener(_syncOverlay);
      widget.controller.finger.addListener(_onFinger);
    }
  }

  void _onFinger() => _entry?.markNeedsBuild();

  void _syncOverlay() {
    final dragging = widget.controller.piece.value != null;
    if (dragging && _entry == null) {
      _entry = OverlayEntry(
        builder: (ctx) => _FloatingPiece(
          controller: widget.controller,
          palette: widget.palette,
        ),
      );
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _entry == null) return;
        Overlay.maybeOf(context, rootOverlay: true)?.insert(_entry!);
      });
    } else if (!dragging && _entry != null) {
      _entry!.remove();
      _entry = null;
    } else {
      _entry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    widget.controller.piece.removeListener(_syncOverlay);
    widget.controller.finger.removeListener(_onFinger);
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FloatingPiece extends StatelessWidget {
  const _FloatingPiece({
    required this.controller,
    required this.palette,
  });

  final PieceDragController controller;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final piece = controller.piece.value;
    final finger = controller.finger.value;
    if (piece == null || finger == null) return const SizedBox.shrink();

    final size = DragMath.piecePixelSize(piece);
    final topLeft = DragMath.pieceTopLeftGlobal(finger, piece);
    final cell = math.max(12.0, BoardSnap.cell);
    final scale = PieceDragController.pickupScale;

    // Bigger visual on pickup; ghost math still uses BoardSnap (unscaled).
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: topLeft.dx,
            top: topLeft.dy,
            width: size.width,
            height: size.height,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: PiecePreview(
                piece: piece,
                palette: palette,
                cellSize: cell,
                gap: BoardSnap.gap,
                elevated: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
