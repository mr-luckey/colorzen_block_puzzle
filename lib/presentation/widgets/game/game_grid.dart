import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_visuals.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/bomb_widgets.dart';

/// Shared board metrics — keep in sync with DragMath / GameGrid padding.
class BoardMetrics {
  /// Inner pad over the 3D wood frame art (keeps 9×9, larger cells).
  static const gridPadding = 4.0;
  static const cellGap = 2.0;
  static const borderWidth = 2.0;
  /// Outer decorative frame inset (shows carved wood rim).
  static const frameInset = 18.0;
  /// Sub-pixel safety so 9 cells + gaps never exceed constraints.
  static const cellSlack = 0.2;

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
    this.previewClearing = false,
    this.previewAccent,
    required this.palette,
  });

  final double size;
  final BlockColor? color;
  final Color? ghostColor;
  final bool clearing;
  final bool placing;
  /// Drag preview: this cell sits on a row/col that would clear on drop.
  final bool previewClearing;
  final Color? previewAccent;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final s = size.clamp(0.0, 1000.0);
    final radius = s * 0.2;
    Widget child;
    final accent = previewAccent ?? palette.accentSecondary;

    if (ghostColor != null && color == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: previewClearing
              ? ghostColor!.withValues(alpha: 0.85)
              : ghostColor,
          border: Border.all(
            color: previewClearing
                ? Colors.white.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.35),
            width: previewClearing ? 2.2 : 1.5,
          ),
          boxShadow: previewClearing
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.65),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      );
    } else if (color == null) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: previewClearing
              ? Color.alphaBlend(
                  accent.withValues(alpha: 0.4),
                  palette.cellEmpty.withValues(alpha: 0.55),
                )
              : palette.cellEmpty.withValues(alpha: 0.55),
          border: Border.all(
            color: previewClearing
                ? accent.withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.08),
            width: previewClearing ? 1.5 : 1,
          ),
          boxShadow: [
            if (previewClearing)
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: 0.5,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
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
      if (previewClearing) {
        child = Stack(
          fit: StackFit.expand,
          children: [
            child,
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.7),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      }
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
    this.previewClearRows = const [],
    this.previewClearCols = const [],
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
  /// Drag preview: lines that would clear if ghost is dropped.
  final List<int> previewClearRows;
  final List<int> previewClearCols;
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
    final previewAccent = ghostColor ?? palette.accentSecondary;

    return RepaintBoundary(
      child: SizedBox(
        width: side,
        height: side,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Downloaded / generated 3D wood board frame.
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset(
                'assets/images/grid_frame_3d.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: palette.gridBackground,
                  ),
                ),
              ),
            ),
            // Soft 3D rim glow over the frame.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFFFD54F).withValues(alpha: 0.35),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(BoardMetrics.frameInset),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withValues(alpha: 0.22),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: -1,
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
                      final boardH = boardW;

                      return Center(
                        child: SizedBox(
                          key: BoardSnap.cellsKey,
                          width: boardW,
                          height: boardH,
                          child: Column(
                            children: List.generate(9, (r) {
                              return Padding(
                                padding:
                                    EdgeInsets.only(bottom: r == 8 ? 0 : gap),
                                child: SizedBox(
                                  height: safeCell,
                                  width: boardW,
                                  child: Row(
                                    children: List.generate(9, (c) {
                                      final ghost = ghostMask != null &&
                                          ghostMask![r][c];
                                      final previewClear =
                                          isGhostValid &&
                                              (previewClearRows.contains(r) ||
                                                  previewClearCols.contains(c));
                                      Color? ghostCol;
                                      if (ghost) {
                                        ghostCol = isGhostValid
                                            ? (ghostColor ??
                                                    palette.accentPrimary)
                                                .withValues(
                                                  alpha: previewClear
                                                      ? 0.72
                                                      : 0.55,
                                                )
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
                                              clearing:
                                                  clearedRows.contains(r) ||
                                                      clearedCols.contains(c) ||
                                                      blastCells
                                                          .contains((r, c)),
                                              placing: placementCells
                                                  .contains((r, c)),
                                              previewClearing: previewClear,
                                              previewAccent: previewAccent,
                                              palette: palette,
                                            );
                                      if (!isBomb && previewClear) {
                                        // Heartbeat on lines that would clear.
                                        cellWidget = cellWidget
                                            .animate(
                                              key: ValueKey(
                                                'preview_clear_${r}_$c',
                                              ),
                                              onPlay: (ctrl) => ctrl.repeat(),
                                            )
                                            .scale(
                                              begin: const Offset(1, 1),
                                              end: const Offset(1.1, 1.1),
                                              duration: 180.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .then()
                                            .scale(
                                              begin: const Offset(1.1, 1.1),
                                              end: const Offset(1, 1),
                                              duration: 160.ms,
                                              curve: Curves.easeIn,
                                            )
                                            .then()
                                            .scale(
                                              begin: const Offset(1, 1),
                                              end: const Offset(1.06, 1.06),
                                              duration: 120.ms,
                                              curve: Curves.easeOut,
                                            )
                                            .then()
                                            .scale(
                                              begin: const Offset(1.06, 1.06),
                                              end: const Offset(1, 1),
                                              duration: 200.ms,
                                              curve: Curves.easeIn,
                                            );
                                      } else if (!isBomb &&
                                          ghost &&
                                          isGhostValid) {
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
          ],
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
