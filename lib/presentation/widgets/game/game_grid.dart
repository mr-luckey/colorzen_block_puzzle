import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_painter.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/bomb_widgets.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/clear_burst.dart';

/// Drag placement preview on the board.
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
  final List<int> previewClearRows;
  final List<int> previewClearCols;

  bool get wouldClearLine =>
      previewClearRows.isNotEmpty || previewClearCols.isNotEmpty;
}

/// Shared board metrics — keep in sync with DragMath / GameGrid padding.
class BoardMetrics {
  static const gridPadding = 7.0;
  static const cellGap = 1.0;
  static const borderWidth = 1.0;
  /// Sub-pixel safety so 9 cells + gaps never exceed constraints.
  static const cellSlack = 0.0;

  static double cellSizeFor(double gridOuterWidth) {
    final inner = gridOuterWidth - gridPadding * 2;
    return ((inner - cellGap * 8) / 9) - cellSlack;
  }
}

/// Live board geometry for accurate drag snapping.
class BoardSnap {
  static final GlobalKey cellsKey = GlobalKey(debugLabel: 'board_cells');
  static double cell = 36;
  static double gap = BoardMetrics.cellGap;

  static double get stride => cell + gap;
}

class GameGrid extends StatelessWidget {
  const GameGrid({
    super.key,
    required this.grid,
    required this.palette,
    this.ghostListenable,
    this.clearedRows = const [],
    this.clearedCols = const [],
    this.placementCells = const [],
    this.blastCells = const [],
    this.clearFxColors = const {},
    this.gridKey,
    this.maxWidth,
    this.timeBomb,
  });

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;
  /// Drag ghost updates only this overlay — board cells stay stable.
  final ValueListenable<GhostState?>? ghostListenable;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<(int, int)> placementCells;
  final List<(int, int)> blastCells;
  final Map<(int, int), BlockColor> clearFxColors;
  final GlobalKey? gridKey;
  final double? maxWidth;
  final TimeBomb? timeBomb;

  @override
  Widget build(BuildContext context) {
    final gap = BoardMetrics.cellGap;
    final pad = BoardMetrics.gridPadding;
    final side =
        maxWidth ?? (MediaQuery.sizeOf(context).width - 28).clamp(200.0, 420.0);
    final inner = side - pad * 2;
    final raw = (inner - gap * 8) / 9 - BoardMetrics.cellSlack;
    final safeCell = raw.clamp(8.0, 200.0);
    BoardSnap.cell = safeCell;
    BoardSnap.gap = gap;
    final boardW = safeCell * 9 + gap * 8;

    return RepaintBoundary(
      child: SizedBox(
        width: side,
        height: side,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: palette.gridBackground,
            border: Border.all(
              color: palette.accentPrimary.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.accentPrimary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: Center(
              child: SizedBox(
                key: BoardSnap.cellsKey,
                width: boardW,
                height: boardW,
                    child: Stack(
                      children: [
                        // Stable board — one CustomPaint layer (no 81 widgets).
                        RepaintBoundary(
                          child: _BoardCells(
                            grid: grid,
                            palette: palette,
                            cell: safeCell,
                            gap: gap,
                            boardW: boardW,
                            timeBomb: timeBomb,
                          ),
                        ),
                        if (placementCells.isNotEmpty)
                          RepaintBoundary(
                            child: _PlacementPunchOverlay(
                              key: ValueKey('place_${placementCells.join()}'),
                              cells: placementCells,
                              cell: safeCell,
                              gap: gap,
                              boardW: boardW,
                            ),
                          ),
                        if (clearedRows.isNotEmpty ||
                            clearedCols.isNotEmpty ||
                            blastCells.isNotEmpty ||
                            clearFxColors.isNotEmpty)
                          RepaintBoundary(
                            child: ClearFxOverlay(
                              key: ValueKey(
                                'fx_${clearedRows.join()}_'
                                '${clearedCols.join()}_'
                                '${blastCells.length}_'
                                '${clearFxColors.length}',
                              ),
                              clearedRows: clearedRows,
                              clearedCols: clearedCols,
                              blastCells: blastCells,
                              clearFxColors: clearFxColors,
                              cell: safeCell,
                              gap: gap,
                              boardW: boardW,
                              palette: palette,
                            ),
                          ),
                        if (ghostListenable != null)
                          RepaintBoundary(
                            child: _GhostOverlay(
                              listenable: ghostListenable!,
                              palette: palette,
                              cell: safeCell,
                              gap: gap,
                              boardW: boardW,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
  }
}

class _BoardCells extends StatelessWidget {
  const _BoardCells({
    required this.grid,
    required this.palette,
    required this.cell,
    required this.gap,
    required this.boardW,
    this.timeBomb,
  });

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;
  final double cell;
  final double gap;
  final double boardW;
  final TimeBomb? timeBomb;

  @override
  Widget build(BuildContext context) {
    final bomb = timeBomb;
    final armed = bomb != null && grid[bomb.row][bomb.col] != null;
    final stride = cell + gap;

    return Stack(
      children: [
        CustomPaint(
          size: Size(boardW, boardW),
          isComplex: true,
          painter: _BoardPainter(
            grid: grid,
            palette: palette,
            cell: cell,
            gap: gap,
            skipBombRow: armed ? bomb.row : null,
            skipBombCol: armed ? bomb.col : null,
          ),
        ),
        if (bomb != null && armed)
          Positioned(
            left: bomb.col * stride,
            top: bomb.row * stride,
            width: cell,
            height: cell,
            child: BombCell(
              size: cell,
              bomb: bomb,
              palette: palette,
            ),
          ),
      ],
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.grid,
    required this.palette,
    required this.cell,
    required this.gap,
    this.skipBombRow,
    this.skipBombCol,
  });

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;
  final double cell;
  final double gap;
  final int? skipBombRow;
  final int? skipBombCol;

  @override
  void paint(Canvas canvas, Size size) {
    BlockPainter.paintBoard(
      canvas,
      grid: grid,
      palette: palette,
      cell: cell,
      gap: gap,
      skipBombRow: skipBombRow,
      skipBombCol: skipBombCol,
    );
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) {
    return old.grid != grid ||
        old.palette != palette ||
        old.cell != cell ||
        old.gap != gap ||
        old.skipBombRow != skipBombRow ||
        old.skipBombCol != skipBombCol;
  }
}

/// Brief land punch — one controller, no per-cell widget animations.
class _PlacementPunchOverlay extends StatefulWidget {
  const _PlacementPunchOverlay({
    super.key,
    required this.cells,
    required this.cell,
    required this.gap,
    required this.boardW,
  });

  final List<(int, int)> cells;
  final double cell;
  final double gap;
  final double boardW;

  @override
  State<_PlacementPunchOverlay> createState() => _PlacementPunchOverlayState();
}

class _PlacementPunchOverlayState extends State<_PlacementPunchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.boardW, widget.boardW),
            painter: _PlacementPunchPainter(
              t: Curves.easeOutCubic.transform(_ctrl.value),
              cells: widget.cells,
              cell: widget.cell,
              gap: widget.gap,
            ),
          );
        },
      ),
    );
  }
}

class _PlacementPunchPainter extends CustomPainter {
  _PlacementPunchPainter({
    required this.t,
    required this.cells,
    required this.cell,
    required this.gap,
  });

  final double t;
  final List<(int, int)> cells;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final stride = cell + gap;
    final punch = 1.0 + 0.16 * math.sin(t * math.pi);
    final flash = (1.0 - t).clamp(0.0, 1.0);
    for (final (r, c) in cells) {
      if (r < 0 || c < 0 || r >= 9 || c >= 9) continue;
      final cx = c * stride + cell / 2;
      final cy = r * stride + cell / 2;
      final side = cell * punch;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: side, height: side),
        Radius.circular(side * 0.22),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.08
          ..color = Colors.white.withValues(alpha: 0.7 * flash),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PlacementPunchPainter old) =>
      old.t != t || old.cells != cells || old.cell != cell;
}

/// Lightweight drag overlay — CustomPaint + one fast pulse (no 81-widget rebuilds).
class _GhostOverlay extends StatefulWidget {
  const _GhostOverlay({
    required this.listenable,
    required this.palette,
    required this.cell,
    required this.gap,
    required this.boardW,
  });

  final ValueListenable<GhostState?> listenable;
  final ColorPalette palette;
  final double cell;
  final double gap;
  final double boardW;

  @override
  State<_GhostOverlay> createState() => _GhostOverlayState();
}

class _GhostOverlayState extends State<_GhostOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    widget.listenable.addListener(_onGhost);
    _syncPulse(widget.listenable.value);
  }

  @override
  void didUpdateWidget(covariant _GhostOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_onGhost);
      widget.listenable.addListener(_onGhost);
      _syncPulse(widget.listenable.value);
    }
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_onGhost);
    _pulse.dispose();
    super.dispose();
  }

  void _onGhost() => _syncPulse(widget.listenable.value);

  void _syncPulse(GhostState? ghost) {
    if (ghost == null) {
      if (_pulse.isAnimating) _pulse.stop();
      return;
    }
    if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.listenable, _pulse]),
        builder: (context, _) {
          final ghost = widget.listenable.value;
          if (ghost == null) return const SizedBox.shrink();

          // Sine pulse — no ping-pong snap at the turnaround.
          final sine = 0.5 + 0.5 * math.sin(_pulse.value * math.pi * 2);
          return CustomPaint(
            size: Size(widget.boardW, widget.boardW),
            painter: _GhostPainter(
              ghost: ghost,
              pulse: ghost.valid ? sine : 0.0,
              cell: widget.cell,
              gap: widget.gap,
              invalidRed: widget.palette.invalidRed,
              fallbackAccent: widget.palette.accentSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _GhostPainter extends CustomPainter {
  _GhostPainter({
    required this.ghost,
    required this.pulse,
    required this.cell,
    required this.gap,
    required this.invalidRed,
    required this.fallbackAccent,
  });

  final GhostState ghost;
  final double pulse;
  final double cell;
  final double gap;
  final Color invalidRed;
  final Color fallbackAccent;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = ghost.color ?? fallbackAccent;
    final wouldClear = ghost.valid && ghost.wouldClearLine;
    final radius = Radius.circular(cell * 0.2);
    final stride = cell + gap;

    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final isGhost = ghost.mask[r][c];
        final previewClear = wouldClear &&
            (ghost.previewClearRows.contains(r) ||
                ghost.previewClearCols.contains(c));
        if (!isGhost && !previewClear) continue;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * stride, r * stride, cell, cell),
          radius,
        );

        if (isGhost) {
          final a = ghost.valid
              ? (previewClear ? 0.55 + 0.35 * pulse : 0.48 + 0.22 * pulse)
              : 0.4;
          final fill = ghost.valid ? accent : invalidRed;
          canvas.drawRRect(
            rect,
            Paint()..color = fill.withValues(alpha: a),
          );
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = previewClear ? 2.0 : 1.4
              ..color = Colors.white.withValues(
                alpha: previewClear ? 0.75 : 0.35,
              ),
          );
        } else {
          canvas.drawRRect(
            rect,
            Paint()
              ..color = accent.withValues(alpha: 0.14 + 0.16 * pulse),
          );
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.white.withValues(
                alpha: 0.5 + 0.4 * pulse,
              ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GhostPainter old) {
    return old.pulse != pulse ||
        old.ghost != ghost ||
        old.cell != cell ||
        old.gap != gap;
  }
}

class PiecePreview extends StatelessWidget {
  const PiecePreview({
    super.key,
    required this.piece,
    required this.palette,
    this.cellSize = 14,
    this.gap = 2,
    this.opacity = 1.0,
    this.elevated = false,
  });

  final Piece piece;
  final ColorPalette palette;
  final double cellSize;
  final double gap;
  final double opacity;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final size = BlockPainter.pieceSize(piece, cellSize, gap);
    return Opacity(
      opacity: opacity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: CustomPaint(
          size: size,
          isComplex: true,
          painter: _PiecePreviewPainter(
            piece: piece,
            palette: palette,
            cell: cellSize,
            gap: gap,
            elevated: elevated,
          ),
        ),
      ),
    );
  }
}

class _PiecePreviewPainter extends CustomPainter {
  _PiecePreviewPainter({
    required this.piece,
    required this.palette,
    required this.cell,
    required this.gap,
    required this.elevated,
  });

  final Piece piece;
  final ColorPalette palette;
  final double cell;
  final double gap;
  final bool elevated;

  @override
  void paint(Canvas canvas, Size size) {
    BlockPainter.paintPiece(
      canvas,
      piece: piece,
      palette: palette,
      cell: cell,
      gap: gap,
      elevated: elevated,
    );
  }

  @override
  bool shouldRepaint(covariant _PiecePreviewPainter old) {
    return old.piece != piece ||
        old.palette != palette ||
        old.cell != cell ||
        old.gap != gap ||
        old.elevated != elevated;
  }
}
