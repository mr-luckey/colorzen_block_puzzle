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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;
  bool _ticksOn = true;

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
    WidgetsBinding.instance.addObserver(this);
    widget.drag.interruptGen.addListener(_onDragInterrupted);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.resumed) {
      _dragging = false;
      _lastElapsed = Duration.zero;
      if (!_ticker!.isActive) {
        _ticker!.start();
      }
    }
  }

  void _onDragInterrupted() {
    _dragging = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache InheritedWidget — do not look it up on every vsync tick.
    _ticksOn = TickerMode.valuesOf(context).enabled;
    if (_ticksOn) {
      _lastElapsed = Duration.zero;
      if (_ticker != null && !_ticker!.isActive) {
        _ticker!.start();
      }
    }
  }

  @override
  void didUpdateWidget(covariant PieceTray oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBelt(widget.pieces);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.drag.interruptGen.removeListener(_onDragInterrupted);
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

  /// Keep local belt when we recycled ahead of bloc; patch on place.
  void _syncBelt(List<Piece?> source) {
    final parent = source.whereType<Piece>().toList(growable: false);
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

    final pSet = pIds.toSet();
    final lSet = lIds.toSet();
    final overlap = pSet.intersection(lSet).length;
    if (overlap >= (_belt.length - 2).clamp(1, _belt.length)) {
      _belt.removeWhere((p) => !pSet.contains(p.id));
      final have = _belt.map((p) => p.id).toSet();
      for (final p in parent) {
        if (have.contains(p.id)) continue;
        _belt.add(p);
        have.add(p.id);
      }
      while (_belt.length > AppConstants.beltSize) {
        _belt.removeLast();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _beltTick.value++;
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _belt
        ..clear()
        ..addAll(parent);
      _beltTick.value++;
    });
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
    if (!mounted || !_ticksOn) return;
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
    return BlocListener<GameBloc, GameState>(
      listenWhen: (prev, next) {
        if (prev is! GamePlaying || next is! GamePlaying) return false;
        return prev.session.movesMade != next.session.movesMade ||
            !identical(prev.session.grid, next.session.grid);
      },
      listener: (context, state) {
        if (state is GamePlaying) {
          _syncBelt(state.session.currentPieces);
        }
      },
      child: SizedBox(
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
              final visible =
                  (w / _slotWidth).ceil().clamp(3, AppConstants.beltSize) + 2;

              return ListenableBuilder(
                listenable: _beltTick,
                builder: (context, _) {
                  if (_belt.isEmpty) {
                    return Center(
                      child: Text(
                        'Loading pieces…',
                        style: AppTextStyles.mini(widget.palette.textSecondary),
                      ),
                    );
                  }

                  final show = visible.clamp(0, _belt.length);
                  final stripW = show * _slotWidth;
                  final row = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < show; i++)
                        SizedBox(
                          width: _slotWidth,
                          height: h,
                          child: _ConveyorPiece(
                            key: ValueKey('belt_${_belt[i].id}'),
                            piece: _belt[i],
                            palette: widget.palette,
                            grid: widget.grid,
                            drag: widget.drag,
                            trayHeight: widget.height,
                            onDragStart: () => _dragging = true,
                            onDragEnd: () => _dragging = false,
                            onDrop: widget.onDrop,
                          ),
                        ),
                    ],
                  );

                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: stripW,
                        height: h,
                        child: ListenableBuilder(
                          listenable: _scroll,
                          child: row,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(-_scroll.value, 0),
                              child: child,
                            );
                          },
                        ),
                      ),
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 28,
                            height: h,
                            child: DecoratedBox(
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
                      ),
                      IgnorePointer(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 28,
                            height: h,
                            child: DecoratedBox(
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
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
    );
  }
}

class _ConveyorPiece extends StatefulWidget {
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

  @override
  State<_ConveyorPiece> createState() => _ConveyorPieceState();
}

class _ConveyorPieceState extends State<_ConveyorPiece> {
  int? _pointer;
  int _boardRetry = 0;
  Offset? _down;
  bool _aimed = false;

  Piece get piece => widget.piece;
  PieceDragController get drag => widget.drag;

  @override
  void initState() {
    super.initState();
    drag.interruptGen.addListener(_onInterrupted);
  }

  @override
  void dispose() {
    drag.interruptGen.removeListener(_onInterrupted);
    super.dispose();
  }

  void _onInterrupted() {
    _pointer = null;
    _boardRetry = 0;
    _down = null;
    _aimed = false;
  }

  double get _cellSize {
    final maxDim = (widget.trayHeight - 16) /
        (piece.rows > piece.cols ? piece.rows : piece.cols.clamp(1, 5));
    return maxDim.clamp(16.0, 32.0);
  }

  void _onUpdate(Offset global) {
    drag.update(global);
    if (!_aimed) {
      final down = _down;
      if (down != null && (global - down).distanceSquared < 256) {
        return;
      }
      _aimed = true;
    }
    DragMath.applyGhost(
      drag: drag,
      board: widget.grid,
      piece: piece,
      palette: widget.palette,
      globalFinger: global,
    );
  }

  void _returnToTray() {
    _boardRetry = 0;
    drag.beginCancelSettle(
      onComplete: () {
        drag.clear();
        widget.onDragEnd();
      },
    );
  }

  void _finish(Offset global) {
    DragMath.applyGhost(
      drag: drag,
      board: widget.grid,
      piece: piece,
      palette: widget.palette,
      globalFinger: global,
    );
    final g = drag.ghost.value;
    final pieceId = piece.id;
    final row = g?.row ?? 0;
    final col = g?.col ?? 0;
    final valid = g != null &&
        g.valid &&
        GameEngine.canPlace(widget.grid, piece, g.row, g.col);

    if (!valid) {
      if ((!DragMath.boardReady || drag.inResumeGrace) && _boardRetry < 6) {
        _boardRetry++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (drag.phase.value != DragPhase.dragging) return;
          if (drag.piece.value?.id != pieceId) return;
          _finish(global);
        });
        return;
      }
      _boardRetry = 0;
      sl<HapticService>().invalidShake();
      sl<AudioService>().playSfx(SfxType.invalid);
      drag.beginCancelSettle(
        onComplete: () {
          drag.clear();
          widget.onDragEnd();
        },
      );
      return;
    }

    _boardRetry = 0;
    sl<AudioService>().playSfx(SfxType.place);
    final target = DragMath.pieceTopLeftForAnchor(row, col);
    if (target == null) {
      drag.clear();
      widget.onDragEnd();
      widget.onDrop(pieceId, row, col);
      return;
    }
    drag.beginPlaceSettle(
      targetTopLeft: target,
      onComplete: () {
        drag.clear();
        widget.onDragEnd();
        widget.onDrop(pieceId, row, col);
      },
    );
  }

  void _stealIfStuck() {
    if (drag.phase.value == DragPhase.settling ||
        drag.phase.value == DragPhase.canceling) {
      drag.completeSettle();
    }
    if (drag.isDragging) {
      drag.clear();
      widget.onDragEnd();
    }
    _pointer = null;
    _boardRetry = 0;
    _down = null;
    _aimed = false;
  }

  @override
  Widget build(BuildContext context) {
    final preview = PiecePreview(
      piece: piece,
      palette: widget.palette,
      cellSize: _cellSize,
    );

    return ListenableBuilder(
      listenable: drag.piece,
      builder: (context, child) {
        final dimmed = drag.piece.value?.id == piece.id;
        return Opacity(
          opacity: dimmed ? 0.22 : 1,
          child: child,
        );
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (_pointer == e.pointer) return;
          if (_pointer != null || drag.isDragging) {
            _stealIfStuck();
          }
          _pointer = e.pointer;
          _boardRetry = 0;
          _down = e.position;
          _aimed = false;
          widget.onDragStart();
          sl<HapticService>().selection();
          drag.start(
            p: piece,
            index: 0,
            global: e.position,
            pointer: e.pointer,
          );
          drag.update(e.position);
        },
        onPointerMove: (e) {
          if (e.pointer != _pointer) return;
          _onUpdate(e.position);
        },
        onPointerUp: (e) {
          if (e.pointer != _pointer) return;
          _pointer = null;
          if (!_aimed) {
            _returnToTray();
            return;
          }
          _finish(e.position);
        },
        onPointerCancel: (e) {
          if (_pointer != null && e.pointer != _pointer) return;
          _pointer = null;
          _boardRetry = 0;
          _down = null;
          _aimed = false;
          if (drag.phase.value == DragPhase.settling ||
              drag.phase.value == DragPhase.canceling) {
            drag.completeSettle();
            return;
          }
          if (drag.isDragging &&
              (drag.activePointer == null || drag.activePointer == e.pointer)) {
            drag.clear();
            widget.onDragEnd();
          }
        },
        child: SizedBox.expand(
          child: Center(child: preview),
        ),
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
    this.scoreSlotKey,
  });

  final int score;
  final int bestScore;
  final ColorPalette palette;
  final bool isNewBest;
  final bool hideScore;
  final int movesMade;
  final GameMode mode;
  final GlobalKey? scoreSlotKey;

  @override
  Widget build(BuildContext context) {
    if (hideScore) {
      return WoodPanel(
        palette: palette,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            child: KeyedSubtree(
              key: scoreSlotKey,
              child: _HudStat(
                label: mode == GameMode.daily ? 'DAILY ×1.5' : 'SCORE',
                value: score,
                palette: palette,
                highlight: true,
              ),
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
