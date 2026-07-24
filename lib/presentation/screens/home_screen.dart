import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/daily/daily_challenge_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/screens/game_screen.dart';
import 'package:colorzen_block_puzzle/presentation/screens/settings_screen.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/ads/banner_ad_bar.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _pageController;
  int _page = 0;
  bool _dailyLoading = false;

  static const _modes = [GameMode.classic, GameMode.daily, GameMode.zen];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final removed = context.read<SettingsCubit>().state.adsRemoved;
      sl<AdService>().setMenuAdsActive(active: true, adsRemoved: removed);
      // ignore: discarded_futures
      sl<AudioService>().ensureMusicPlaying();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GameMode get _currentMode => _modes[_page.clamp(0, _modes.length - 1)];

  void _openGame(GameMode mode, {bool forceNew = false}) {
    Navigator.of(context)
        .push(
      PageRouteBuilder<void>(
        transitionDuration: 320.ms,
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(mode: mode, forceNew: forceNew),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    )
        .then((_) {
      if (!mounted) return;
      setState(() {});
      // Game / interstitial can leave BGM paused — kick it on home again.
      // ignore: discarded_futures
      sl<AudioService>().ensureMusicPlaying();
    });
  }

  Future<void> _startDailyWithReward() async {
    if (_dailyLoading) return;
    setState(() => _dailyLoading = true);
    final ok = await sl<AdService>().showRewarded(onEarned: () {});
    if (!mounted) return;
    setState(() => _dailyLoading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Watch a short ad to start Daily Challenge.'),
        ),
      );
      return;
    }
    // Resume saved daily progress (board / score) if present.
    _openGame(GameMode.daily);
  }

  void _openSettings() {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: 300.ms,
        pageBuilder: (c, a, s) => const SettingsScreen(),
        transitionsBuilder: (c, a, s, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<GameSession?> _savedClassic() async {
    final s = await sl<GameRepository>().loadSession(GameMode.classic);
    if (s == null || s.isGameOver) return null;
    final hasPieces = s.currentPieces.any((p) => p != null);
    final hasBlocks = s.grid.any((row) => row.any((c) => c != null));
    if (!hasPieces && !hasBlocks && s.movesMade <= 0) return null;
    return s;
  }

  void _goTo(int index) {
    final next = index.clamp(0, _modes.length - 1);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    sl<HapticService>().selection();
    sl<AudioService>().playSfx(SfxType.tap);
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeCubit>().state;
    final palette = AppPalettes.of(themeState.selected);
    final daily = context.watch<DailyChallengeCubit>().state;
    final adsRemoved = context.watch<SettingsCubit>().state.adsRemoved;

    // Sync remove-ads without restarting an already-running menu timer.
    final ads = sl<AdService>();
    ads.setMenuAdsActive(active: true, adsRemoved: adsRemoved);

    final size = MediaQuery.sizeOf(context);
    final pad = (size.width * 0.05).clamp(14.0, 24.0);
    final cardSide = (math.min(size.width * 0.78, size.height * 0.42))
        .clamp(240.0, 360.0);

    return Scaffold(
      body: WoodBackground(
        palette: palette,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxHeight < 620;
                      // Portrait card: art + labels. Height leaves room so Column never overflows.
                      final cardWidth = compact
                          ? (cardSide * 0.9).clamp(220.0, 300.0)
                          : cardSide;
                      final heroHeight = cardWidth * 1.28;

                      Widget actions() => _ModeActions(
                            mode: _currentMode,
                            palette: palette,
                            daily: daily,
                            dailyLoading: _dailyLoading,
                            savedClassic: _savedClassic(),
                            onContinueClassic: () =>
                                _openGame(GameMode.classic),
                            onNewClassic: () =>
                                _openGame(GameMode.classic, forceNew: true),
                            onStartDaily: _startDailyWithReward,
                            onPlayZen: () => _openGame(GameMode.zen),
                          )
                              .animate(key: ValueKey(_currentMode))
                              .fadeIn(duration: 220.ms)
                              .slideY(begin: 0.08, end: 0);

                      final header = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: size.height < 700 ? 4 : 10),
                          Image.asset(
                            AppConstants.appLogoAsset,
                            width: size.width < 360 ? 96 : 112,
                            height: size.width < 360 ? 96 : 112,
                            filterQuality: FilterQuality.high,
                          )
                              .animate()
                              .fadeIn(duration: 450.ms)
                              .slideY(begin: -0.1, end: 0),
                          Text(
                            'Swipe to choose a mode',
                            style: AppTextStyles.mini(palette.textSecondary),
                          ),
                          SizedBox(height: size.height < 700 ? 10 : 16),
                        ],
                      );

                      final carousel = SizedBox(
                        height: heroHeight + 8,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: _modes.length,
                              onPageChanged: (i) {
                                setState(() => _page = i);
                                sl<HapticService>().selection();
                              },
                              itemBuilder: (context, index) {
                                final mode = _modes[index];
                                final active = index == _page;
                                return AnimatedScale(
                                  scale: active ? 1.0 : 0.94,
                                  duration: const Duration(milliseconds: 220),
                                  child: Center(
                                    child: _ModeHeroCard(
                                      mode: mode,
                                      palette: palette,
                                      width: cardWidth,
                                      height: heroHeight,
                                      daily: daily,
                                      selected: active,
                                      onTap: () {
                                        if (mode == GameMode.daily) {
                                          _startDailyWithReward();
                                        } else {
                                          _openGame(mode);
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            // No left arrow on the first card.
                            if (_page > 0)
                              Positioned(
                                left: 0,
                                child: _IosChevron(
                                  direction: AxisDirection.left,
                                  palette: palette,
                                  onTap: () => _goTo(_page - 1),
                                ),
                              ),
                            if (_page < _modes.length - 1)
                              Positioned(
                                right: 0,
                                child: _IosChevron(
                                  direction: AxisDirection.right,
                                  palette: palette,
                                  onTap: () => _goTo(_page + 1),
                                ),
                              ),
                          ],
                        ),
                      );

                      final footer = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 10),
                          _PageDots(
                            count: _modes.length,
                            index: _page,
                            palette: palette,
                          ),
                          const SizedBox(height: 14),
                          actions(),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openSettings,
                            child: Text(
                              'Settings',
                              style:
                                  AppTextStyles.mini(palette.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      );

                      if (compact) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              header,
                              carousel,
                              footer,
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: [
                          header,
                          Expanded(child: Center(child: carousel)),
                          footer,
                        ],
                      );
                    },
                  ),
                ),
              ),
              BannerAdBar(adsRemoved: adsRemoved),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeActions extends StatelessWidget {
  const _ModeActions({
    required this.mode,
    required this.palette,
    required this.daily,
    required this.dailyLoading,
    required this.savedClassic,
    required this.onContinueClassic,
    required this.onNewClassic,
    required this.onStartDaily,
    required this.onPlayZen,
  });

  final GameMode mode;
  final ColorPalette palette;
  final DailyChallengeState daily;
  final bool dailyLoading;
  final Future<GameSession?> savedClassic;
  final VoidCallback onContinueClassic;
  final VoidCallback onNewClassic;
  final VoidCallback onStartDaily;
  final VoidCallback onPlayZen;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      GameMode.classic => FutureBuilder<GameSession?>(
          future: savedClassic,
          builder: (context, snap) {
            final saved = snap.data;
            return Column(
              children: [
                AppButton(
                  label: 'CONTINUE',
                  subtitle: saved == null
                      ? null
                      : 'Score ${NumberFormat('#,###').format(saved.score)} · ${saved.movesMade} moves',
                  leading: const Icon(Icons.play_arrow_rounded),
                  onTap: onContinueClassic,
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: 'NEW GAME',
                  style: AppButtonStyle.secondary,
                  leading: const Icon(Icons.refresh_rounded),
                  onTap: onNewClassic,
                ),
              ],
            );
          },
        ),
      GameMode.daily => AppButton(
          label: dailyLoading ? 'LOADING…' : 'START NOW',
          subtitle: daily.completed
              ? 'Done · Score ${daily.score}'
              : 'Watch ad · ${daily.countdown}',
          leading: Icon(
            dailyLoading ? Icons.hourglass_top_rounded : Icons.ondemand_video,
          ),
          onTap: dailyLoading ? null : onStartDaily,
        ),
      GameMode.zen => AppButton(
          label: 'PLAY',
          leading: const Icon(Icons.spa_rounded),
          onTap: onPlayZen,
        ),
    };
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.palette,
  });

  final int count;
  final int index;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: active
                ? palette.accentPrimary
                : palette.textSecondary.withValues(alpha: 0.35),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: palette.accentPrimary.withValues(alpha: 0.45),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _IosChevron extends StatelessWidget {
  const _IosChevron({
    required this.direction,
    required this.palette,
    required this.onTap,
  });

  final AxisDirection direction;
  final ColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLeft = direction == AxisDirection.left;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.surface.withValues(alpha: 0.72),
            border: Border.all(
              color: palette.accentPrimary.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Transform.flip(
            flipX: isLeft,
            child: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeHeroCard extends StatelessWidget {
  const _ModeHeroCard({
    required this.mode,
    required this.palette,
    required this.width,
    required this.height,
    required this.daily,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final ColorPalette palette;
  final double width;
  final double height;
  final DailyChallengeState daily;
  final bool selected;
  final VoidCallback onTap;

  static String assetFor(GameMode mode) => switch (mode) {
        GameMode.classic => 'assets/images/mode_classic_3d.png',
        GameMode.daily => 'assets/images/mode_daily_3d.png',
        GameMode.zen => 'assets/images/mode_zen_3d.png',
      };

  _ModeVisual get _visual {
    final blocks = palette.blocks;
    return switch (mode) {
      GameMode.classic => _ModeVisual(
          title: 'CLASSIC',
          subtitle: 'Score · Bombs · Survive',
          accent: palette.accentSecondary,
          glow: palette.accentPrimary,
        ),
      GameMode.daily => _ModeVisual(
          title: 'DAILY',
          subtitle: daily.completed
              ? 'Done · Score ${daily.score}'
              : 'Watch ad · Shared puzzle',
          accent: Color.lerp(blocks[2], palette.accentPrimary, 0.35)!,
          glow: Color.lerp(blocks[4 % blocks.length], Colors.white, 0.25)!,
        ),
      GameMode.zen => _ModeVisual(
          title: 'ZEN',
          subtitle: 'No score · Never ends',
          accent: Color.lerp(blocks[1], palette.accentPrimary, 0.25)!,
          glow: Color.lerp(blocks[5 % blocks.length], Colors.white, 0.2)!,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final v = _visual;
    final radius = (width * 0.08).clamp(18.0, 28.0);
    final pad = (width * 0.035).clamp(9.0, 12.0);
    final artRadius = radius * 0.65;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: v.glow.withValues(alpha: selected ? 0.5 : 0.22),
                blurRadius: selected ? 28 : 14,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: WoodPanel(
            palette: palette,
            radius: radius,
            borderColor: v.accent.withValues(alpha: 0.7),
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 0.75),
            child: Column(
              children: [
                // Fills remaining height — no AspectRatio overflow inside fixed slot.
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(artRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(
                          color: Color.lerp(
                            palette.gridBackground,
                            v.glow,
                            0.1,
                          )!,
                        ),
                        Image.asset(
                          assetFor(mode),
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, error, stack) => Center(
                            child: Icon(
                              Icons.image_rounded,
                              size: width * 0.28,
                              color: v.accent,
                            ),
                          ),
                        ),
                        IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  v.glow.withValues(alpha: 0.1),
                                  Colors.transparent,
                                  palette.background.withValues(alpha: 0.18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: pad * 0.55),
                Text(
                  v.title,
                  style: AppTextStyles.section(palette.textPrimary).copyWith(
                    fontSize: (width * 0.06).clamp(14.0, 18.0),
                    letterSpacing: 1.2,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: pad * 0.2),
                Text(
                  v.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mini(palette.textSecondary).copyWith(
                    fontSize: (width * 0.038).clamp(10.0, 12.0),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeVisual {
  const _ModeVisual({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.glow,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final Color glow;
}
