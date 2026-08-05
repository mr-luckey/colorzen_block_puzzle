import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_visuals.dart';
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

class GridCell extends StatelessWidget {
  const GridCell({
    super.key,
    required this.size,
    this.color,
    this.placing = false,
    required this.palette,
  });

  final double size;
  final BlockColor? color;
  final bool placing;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final s = size.clamp(0.0, 1000.0);
    final radius = s * 0.2;
    Widget child;

    if (color == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: palette.cellEmpty.withValues(alpha: 0.55),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      );
    } else {
      child = BlockVisuals.glassBlock(
        size: s,
        base: palette.blockColor(color!),
        emoji: BlockVisuals.emojiFor(color!),
      );
    }

    child = SizedBox(width: s, height: s, child: child);

    // Placement pop only — clear/blast FX live in ClearFxOverlay (1 controller).
    if (placing) {
      child = child
          .animate()
          .scale(
            begin: const Offset(0.55, 0.55),
            end: const Offset(1.0, 1.0),
            duration: 90.ms,
            curve: Curves.easeOut,
          );
    }

    return child;
  }
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxSide = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final raw =
                    (maxSide - gap * 8) / 9 - BoardMetrics.cellSlack;
                final safeCell = raw.clamp(8.0, 200.0);

                BoardSnap.cell = safeCell;
                BoardSnap.gap = gap;

                final boardW = safeCell * 9 + gap * 8;

                return Center(
                  child: SizedBox(
                    key: BoardSnap.cellsKey,
                    width: boardW,
                    height: boardW,
                    child: Stack(
                      children: [
                        // Stable board — does NOT rebuild on every drag move.
                        RepaintBoundary(
                          child: _BoardCells(
                            grid: grid,
                            palette: palette,
                            cell: safeCell,
                            gap: gap,
                            boardW: boardW,
                            placementCells: placementCells,
                            timeBomb: timeBomb,
                          ),
                        ),
                        if (clearedRows.isNotEmpty ||
                            clearedCols.isNotEmpty ||
                            blastCells.isNotEmpty ||
                            clearFxColors.isNotEmpty)
                          ClearFxOverlay(
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
                        if (ghostListenable != null)
                          _GhostOverlay(
                            listenable: ghostListenable!,
                            palette: palette,
                            cell: safeCell,
                            gap: gap,
                            boardW: boardW,
                          ),
                      ],
                    ),
                  ),
                );
              },
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
    required this.placementCells,
    this.timeBomb,
  });

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;
  final double cell;
  final double gap;
  final double boardW;
  final List<(int, int)> placementCells;
  final TimeBomb? timeBomb;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(9, (r) {
        return Padding(
          padding: EdgeInsets.only(bottom: r == 8 ? 0 : gap),
          child: SizedBox(
            height: cell,
            width: boardW,
            child: Row(
              children: List.generate(9, (c) {
                final isBomb = timeBomb != null &&
                    timeBomb!.row == r &&
                    timeBomb!.col == c &&
                    grid[r][c] != null;

                final child = isBomb
                    ? BombCell(
                        size: cell,
                        bomb: timeBomb!,
                        palette: palette,
                      )
                    : GridCell(
                        size: cell,
                        color: grid[r][c],
                        placing: placementCells.contains((r, c)),
                        palette: palette,
                      );

                return Padding(
                  padding: EdgeInsets.only(right: c == 8 ? 0 : gap),
                  child: SizedBox(
                    width: cell,
                    height: cell,
                    child: child,
                  ),
                );
              }),
            ),
          ),
        );
      }),
    );
  }
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
      duration: const Duration(milliseconds: 90),
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
      _pulse.repeat(reverse: true);
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

          return CustomPaint(
            size: Size(widget.boardW, widget.boardW),
            painter: _GhostPainter(
              ghost: ghost,
              pulse: ghost.valid ? _pulse.value : 0.0,
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
    final baseColor = palette.blockColor(piece.color);
    final emoji = BlockVisuals.emojiFor(piece.color);
    final bombLocal = piece.isBomb ? piece.occupiedCells.first : null;

    return Opacity(
      opacity: opacity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: piece.cols * cellSize + (piece.cols - 1) * gap,
          height: piece.rows * cellSize + (piece.rows - 1) * gap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(piece.rows, (r) {
              return Padding(
                padding: EdgeInsets.only(bottom: r == piece.rows - 1 ? 0 : gap),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(piece.cols, (c) {
                    final filled = piece.shape[r][c];
                    final isBombCell = bombLocal != null &&
                        bombLocal.$1 == r &&
                        bombLocal.$2 == c;
                    if (!filled) {
                      return Padding(
                        padding: EdgeInsets.only(
                          right: c == piece.cols - 1 ? 0 : gap,
                        ),
                        child: SizedBox(width: cellSize, height: cellSize),
                      );
                    }
                    return Padding(
                      padding: EdgeInsets.only(
                        right: c == piece.cols - 1 ? 0 : gap,
                      ),
                      child: isBombCell
                          ? SizedBox(
                              width: cellSize,
                              height: cellSize,
                              child: BlockVisuals.glassBlock(
                                size: cellSize,
                                base: const Color(0xFFB71C1C),
                                emoji: BlockVisuals.bombEmoji,
                                elevated: elevated,
                              ),
                            )
                          : BlockVisuals.glassBlock(
                              size: cellSize,
                              base: baseColor,
                              emoji: emoji,
                              elevated: elevated,
                            ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
