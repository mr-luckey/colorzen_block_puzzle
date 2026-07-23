import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/piece_generator.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/game/game_bloc.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/drag_controller.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_grid.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';

typedef PieceDropCallback = void Function(int pieceId, int row, int col);

/// Infinite random conveyor — scroll via ValueNotifier (no setState / no flicker).
class PieceTray extends StatefulWidget {
  const PieceTray({
    super.key,
    required this.pieces,
    required this.palette,
    required this.grid,
    required this.gridKey,
    required this.drag,
    required this.onDrop,
    this.height = 120,
    this.stripBombs = false,
  });

  final List<Piece?> pieces;
  final ColorPalette palette;
  final List<List<BlockColor?>> grid;
  final GlobalKey gridKey;
  final PieceDragController drag;
  final PieceDropCallback onDrop;
  final double height;
  final bool stripBombs;

  @override
  State<PieceTray> createState() => _PieceTrayState();
}

class _PieceTrayState extends State<PieceTray>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  /// Local belt — recycle is applied here first (same frame as scroll), then synced to bloc.
  final List<Piece> _belt = [];
  final ValueNotifier<double> _scroll = ValueNotifier(0);
  final ValueNotifier<int> _beltTick = ValueNotifier(0);
  bool _dragging = false;

  static const double _slotWidth = 96;

  @override
  void initState() {
    super.initState();
    _hydrateFromParent();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant PieceTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromParentIfNeeded();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    _beltTick.dispose();
    super.dispose();
  }

  void _hydrateFromParent() {
    _belt
      ..clear()
      ..addAll(widget.pieces.whereType<Piece>());
  }

  /// Keep local belt when we recycled ahead of bloc; adopt parent on place / new game.
  void _syncFromParentIfNeeded() {
    final parent = widget.pieces.whereType<Piece>().toList(growable: false);
    if (parent.isEmpty) return;
    if (_belt.isEmpty) {
      _belt.addAll(parent);
      _beltTick.value++;
      return;
    }

    final pIds = parent.map((p) => p.id).toList(growable: false);
    final lIds = _belt.map((p) => p.id).toList(growable: false);
    if (listEquals(pIds, lIds)) return;

    if (_isRecycleLag(parent, _belt)) return;

    _belt
      ..clear()
      ..addAll(parent);
    _beltTick.value++;
  }

  /// Local already dropped parent.first and appended a new tail piece.
  bool _isRecycleLag(List<Piece> parent, List<Piece> local) {
    if (parent.length != local.length || parent.length < 2) return false;
    for (var i = 0; i < parent.length - 1; i++) {
      if (parent[i + 1].id != local[i].id) return false;
    }
    return parent.first.id != local.last.id;
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (_dragging) return;
    if (dt <= 0 || dt > 0.05) return;
    if (_belt.length < 2) return;

    var next = _scroll.value + AppConstants.beltScrollSpeedPx * dt;
    while (next >= _slotWidth && _belt.length >= 2) {
      next -= _slotWidth;
      var fresh = sl<PieceGenerator>().nextConveyorPiece();
      if (widget.stripBombs) {
        fresh = fresh.copyWith(isBomb: false);
      }
      _belt.removeAt(0);
      _belt.add(fresh);
      _beltTick.value++;
      context.read<GameBloc>().add(ConveyorRecycled(newPiece: fresh));
    }
    if (_scroll.value != next) {
      _scroll.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncFromParentIfNeeded();

    return SizedBox(
      height: widget.height,
      child: WoodPanel(
        palette: widget.palette,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              return ListenableBuilder(
                listenable: _beltTick,
                builder: (context, _) {
                  final belt = List<Piece>.from(_belt);
                  if (belt.isEmpty) {
                    return Center(
                      child: Text(
                        'Loading pieces…',
                        style: AppTextStyles.mini(widget.palette.textSecondary),
                      ),
                    );
                  }

                  return ListenableBuilder(
                    listenable: _scroll,
                    builder: (context, _) {
                      final scroll = _scroll.value;
                      final children = <Widget>[];
                      for (var i = 0; i < belt.length; i++) {
                        final x = i * _slotWidth - scroll;
                        if (x < -_slotWidth || x > w + _slotWidth) continue;
                        final piece = belt[i];
                        children.add(
                          Positioned(
                            left: x,
                            top: 0,
                            width: _slotWidth,
                            height: h,
                            child: RepaintBoundary(
                              child: ListenableBuilder(
                                listenable: widget.drag.piece,
                                builder: (context, child) {
                                  final dimmed =
                                      widget.drag.piece.value?.id == piece.id;
                                  return Opacity(
                                    opacity: dimmed ? 0.22 : 1,
                                    child: child,
                                  );
                                },
                                child: _ConveyorPiece(
                                  key: ValueKey('belt_${piece.id}'),
                                  piece: piece,
                                  palette: widget.palette,
                                  grid: widget.grid,
                                  drag: widget.drag,
                                  trayHeight: widget.height,
                                  onDragStart: () => _dragging = true,
                                  onDragEnd: () => _dragging = false,
                                  onDrop: widget.onDrop,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          ...children,
                          IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.palette.surface,
                                      widget.palette.surface
                                          .withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IgnorePointer(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                width: 28,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      widget.palette.surface
                                          .withValues(alpha: 0),
                                      widget.palette.surface,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ConveyorPiece extends StatelessWidget {
  const _ConveyorPiece({
    super.key,
    required this.piece,
    required this.palette,
    required this.grid,
    required this.drag,
    required this.onDrop,
    required this.trayHeight,
    required this.onDragStart,
    required this.onDragEnd,
  });

  final Piece piece;
  final ColorPalette palette;
  final List<List<BlockColor?>> grid;
  final PieceDragController drag;
  final PieceDropCallback onDrop;
  final double trayHeight;
  final VoidCallback onDragStart;
  final VoidCallback onDragEnd;

  double get _cellSize {
    final maxDim = (trayHeight - 28) /
        (piece.rows > piece.cols ? piece.rows : piece.cols.clamp(1, 5));
    return maxDim.clamp(12.0, 24.0);
  }

  void _onUpdate(Offset global) {
    drag.update(global);
    DragMath.applyGhost(
      drag: drag,
      board: grid,
      piece: piece,
      palette: palette,
      globalFinger: global,
    );
  }

  void _finish(Offset global) {
    DragMath.applyGhost(
      drag: drag,
      board: grid,
      piece: piece,
      palette: palette,
      globalFinger: global,
    );
    final g = drag.ghost.value;
    final pieceId = piece.id;
    drag.clear();
    onDragEnd();

    if (g == null || !g.valid) {
      sl<HapticService>().invalidShake();
      sl<AudioService>().playSfx(SfxType.invalid);
      return;
    }

    if (GameEngine.canPlace(grid, piece, g.row, g.col)) {
      sl<AudioService>().playSfx(SfxType.place);
      onDrop(pieceId, g.row, g.col);
    } else {
      sl<HapticService>().invalidShake();
      sl<AudioService>().playSfx(SfxType.invalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = PiecePreview(
      piece: piece,
      palette: palette,
      cellSize: _cellSize,
    );

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        onDragStart();
        sl<HapticService>().selection();
        sl<AudioService>().playSfx(SfxType.pickup);
        drag.start(p: piece, index: 0, global: e.position);
        _onUpdate(e.position);
      },
      onPointerMove: (e) => _onUpdate(e.position),
      onPointerUp: (e) => _finish(e.position),
      onPointerCancel: (_) {
        drag.clear();
        onDragEnd();
      },
      child: SizedBox.expand(
        child: Center(child: preview),
      ),
    );
  }
}

class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    super.key,
    required this.score,
    required this.bestScore,
    required this.palette,
    this.isNewBest = false,
    this.hideScore = false,
    this.movesMade = 0,
    this.mode = GameMode.classic,
  });

  final int score;
  final int bestScore;
  final ColorPalette palette;
  final bool isNewBest;
  final bool hideScore;
  final int movesMade;
  final GameMode mode;

  @override
  Widget build(BuildContext context) {
    if (hideScore) {
      return WoodPanel(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'ZEN · No score · No bombs · Never ends',
                style: AppTextStyles.section(palette.accentPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              '$movesMade moves',
              style: AppTextStyles.mini(palette.textSecondary),
            ),
          ],
        ),
      );
    }

    return WoodPanel(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _HudStat(
              label: 'BEST',
              value: bestScore,
              palette: palette,
              leading: Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: palette.accentSecondary,
              ),
              shimmer: isNewBest,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: palette.accentSecondary.withValues(alpha: 0.25),
          ),
          Expanded(
            child: _HudStat(
              label: mode == GameMode.daily ? 'DAILY ×1.5' : 'SCORE',
              value: score,
              palette: palette,
              highlight: true,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: palette.accentSecondary.withValues(alpha: 0.25),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('MOVES', style: AppTextStyles.mini(palette.textSecondary)),
                Text(
                  '$movesMade',
                  style: AppTextStyles.score(palette.accentSecondary)
                      .copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HudStat extends StatelessWidget {
  const _HudStat({
    required this.label,
    required this.value,
    required this.palette,
    this.leading,
    this.highlight = false,
    this.shimmer = false,
  });

  final String label;
  final int value;
  final ColorPalette palette;
  final Widget? leading;
  final bool highlight;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    Widget valueText = Text(
      '$value',
      style: AppTextStyles.score(
        highlight ? palette.textPrimary : palette.accentSecondary,
      ).copyWith(fontSize: 22, height: 1.05),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    if (shimmer) {
      valueText = valueText
          .animate(onPlay: (c) => c.repeat(count: 3))
          .shimmer(duration: 1200.ms, color: palette.comboGold);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 4)],
              Text(label, style: AppTextStyles.mini(palette.textSecondary)),
            ],
          ),
          const SizedBox(height: 2),
          valueText,
        ],
      ),
    );
  }
}
