import 'dart:async';
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
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/ads/banner_ad_bar.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/bomb_widgets.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/clear_burst.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/drag_controller.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_exit_sheet.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/game_grid.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/move_praise_banner.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/piece_tray.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:colorzen_block_puzzle/services/share_service.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({
    super.key,
    required this.mode,
    this.forceNew = false,
  });

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

class _GameViewState extends State<_GameView> {
  final _gridKey = GlobalKey();
  final _shareKey = GlobalKey();
  final _drag = PieceDragController();

  final _fx = ValueNotifier<_GameFx>(const _GameFx());
  bool _gameOverShown = false;
  Timer? _bombUiTimer;
  TimeBomb? _trackedBomb;

  @override
  void dispose() {
    _bombUiTimer?.cancel();
    _fx.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _syncBombTimer(GameSession session) {
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
                  prev.hadColorBonus != next.hadColorBonus ||
                  !listEquals(prev.clearedRows, next.clearedRows) ||
                  !listEquals(prev.clearedCols, next.clearedCols) ||
                  !listEquals(prev.blastCells, next.blastCells) ||
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
          listener: (context, state) async {
            if (state is GamePlaying) {
              _syncBombTimer(state.session);
              if (state.bombSpawned) {
                _pushFx(
                  (f) => f.copyWith(
                    showBombArmed: true,
                    bombKind:
                        state.session.timeBomb?.kind ?? BombKind.conveyor,
                  ),
                );
                Future<void>.delayed(1800.ms, () {
                  if (mounted) {
                    _pushFx((f) => f.copyWith(showBombArmed: false));
                  }
                });
              }
              if (state.boardNuked) {
                _pushFx(
                  (f) => f.copyWith(
                    showBoardNuke: true,
                    nukeBonus: state.lastScoreGained,
                  ),
                );
                Future<void>.delayed(1600.ms, () {
                  if (mounted) {
                    _pushFx(
                      (f) => f.copyWith(showBoardNuke: false, nukeBonus: 0),
                    );
                  }
                });
              }
            }
            if (state is GamePlaying &&
                (state.lastScoreGained > 0 ||
                    state.praise != MovePraise.none)) {
              final cleared = state.clearedRows.isNotEmpty ||
                  state.clearedCols.isNotEmpty ||
                  state.blastCells.isNotEmpty;
              _pushFx((f) {
                var next = f.copyWith(
                  showCombo: state.showCombo,
                  showBurst: cleared && !state.boardNuked,
                );
                if (state.lastScoreGained > 0) {
                  next = next.copyWith(floatingScore: state.lastScoreGained);
                }
                if (cleared) {
                  next = next.copyWith(burstSeed: f.burstSeed + 1);
                }
                if (state.praise != MovePraise.none) {
                  next = next.copyWith(
                    praise: state.praise,
                    praiseKey: f.praiseKey + 1,
                  );
                }
                return next;
              });
              Future<void>.delayed(900.ms, () {
                if (mounted) {
                  _pushFx(
                    (f) => f.copyWith(
                      clearFloating: true,
                      showCombo: false,
                      showBurst: false,
                      praise: MovePraise.none,
                    ),
                  );
                }
              });
            }
            if (state is GameOverState && !_gameOverShown) {
              _gameOverShown = true;
              final removed = context.read<SettingsCubit>().state.adsRemoved;
              await sl<AdService>().showInterstitial(adsRemoved: removed);
              if (!context.mounted) return;
              await _showGameOver(context, state, palette);
              if (context.mounted) {
                context.read<DailyChallengeCubit>().refresh();
              }
            }
          },
          builder: (context, state) {
            return Scaffold(
              body: WoodBackground(
                palette: palette,
                animated: false,
                child: SafeArea(
                  bottom: false,
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
                            children: [
                              if (fx.floatingScore != null)
                                Align(
                                alignment: const Alignment(0, -0.25),
                                child: Text(
                                  '+${fx.floatingScore}',
                                  style: AppTextStyles.score(palette.comboGold)
                                      .copyWith(
                                    fontSize: 42,
                                    shadows: [
                                      Shadow(
                                        color: palette.comboGold
                                            .withValues(alpha: 0.6),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                )
                                    .animate()
                                    .scale(
                                      begin: const Offset(0.6, 0.6),
                                      end: const Offset(1.1, 1.1),
                                      duration: 280.ms,
                                      curve: Curves.easeOutBack,
                                    )
                                    .moveY(
                                      begin: 0,
                                      end: -56,
                                      duration: 700.ms,
                                    )
                                    .fadeOut(
                                      delay: 280.ms,
                                      duration: 420.ms,
                                    ),
                              ),
                            if (fx.showBurst)
                              Align(
                                alignment: const Alignment(0, -0.05),
                                child: SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: ClearBurst(
                                    seed: fx.burstSeed,
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
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.comboGold
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border:
                                        Border.all(color: palette.comboGold),
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
                        child: state is GamePlaying || state is GameOverState
                            ? ShareCardPainter.buildCard(
                                session: state is GamePlaying
                                    ? state.session
                                    : (state as GameOverState).session,
                                palette: palette,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: BannerAdBar(adsRemoved: adsRemoved),
          );
        },
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
        final pad = (w * 0.04).clamp(10.0, 18.0);

        // Reserve fixed chrome first, then size grid to leftover space.
        final headerH = 44.0;
        final gaps = 12.0;
        final trayH = (h * 0.155).clamp(96.0, 128.0);
        // Score HUD (BEST / SCORE / MOVES).
        final scoreEstimate = session.mode == GameMode.zen ? 56.0 : 64.0;
        final reserved = headerH + scoreEstimate + trayH + gaps;
        final gridBudget = (h - reserved).clamp(160.0, h);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Column(
            children: [
              SizedBox(
                height: headerH,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Menu',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      onPressed: () => _confirmExit(context, palette),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: palette.textPrimary,
                        size: 20,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppConstants.appName,
                            style: AppTextStyles.section(palette.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            modeLabel,
                            style: AppTextStyles.mini(palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              ScoreDisplay(
                score: session.score,
                bestScore: session.bestScore,
                palette: palette,
                isNewBest: session.score > 0 &&
                    session.score >= session.bestScore &&
                    session.mode != GameMode.zen,
                hideScore: session.mode == GameMode.zen,
                movesMade: session.movesMade,
                mode: session.mode,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, gridBox) {
                    final side = [
                      gridBox.maxWidth,
                      gridBox.maxHeight,
                      gridBudget,
                      w - pad * 2,
                    ].reduce((a, b) => a < b ? a : b);

                    return Center(
                      child: ValueListenableBuilder<GhostState?>(
                        valueListenable: _drag.ghost,
                        builder: (context, ghost, child) {
                          return GameGrid(
                            gridKey: _gridKey,
                            grid: session.grid,
                            palette: palette,
                            maxWidth: side,
                            ghostMask: ghost?.mask,
                            ghostColor: ghost?.color,
                            isGhostValid: ghost?.valid ?? true,
                            clearedRows: state.clearedRows,
                            clearedCols: state.clearedCols,
                            placementCells: state.placementAnimCells,
                            blastCells: state.blastCells,
                            timeBomb: session.timeBomb,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
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
                        PiecePlaced(
                          pieceId: pieceId,
                          row: row,
                          col: col,
                        ),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmExit(
    BuildContext context,
    ColorPalette palette,
  ) async {
    final blocState = context.read<GameBloc>().state;
    final session = switch (blocState) {
      GamePlaying(:final session) => session,
      GameOverState(:final session) => session,
      _ => null,
    };
    final leave = await showGameExitSheet(
      context: context,
      palette: palette,
      mode: session?.mode ?? widget.mode,
      score: session?.score ?? 0,
      moves: session?.movesMade ?? 0,
    );
    if (leave && context.mounted) {
      Navigator.of(context).pop();
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
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black54,
            child: Center(
              child: _GameOverCard(
                session: state.session,
                isNewBest: state.isNewBest,
                palette: palette,
                onPlayAgain: () {
                  Navigator.pop(ctx);
                  _gameOverShown = false;
                  context.read<GameBloc>().add(const GameReset());
                },
                onHome: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pop();
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
                  .fadeIn(duration: 280.ms),
            ),
          ),
        );
      },
    );
  }
}

class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.session,
    required this.isNewBest,
    required this.palette,
    required this.onPlayAgain,
    required this.onHome,
    this.onShare,
  });

  final GameSession session;
  final bool isNewBest;
  final ColorPalette palette;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;
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
              tween: IntTween(begin: 0, end: session.score),
              duration: 1200.ms,
              curve: Curves.easeOut,
              builder: (_, value, child) => Text(
                NumberFormat('#,###').format(value),
                style: AppTextStyles.score(palette.accentSecondary),
              ),
            ),
            if (isNewBest) ...[
              const SizedBox(height: 8),
              Text(
                'NEW BEST!',
                style: AppTextStyles.section(palette.comboGold),
              )
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
            const SizedBox(height: 24),
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
    this.burstSeed = 0,
    this.praise = MovePraise.none,
    this.praiseKey = 0,
    this.showBombArmed = false,
    this.showBoardNuke = false,
    this.nukeBonus = 0,
    this.bombKind = BombKind.conveyor,
  });

  final int? floatingScore;
  final bool showCombo;
  final bool showBurst;
  final int burstSeed;
  final MovePraise praise;
  final int praiseKey;
  final bool showBombArmed;
  final bool showBoardNuke;
  final int nukeBonus;
  final BombKind bombKind;

  _GameFx copyWith({
    int? floatingScore,
    bool clearFloating = false,
    bool? showCombo,
    bool? showBurst,
    int? burstSeed,
    MovePraise? praise,
    int? praiseKey,
    bool? showBombArmed,
    bool? showBoardNuke,
    int? nukeBonus,
    BombKind? bombKind,
  }) {
    return _GameFx(
      floatingScore:
          clearFloating ? null : (floatingScore ?? this.floatingScore),
      showCombo: showCombo ?? this.showCombo,
      showBurst: showBurst ?? this.showBurst,
      burstSeed: burstSeed ?? this.burstSeed,
      praise: praise ?? this.praise,
      praiseKey: praiseKey ?? this.praiseKey,
      showBombArmed: showBombArmed ?? this.showBombArmed,
      showBoardNuke: showBoardNuke ?? this.showBoardNuke,
      nukeBonus: nukeBonus ?? this.nukeBonus,
      bombKind: bombKind ?? this.bombKind,
    );
  }
}
