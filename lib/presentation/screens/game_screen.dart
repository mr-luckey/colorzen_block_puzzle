import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/piece_generator.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/daily/daily_challenge_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/game/game_bloc.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/home/game_over_bonus_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/ads/banner_ad_bar.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/bomb_widgets.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/clear_burst.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/clear_score_fly.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/drag_controller.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_exit_sheet.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_grid.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/move_praise_banner.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/piece_tray.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/perf_tier.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/survive_timer_hud.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/time_up_result.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:colorzen_block_puzzle/services/share_service.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.mode, this.forceNew = false});

  final GameMode mode;
  final bool forceNew;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GameBloc(
        repo: sl<GameRepository>(),
        pieceGen: sl<PieceGenerator>(),
        clearEngine: sl<LineClearEngine>(),
        haptics: sl<HapticService>(),
        audio: sl<AudioService>(),
        loadTheme: () async => sl<ThemeCubit>().state,
        onThemeMaybeUnlock: (data) => sl<ThemeCubit>().applyUnlocks(data),
      )..add(GameStarted(mode, forceNew: forceNew)),
      child: _GameView(mode: mode),
    );
  }
}

class _GameView extends StatefulWidget {
  const _GameView({required this.mode});
  final GameMode mode;

  @override
  State<_GameView> createState() => _GameViewState();
}

class _GameViewState extends State<_GameView> with WidgetsBindingObserver {
  final _gridKey = GlobalKey();
  final _shareKey = GlobalKey();
  final _scoreHudKey = GlobalKey();
  final _drag = PieceDragController();

  final _fx = ValueNotifier<_GameFx>(const _GameFx());
  bool _gameOverShown = false;
  bool _paused = false;
  bool _pauseOpen = false;
  bool _leftToBackground = false;
  int? _hudHeldScore;
  Timer? _bombUiTimer;
  TimeBomb? _trackedBomb;

  bool get _isLivePlay {
    if (!mounted) return false;
    final s = context.read<GameBloc>().state;
    return s is GamePlaying && !s.session.isGameOver;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hard-block menu interstitials while the board is active.
    sl<AdService>().setInGameplay(true);
    PerfTier.instance.ensureHooked();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bombUiTimer?.cancel();
    _fx.dispose();
    // Allow menu / home interstitial loop again after leaving the board.
    sl<AdService>().setInGameplay(false);
    // Kick BGM for whoever is underneath (home) before route finishes.
    // ignore: discarded_futures
    sl<AudioService>().ensureMusicPlaying();
    super.dispose();
    _drag.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    switch (state) {
      case AppLifecycleState.inactive:
        // Recents / home press starts here — freeze clock immediately.
        if (_isLivePlay) _freezePlay(true);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_isLivePlay || _paused) {
          _freezePlay(true);
          _leftToBackground = true;
          _persistLiveSession();
        }
        break;
      case AppLifecycleState.resumed:
        _onReturnedToForeground();
        break;
    }
  }

  void _persistLiveSession() {
    final s = context.read<GameBloc>().state;
    if (s is GamePlaying && !s.session.isGameOver) {
      // ignore: discarded_futures
      sl<GameRepository>().saveSession(s.session);
    }
  }

  void _onReturnedToForeground() {
    if (!_leftToBackground) {
      // Notification shade / transient inactive — keep playing.
      if (_paused && !_pauseOpen && _isLivePlay) {
        _freezePlay(false);
      }
      return;
    }
    _leftToBackground = false;
    if (!_isLivePlay || _pauseOpen) return;
    final palette = AppPalettes.of(context.read<ThemeCubit>().state.selected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pauseOpen || !_isLivePlay) return;
      _confirmExit(context, palette);
    });
  }

  void _syncBombTimer(GameSession session) {
    if (_paused) {
      _bombUiTimer?.cancel();
      return;
    }
    final bomb = session.timeBomb;
    if (bomb?.row == _trackedBomb?.row &&
        bomb?.col == _trackedBomb?.col &&
        bomb?.expiresAtMs == _trackedBomb?.expiresAtMs) {
      return;
    }
    _trackedBomb = bomb;
    _bombUiTimer?.cancel();
    if (bomb == null) return;
    _bombUiTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      final s = context.read<GameBloc>().state;
      if (s is! GamePlaying || s.session.timeBomb == null) {
        _bombUiTimer?.cancel();
        return;
      }
      if (s.session.timeBomb!.isExpired) {
        context.read<GameBloc>().add(const BombExpired());
        _bombUiTimer?.cancel();
      }
    });
  }

  void _pushFx(_GameFx Function(_GameFx) update) {
    _fx.value = update(_fx.value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);
    final adsRemoved = context.watch<SettingsCubit>().state.adsRemoved;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _confirmExit(context, palette);
      },
      child: DragOverlayHost(
        controller: _drag,
        palette: palette,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: WoodBackground(
            palette: palette,
            themeId: context.read<ThemeCubit>().state.selected,
            animated: false,
            child: SafeArea(
              bottom: false,
              child: BlocConsumer<GameBloc, GameState>(
          buildWhen: (prev, next) {
            if (prev is GamePlaying && next is GamePlaying) {
              final a = prev.session;
              final b = next.session;
              if (a.score != b.score ||
                  a.movesMade != b.movesMade ||
                  a.bestScore != b.bestScore ||
                  a.timeBomb != b.timeBomb ||
                  a.isGameOver != b.isGameOver ||
                  prev.lastScoreGained != next.lastScoreGained ||
                  prev.praise != next.praise ||
                  prev.showCombo != next.showCombo ||
                  prev.bombSpawned != next.bombSpawned ||
                  prev.boardNuked != next.boardNuked ||
                  prev.allClear != next.allClear ||
                  prev.linesJustCleared != next.linesJustCleared ||
                  prev.hadColorBonus != next.hadColorBonus ||
                  !listEquals(prev.clearedRows, next.clearedRows) ||
                  !listEquals(prev.clearedCols, next.clearedCols) ||
                  !listEquals(prev.blastCells, next.blastCells) ||
                  prev.clearFxColors != next.clearFxColors ||
                  !listEquals(
                    prev.placementAnimCells,
                    next.placementAnimCells,
                  )) {
                return true;
              }
              // Grid cell changes (placement / clear) — compare refs first.
              if (!identical(a.grid, b.grid)) {
                for (var r = 0; r < a.grid.length; r++) {
                  if (!identical(a.grid[r], b.grid[r]) &&
                      !listEquals(a.grid[r], b.grid[r])) {
                    return true;
                  }
                }
              }
              // Conveyor-only recycle → skip full game rebuild (tray is local).
              return false;
            }
            return prev.runtimeType != next.runtimeType || prev != next;
          },
          listenWhen: (prev, next) {
            if (prev is GamePlaying && next is GamePlaying) {
              // Survive clock keeps lastScoreGained — do not re-fire clear FX.
              if (prev.session.movesMade == next.session.movesMade &&
                  prev.lastScoreGained == next.lastScoreGained &&
                  prev.praise == next.praise &&
                  prev.bombSpawned == next.bombSpawned &&
                  prev.allClear == next.allClear &&
                  prev.boardNuked == next.boardNuked &&
                  prev.linesJustCleared == next.linesJustCleared &&
                  prev.bombDefused == next.bombDefused &&
                  prev.session.timeBomb == next.session.timeBomb &&
                  listEquals(prev.blastCells, next.blastCells)) {
                return false;
              }
            }
            return true;
          },
          listener: (context, state) async {
            if (state is GamePlaying) {
              _syncBombTimer(state.session);
              if (state.bombSpawned) {
                _pushFx(
                  (f) => f.copyWith(
                    showBombArmed: true,
                    bombKind: state.session.timeBomb?.kind ?? BombKind.conveyor,
                  ),
                );
                Future<void>.delayed(1100.ms, () {
                  if (mounted) {
                    _pushFx((f) => f.copyWith(showBombArmed: false));
                  }
                });
              }
            }
            if (state is GamePlaying &&
                (state.lastScoreGained > 0 ||
                    state.praise != MovePraise.none)) {
              final cleared =
                  state.clearedRows.isNotEmpty ||
                  state.clearedCols.isNotEmpty ||
                  state.blastCells.isNotEmpty;
              _pushFx((f) {
                final big = state.allClear ||
                    state.boardNuked ||
                    state.linesJustCleared >= 4;
                final bigFire = state.linesJustCleared > 1 ||
                    state.blastCells.isNotEmpty ||
                    state.bombDefused ||
                    state.boardNuked;
                var next = f.copyWith(
                  showCombo: false,
                  showBurst: false,
                  showBlast: bigFire,
                  showBoardNuke: false,
                  showClearCele: false,
                  celeLines: state.linesJustCleared,
                  celeAllClear: state.allClear || state.boardNuked,
                  celeBonus: state.lastScoreGained,
                );
                if (state.lastScoreGained > 0 &&
                    state.session.mode != GameMode.zen &&
                    f.floatingScore == null) {
                  _hudHeldScore =
                      state.session.score - state.lastScoreGained;
                  next = next.copyWith(floatingScore: state.lastScoreGained);
                }
                if (cleared) {
                  next = next.copyWith(burstSeed: f.burstSeed + 1);
                }
                if (state.praise != MovePraise.none && !big) {
                  next = next.copyWith(
                    praise: state.praise,
                    praiseKey: f.praiseKey + 1,
                  );
                }
                return next;
              });
              final hold = 3000;
              Future<void>.delayed(Duration(milliseconds: hold), () {
                if (mounted) {
                  _pushFx(
                    (f) => f.copyWith(
                      showCombo: false,
                      showBurst: false,
                      showBlast: false,
                      showBoardNuke: false,
                      showClearCele: false,
                      praise: MovePraise.none,
                    ),
                  );
                }
              });
            }
            if (state is GameOverState && !_gameOverShown) {
              _gameOverShown = true;
              final removed = context.read<SettingsCubit>().state.adsRemoved;
              // Best interstitial moment: natural break after a run ends.
              await sl<AdService>().showInterstitial(adsRemoved: removed);
              if (!context.mounted) return;
              await _showGameOver(context, state, palette);
              if (context.mounted) {
                context.read<DailyChallengeCubit>().refresh();
              }
            }
          },
          builder: (context, state) {
            return TickerMode(
              enabled: !_paused,
              child: IgnorePointer(
                ignoring: _paused,
                child: Stack(
                    children: [
                      if (state is GameLoading || state is GameInitial)
                        Center(
                          child: CircularProgressIndicator(
                            color: palette.accentPrimary,
                          ),
                        )
                      else if (state is GamePlaying)
                        _buildPlaying(context, state, palette)
                      else if (state is GameTimeUpState)
                        _TimeUpLayer(
                          session: state.session,
                          isNewBest: state.isNewBest,
                          palette: palette,
                          playing: _buildPlaying(
                            context,
                            GamePlaying(state.session),
                            palette,
                          ),
                        )
                      else if (state is GameOverState)
                        _buildPlaying(
                          context,
                          GamePlaying(state.session),
                          palette,
                        ),
                      ValueListenableBuilder<_GameFx>(
                        valueListenable: _fx,
                        builder: (context, fx, _) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (fx.showBlast)
                                Align(
                                  alignment: const Alignment(0, 0.08),
                                  child: SizedBox(
                                    width: 420,
                                    height: 420,
                                    child: BlastBurst(
                                      key: ValueKey('fire_${fx.burstSeed}'),
                                      seed: fx.burstSeed,
                                      colors: [
                                        const Color(0xFFFF6D00),
                                        const Color(0xFFFF1744),
                                        const Color(0xFFFFEA00),
                                        palette.comboGold,
                                        palette.accentPrimary,
                                      ],
                                    ),
                                  ),
                                ),
                              if (fx.floatingScore != null)
                                Positioned.fill(
                                  child: ClearScoreFly(
                                    key: const ValueKey('score_fly'),
                                    amount: fx.floatingScore!,
                                    lines: fx.celeLines,
                                    allClear: fx.celeAllClear,
                                    palette: palette,
                                    targetKey: _scoreHudKey,
                                    onArrived: () => _onScoreFlyArrived(),
                                  ),
                                ),
                              if (fx.showBurst && PerfTier.instance.screenBurst)
                                Align(
                                  alignment: const Alignment(0, -0.05),
                                  child: SizedBox(
                                    width: 260,
                                    height: 260,
                                    child: ClearBurst(
                                      seed: fx.burstSeed,
                                      intense: true,
                                      colors: [
                                        palette.comboGold,
                                        palette.accentPrimary,
                                        palette.accentSecondary,
                                        ...palette.blocks.take(3),
                                      ],
                                    ),
                                  ),
                                ),
                              if (fx.praise != MovePraise.none)
                                MovePraiseBanner(
                                  key: ValueKey('praise_${fx.praiseKey}'),
                                  praise: fx.praise,
                                  palette: palette,
                                ),
                              if (fx.showBombArmed)
                                BombArmedBanner(
                                  palette: palette,
                                  kind: fx.bombKind,
                                ),
                              if (fx.showBoardNuke)
                                BoardNukeOverlay(
                                  palette: palette,
                                  bonus: fx.nukeBonus,
                                ),
                              if (fx.showCombo)
                                Positioned(
                                  top: 100,
                                  right: 16,
                                  child:
                                      Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: palette.comboGold
                                                  .withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: palette.comboGold,
                                              ),
                                            ),
                                            child: Text(
                                              'COMBO ×1.5!',
                                              style: AppTextStyles.section(
                                                palette.comboGold,
                                              ),
                                            ),
                                          )
                                          .animate()
                                          .slideX(
                                            begin: 1,
                                            end: 0,
                                            duration: 300.ms,
                                          )
                                          .then(delay: 200.ms)
                                          .fadeOut(duration: 300.ms),
                                ),
                            ],
                          );
                        },
                      ),
                      Positioned(
                        left: -9999,
                        child: RepaintBoundary(
                          key: _shareKey,
                          child: state is GamePlaying ||
                                  state is GameOverState ||
                                  state is GameTimeUpState
                              ? ShareCardPainter.buildCard(
                                  session: switch (state) {
                                    GamePlaying(:final session) => session,
                                    GameOverState(:final session) => session,
                                    GameTimeUpState(:final session) => session,
                                    _ => (state as GamePlaying).session,
                                  },
                                  palette: palette,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
              ),
            ),
          ),
          bottomNavigationBar: BannerAdBar(adsRemoved: adsRemoved),
        ),
      ),
    );
  }

  Widget _buildPlaying(
    BuildContext context,
    GamePlaying state,
    ColorPalette palette,
  ) {
    final session = state.session;
    final modeLabel = switch (session.mode) {
      GameMode.classic => 'Classic · Survive',
      GameMode.daily => 'Daily · 1.5× score',
      GameMode.zen => 'Zen · No bombs · Endless',
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final pad = (w * 0.008).clamp(2.0, 6.0);

        // Compact chrome so the square board can fill the screen.
        final headerH = 30.0;
        final trayH = (h * 0.1).clamp(72.0, 96.0);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              const SizedBox(height: 8),
              SizedBox(
                height: headerH,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Pause',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onPressed: () => _confirmExit(context, palette),
                      icon: Icon(
                        Icons.pause_rounded,
                        color: palette.textPrimary,
                        size: 26,
                      ),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppConstants.appName,
                              style: AppTextStyles.section(
                                palette.textPrimary,
                              ).copyWith(height: 1.05),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              modeLabel,
                              style: AppTextStyles.mini(
                                palette.textSecondary,
                              ).copyWith(height: 1.05),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ScoreDisplay(
                score: _hudHeldScore ?? session.score,
                bestScore: session.bestScore,
                palette: palette,
                isNewBest:
                    session.score > 0 &&
                    session.score >= session.bestScore &&
                    session.mode != GameMode.zen,
                hideScore: session.mode == GameMode.zen,
                movesMade: session.movesMade,
                mode: session.mode,
                scoreSlotKey: _scoreHudKey,
              ),
              const SizedBox(height: 2),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridBox) {
                    // Leave a strip above the square for the survive clock.
                    final timerReserve = 46.0;
                    final side = math.min(
                      gridBox.maxWidth,
                      (gridBox.maxHeight - timerReserve).clamp(
                        120.0,
                        gridBox.maxHeight,
                      ),
                    );

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SurviveTimerHud(palette: palette),
                          const SizedBox(height: 6),
                          GameGrid(
                            gridKey: _gridKey,
                            grid: session.grid,
                            palette: palette,
                            maxWidth: side,
                            ghostListenable: _drag.ghost,
                            clearedRows: state.clearedRows,
                            clearedCols: state.clearedCols,
                            placementCells: state.placementAnimCells,
                            blastCells: state.blastCells,
                            clearFxColors: state.clearFxColors,
                            timeBomb: session.timeBomb,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              PieceTray(
                pieces: session.currentPieces,
                palette: palette,
                grid: session.grid,
                gridKey: _gridKey,
                drag: _drag,
                height: trayH,
                stripBombs: session.mode == GameMode.zen,
                onDrop: (pieceId, row, col) {
                  context.read<GameBloc>().add(
                    PiecePlaced(pieceId: pieceId, row: row, col: col),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _onScoreFlyArrived() {
    if (!mounted) return;
    _pushFx((f) => f.copyWith(clearFloating: true));
    if (_hudHeldScore == null) return;
    setState(() => _hudHeldScore = null);
  }

  void _freezePlay(bool freeze) {
    if (_paused == freeze) return;
    setState(() => _paused = freeze);
    if (!mounted) return;
    final bloc = context.read<GameBloc>();
    bloc.add(freeze ? const GamePaused() : const GameResumed());
    if (freeze) {
      _drag.handleLifecycleInterrupt(completePending: false);
      _bombUiTimer?.cancel();
    } else {
      final s = bloc.state;
      if (s is GamePlaying) _syncBombTimer(s.session);
    }
  }

  Future<void> _confirmExit(BuildContext context, ColorPalette palette) async {
    if (_pauseOpen) return;
    _pauseOpen = true;
    _freezePlay(true);
    final blocState = context.read<GameBloc>().state;
    final session = switch (blocState) {
      GamePlaying(:final session) => session,
      GameOverState(:final session) => session,
      GameTimeUpState(:final session) => session,
      _ => null,
    };
    var leave = false;
    try {
      leave = await showGameExitSheet(
        context: context,
        palette: palette,
        mode: session?.mode ?? widget.mode,
        score: session?.score ?? 0,
        moves: session?.movesMade ?? 0,
      );
      if (leave && context.mounted) {
        // Persist board + pieces (and current run stats). On next Continue,
        // classic score/moves reset to 0; lifetime best stays in stats.
        if (session != null && !session.isGameOver) {
          await sl<GameRepository>().saveSession(session);
        }
        if ((session?.movesMade ?? 0) >= 5) {
          final removed = context.read<SettingsCubit>().state.adsRemoved;
          await sl<AdService>().showInterstitial(adsRemoved: removed);
        }
        if (context.mounted) Navigator.of(context).pop();
      }
    } finally {
      _pauseOpen = false;
      if (mounted && !leave) {
        final life = WidgetsBinding.instance.lifecycleState;
        final inBackground = life == AppLifecycleState.paused ||
            life == AppLifecycleState.hidden ||
            life == AppLifecycleState.detached ||
            _leftToBackground;
        if (inBackground) {
          _freezePlay(true);
        } else if (life == AppLifecycleState.resumed) {
          _freezePlay(false);
        }
      }
    }
  }

  Future<void> _showGameOver(
    BuildContext context,
    GameOverState state,
    ColorPalette palette,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocProvider(
          create: (_) => GameOverBonusCubit(state.session.score),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black54,
              child: Center(
                child: BlocBuilder<GameOverBonusCubit, GameOverBonusState>(
                  builder: (ctx, bonus) {
                    return _GameOverCard(
                          session: state.session,
                          displayScore: bonus.displayScore,
                          isNewBest: state.isNewBest ||
                              (bonus.displayScore > state.session.bestScore &&
                                  state.session.mode != GameMode.zen),
                          palette: palette,
                          bonusClaimed: bonus.bonusClaimed,
                          onWatchBonus: state.session.mode == GameMode.zen
                              ? null
                              : () async {
                                  if (bonus.bonusClaimed) return;
                                  final ok = await sl<AdService>().showRewarded(
                                    onEarned: () {},
                                  );
                                  if (!ctx.mounted) return;
                                  if (!ok) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Rewarded ad not ready. Try again shortly.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  ctx.read<GameOverBonusCubit>().claimBonus(250);
                                  final displayScore = ctx
                                      .read<GameOverBonusCubit>()
                                      .state
                                      .displayScore;
                                  final stats =
                                      await sl<GameRepository>().loadStats();
                                  if (state.session.mode == GameMode.classic &&
                                      displayScore > stats.classicBest) {
                                    await sl<GameRepository>().saveStats(
                                      stats.copyWith(classicBest: displayScore),
                                    );
                                  } else if (state.session.mode ==
                                          GameMode.daily &&
                                      displayScore > stats.dailyBest) {
                                    await sl<GameRepository>().saveStats(
                                      stats.copyWith(dailyBest: displayScore),
                                    );
                                  }
                                },
                          onPlayAgain: () async {
                            Navigator.pop(ctx);
                            final removed = context
                                .read<SettingsCubit>()
                                .state
                                .adsRemoved;
                            await sl<AdService>().showInterstitial(
                              adsRemoved: removed,
                            );
                            if (!context.mounted) return;
                            _gameOverShown = false;
                            context.read<GameBloc>().add(const GameReset());
                          },
                          onHome: () async {
                            Navigator.pop(ctx);
                            final removed = context
                                .read<SettingsCubit>()
                                .state
                                .adsRemoved;
                            await sl<AdService>().showInterstitial(
                              adsRemoved: removed,
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          onShare: state.session.mode == GameMode.daily
                              ? () async {
                                  await sl<ShareService>().shareDailyResult(
                                    session: state.session,
                                    repaintKey: _shareKey,
                                  );
                                }
                              : null,
                        )
                        .animate()
                        .slideY(
                          begin: 0.35,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeIn(duration: 280.ms);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

}

class _TimeUpLayer extends StatefulWidget {
  const _TimeUpLayer({
    required this.session,
    required this.isNewBest,
    required this.palette,
    required this.playing,
  });

  final GameSession session;
  final bool isNewBest;
  final ColorPalette palette;
  final Widget playing;

  @override
  State<_TimeUpLayer> createState() => _TimeUpLayerState();
}

class _TimeUpLayerState extends State<_TimeUpLayer> {
  bool _busy = false;

  Future<void> _watchAd() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final removed = context.read<SettingsCubit>().state.adsRemoved;
      var ok = removed;
      if (!removed) {
        ok = await sl<AdService>().showRewarded(onEarned: () {});
      }
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rewarded ad not ready. Try again shortly.'),
          ),
        );
        return;
      }
      context.read<GameBloc>().add(const SurviveExtraTimeGranted());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        TickerMode(
          enabled: false,
          child: IgnorePointer(child: widget.playing),
        ),
        TimeUpResultView(
          session: widget.session,
          isNewBest: widget.isNewBest,
          palette: widget.palette,
          busy: _busy,
          onRestart: () {
            context.read<GameBloc>().add(const GameReset());
          },
          onHome: () {
            context.read<GameBloc>().add(const SurviveGiveUp());
            Navigator.of(context).pop();
          },
          onWatchAd: _watchAd,
        ),
      ],
    );
  }
}


class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.session,
    required this.displayScore,
    required this.isNewBest,
    required this.palette,
    required this.onPlayAgain,
    required this.onHome,
    this.onWatchBonus,
    this.bonusClaimed = false,
    this.onShare,
  });

  final GameSession session;
  final int displayScore;
  final bool isNewBest;
  final ColorPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
  final VoidCallback? onWatchBonus;
  final bool bonusClaimed;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return WoodPanel(
      palette: palette,
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 292,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GAME OVER',
              style: AppTextStyles.gameOver(palette.textPrimary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: palette.accentPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: palette.accentPrimary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                RankingEngine.tierLabel(
                  RankingEngine.tierFor(
                    movesMade: session.movesMade,
                    activeSurviveMs: session.activeSurviveMs,
                  ),
                ),
                style: AppTextStyles.section(palette.accentSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<int>(
              key: ValueKey(displayScore),
              tween: IntTween(begin: 0, end: displayScore),
              duration: 900.ms,
              curve: Curves.easeOut,
              builder: (_, value, child) => Text(
                NumberFormat('#,###').format(value),
                style: AppTextStyles.score(palette.accentSecondary),
              ),
            ),
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Text('NEW BEST!', style: AppTextStyles.section(palette.comboGold))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.08, 1.08),
                    duration: 600.ms,
                  ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('Moves', '${session.movesMade}', palette),
                _stat('Rank pts', '${session.rankPoints}', palette),
                _stat(
                  'Tier',
                  RankingEngine.tierLabel(
                    RankingEngine.tierFor(
                      movesMade: session.movesMade,
                      activeSurviveMs: session.activeSurviveMs,
                    ),
                  ),
                  palette,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('Lines', '${session.linesCleared}', palette),
                _stat('Combo', '${session.comboCount}×', palette),
                _stat('Blocks', '${session.blocksPlaced}', palette),
              ],
            ),
            const SizedBox(height: 20),
            if (onWatchBonus != null) ...[
              AppButton(
                label: bonusClaimed ? 'BONUS CLAIMED ✓' : 'WATCH AD · +250',
                style: AppButtonStyle.secondary,
                onTap: bonusClaimed ? null : onWatchBonus,
              ),
              const SizedBox(height: 10),
            ],
            AppButton(label: 'PLAY AGAIN', onTap: onPlayAgain),
            const SizedBox(height: 12),
            AppButton(
              label: 'MAIN MENU',
              style: AppButtonStyle.secondary,
              onTap: onHome,
            ),
            if (onShare != null) ...[
              const SizedBox(height: 12),
              AppButton(
                label: 'SHARE',
                style: AppButtonStyle.ghost,
                onTap: onShare,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, ColorPalette palette) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.section(palette.textPrimary)),
        Text(label, style: AppTextStyles.mini(palette.textSecondary)),
      ],
    );
  }
}

class _GameFx {
  const _GameFx({
    this.floatingScore,
    this.showCombo = false,
    this.showBurst = false,
    this.showBlast = false,
    this.burstSeed = 0,
    this.praise = MovePraise.none,
    this.praiseKey = 0,
    this.showBombArmed = false,
    this.showBoardNuke = false,
    this.nukeBonus = 0,
    this.bombKind = BombKind.conveyor,
    this.showClearCele = false,
    this.celeLines = 0,
    this.celeAllClear = false,
    this.celeBonus = 0,
  });

  final int? floatingScore;
  final bool showCombo;
  final bool showBurst;
  final bool showBlast;
  final int burstSeed;
  final MovePraise praise;
  final int praiseKey;
  final bool showBombArmed;
  final bool showBoardNuke;
  final int nukeBonus;
  final BombKind bombKind;
  final bool showClearCele;
  final int celeLines;
  final bool celeAllClear;
  final int celeBonus;

  _GameFx copyWith({
    int? floatingScore,
    bool clearFloating = false,
    bool? showCombo,
    bool? showBurst,
    bool? showBlast,
    int? burstSeed,
    MovePraise? praise,
    int? praiseKey,
    bool? showBombArmed,
    bool? showBoardNuke,
    int? nukeBonus,
    BombKind? bombKind,
    bool? showClearCele,
    int? celeLines,
    bool? celeAllClear,
    int? celeBonus,
  }) {
    return _GameFx(
      floatingScore: clearFloating
          ? null
          : (floatingScore ?? this.floatingScore),
      showCombo: showCombo ?? this.showCombo,
      showBurst: showBurst ?? this.showBurst,
      showBlast: showBlast ?? this.showBlast,
      burstSeed: burstSeed ?? this.burstSeed,
      praise: praise ?? this.praise,
      praiseKey: praiseKey ?? this.praiseKey,
      showBombArmed: showBombArmed ?? this.showBombArmed,
      showBoardNuke: showBoardNuke ?? this.showBoardNuke,
      nukeBonus: nukeBonus ?? this.nukeBonus,
      bombKind: bombKind ?? this.bombKind,
      showClearCele: showClearCele ?? this.showClearCele,
      celeLines: celeLines ?? this.celeLines,
      celeAllClear: celeAllClear ?? this.celeAllClear,
      celeBonus: celeBonus ?? this.celeBonus,
    );
  }
}
