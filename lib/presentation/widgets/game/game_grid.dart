import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_visuals.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/bomb_widgets.dart';

/// Shared board metrics — keep in sync with DragMath / GameGrid padding.
class BoardMetrics {
  static const gridPadding = 8.0;
  static const cellGap = 3.0;
  static const borderWidth = 2.0;
  /// Sub-pixel safety so 9 cells + gaps never exceed constraints.
  static const cellSlack = 0.25;

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
    this.ghostColor,
    this.clearing = false,
    this.placing = false,
    required this.palette,
  });

  final double size;
  final BlockColor? color;
  final Color? ghostColor;
  final bool clearing;
  final bool placing;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final s = size.clamp(0.0, 1000.0);
    final radius = s * 0.2;
    Widget child;

    if (ghostColor != null && color == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: ghostColor,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
      );
    } else if (color == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: palette.cellEmpty,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 2,
              offset: const Offset(0, 1),
              spreadRadius: -0.5,
            ),
          ],
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

    // Only fade filled blocks. Empty cell backgrounds must stay visible.
    if (clearing && color != null) {
      child = child
          .animate()
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.15, 1.15),
            duration: 120.ms,
          )
          .then()
          .fadeOut(duration: 180.ms);
    } else if (clearing && color == null) {
      // Soft flash on the empty slot — never remove the background box.
      child = child
          .animate()
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: 100.ms,
          )
          .tint(color: palette.accentSecondary.withValues(alpha: 0.35))
          .then()
          .scale(
            begin: const Offset(1.06, 1.06),
            end: const Offset(1, 1),
            duration: 160.ms,
          );
    }

    if (placing) {
      child = child
          .animate()
          .scale(
            begin: const Offset(0.4, 0.4),
            end: const Offset(1.08, 1.08),
            duration: 120.ms,
            curve: Curves.easeOutBack,
          )
          .then()
          .scale(
            begin: const Offset(1.08, 1.08),
            end: const Offset(1.0, 1.0),
            duration: 80.ms,
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
    this.ghostMask,
    this.ghostColor,
    this.isGhostValid = true,
    this.clearedRows = const [],
    this.clearedCols = const [],
    this.placementCells = const [],
    this.blastCells = const [],
    this.gridKey,
    this.maxWidth,
    this.timeBomb,
  });

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;
  final List<List<bool>>? ghostMask;
  final Color? ghostColor;
  final bool isGhostValid;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<(int, int)> placementCells;
  final List<(int, int)> blastCells;
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(palette.gridBackground, Colors.white, 0.06)!,
                  palette.gridBackground,
                  Color.lerp(palette.gridBackground, Colors.black, 0.12)!,
                ],
              ),
              border: Border.all(
                color: Color.lerp(palette.accentPrimary, Colors.brown, 0.4)!
                    .withValues(alpha: 0.55),
                width: BoardMetrics.borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
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
                // Tiny slack only — keeps original look, prevents sub-pixel overflow.
                final raw =
                    (maxSide - gap * 8) / 9 - BoardMetrics.cellSlack;
                final safeCell = raw.clamp(8.0, 200.0);

                // Publish live geometry for drag snapping.
                BoardSnap.cell = safeCell;
                BoardSnap.gap = gap;

                final boardW = safeCell * 9 + gap * 8;
                final boardH = boardW;

                return Center(
                  child: SizedBox(
                    key: BoardSnap.cellsKey,
                    width: boardW,
                    height: boardH,
                    child: Column(
                      children: List.generate(9, (r) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: r == 8 ? 0 : gap),
                          child: SizedBox(
                            height: safeCell,
                            width: boardW,
                            child: Row(
                              children: List.generate(9, (c) {
                                final ghost =
                                    ghostMask != null && ghostMask![r][c];
                                Color? ghostCol;
                                if (ghost) {
                                  ghostCol = isGhostValid
                                      ? (ghostColor ?? palette.accentPrimary)
                                          .withValues(alpha: 0.55)
                                      : palette.invalidRed
                                          .withValues(alpha: 0.4);
                                }
                                final isBomb = timeBomb != null &&
                                    timeBomb!.row == r &&
                                    timeBomb!.col == c &&
                                    grid[r][c] != null;

                                Widget cellWidget = isBomb
                                    ? BombCell(
                                        size: safeCell,
                                        bomb: timeBomb!,
                                        palette: palette,
                                      )
                                    : GridCell(
                                        size: safeCell,
                                        color: grid[r][c],
                                        ghostColor: ghostCol,
                                        clearing: clearedRows.contains(r) ||
                                            clearedCols.contains(c) ||
                                            blastCells.contains((r, c)),
                                        placing:
                                            placementCells.contains((r, c)),
                                        palette: palette,
                                      );
                                if (!isBomb && ghost && isGhostValid) {
                                  cellWidget = cellWidget
                                      .animate(
                                        onPlay: (ctrl) =>
                                            ctrl.repeat(reverse: true),
                                      )
                                      .fade(
                                        begin: 0.75,
                                        end: 1,
                                        duration: 350.ms,
                                      );
                                }
                                return Padding(
                                  padding: EdgeInsets.only(
                                    right: c == 8 ? 0 : gap,
                                  ),
                                  child: SizedBox(
                                    width: safeCell,
                                    height: safeCell,
                                    child: cellWidget,
                                  ),
                                );
                              }),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        ),
      ),
    );
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
    // Bomb sits on ONE cell of the shape (same cell that arms on place).
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
