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

  static const _modes = [GameMode.classic, GameMode.daily, GameMode.zen];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
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
      if (mounted) setState(() {});
    });
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
                      final heroHeight = compact
                          ? (cardSide * 0.92).clamp(220.0, 300.0)
                          : cardSide;

                      Widget actions() => _ModeActions(
                            mode: _currentMode,
                            palette: palette,
                            daily: daily,
                            savedClassic: _savedClassic(),
                            onContinueClassic: () =>
                                _openGame(GameMode.classic),
                            onNewClassic: () =>
                                _openGame(GameMode.classic, forceNew: true),
                            onStartDaily: () => _openGame(GameMode.daily),
                            onPlayZen: () => _openGame(GameMode.zen),
                          )
                              .animate(key: ValueKey(_currentMode))
                              .fadeIn(duration: 220.ms)
                              .slideY(begin: 0.08, end: 0);

                      final header = Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: size.height < 700 ? 4 : 10),
                          ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                palette.accentPrimary,
                                palette.accentSecondary,
                                palette.accentPrimary,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              AppConstants.appName.toUpperCase(),
                              style: AppTextStyles.logo(Colors.white).copyWith(
                                fontSize: size.width < 360 ? 30 : 36,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
                                      side: heroHeight,
                                      daily: daily,
                                      selected: active,
                                      onTap: () => _openGame(mode),
                                    ),
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              left: 0,
                              child: _IosChevron(
                                direction: AxisDirection.left,
                                enabled: _page > 0,
                                palette: palette,
                                onTap: () => _goTo(_page - 1),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: _IosChevron(
                                direction: AxisDirection.right,
                                enabled: _page < _modes.length - 1,
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
    required this.savedClassic,
    required this.onContinueClassic,
    required this.onNewClassic,
    required this.onStartDaily,
    required this.onPlayZen,
  });

  final GameMode mode;
  final ColorPalette palette;
  final DailyChallengeState daily;
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
          label: 'START NOW',
          subtitle: daily.completed
              ? 'Done · Score ${daily.score}'
              : daily.countdown,
          leading: const Icon(Icons.bolt_rounded),
          onTap: onStartDaily,
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

/// Soft iOS-style chevron control.
class _IosChevron extends StatelessWidget {
  const _IosChevron({
    required this.direction,
    required this.enabled,
    required this.palette,
    required this.onTap,
  });

  final AxisDirection direction;
  final bool enabled;
  final ColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLeft = direction == AxisDirection.left;
    return Opacity(
      opacity: enabled ? 1 : 0.28,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
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
      ),
    );
  }
}

class _ModeHeroCard extends StatelessWidget {
  const _ModeHeroCard({
    required this.mode,
    required this.palette,
    required this.side,
    required this.daily,
    required this.selected,
    required this.onTap,
  });

  final GameMode mode;
  final ColorPalette palette;
  final double side;
  final DailyChallengeState daily;
  final bool selected;
  final VoidCallback onTap;

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
              : 'Shared puzzle · 1.5×',
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
    final radius = (side * 0.08).clamp(18.0, 28.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: side,
          height: side,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: v.glow.withValues(alpha: selected ? 0.45 : 0.2),
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
            padding: EdgeInsets.all(side * 0.06),
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius * 0.7),
                      gradient: RadialGradient(
                        center: const Alignment(-0.2, -0.35),
                        radius: 1.05,
                        colors: [
                          Color.lerp(v.glow, Colors.white, 0.2)!
                              .withValues(alpha: 0.35),
                          palette.gridBackground.withValues(alpha: 0.55),
                          palette.background.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _ModeScenePainter(
                        mode: mode,
                        palette: palette,
                        accent: v.accent,
                        glow: v.glow,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                SizedBox(height: side * 0.04),
                Text(
                  v.title,
                  style: AppTextStyles.section(palette.textPrimary).copyWith(
                    fontSize: (side * 0.065).clamp(15.0, 20.0),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  v.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mini(palette.textSecondary).copyWith(
                    fontSize: (side * 0.04).clamp(10.0, 12.0),
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

/// Theme-tinted isometric 3D scene per game mode.
class _ModeScenePainter extends CustomPainter {
  _ModeScenePainter({
    required this.mode,
    required this.palette,
    required this.accent,
    required this.glow,
  });

  final GameMode mode;
  final ColorPalette palette;
  final Color accent;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.55;
    final unit = math.min(size.width, size.height) * 0.11;

    // Soft floor ellipse
    final floor = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.28),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(
          center: Offset(cx, cy + unit * 1.6),
          width: unit * 7,
          height: unit * 2.4,
        ),
      );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + unit * 1.6),
        width: unit * 6.2,
        height: unit * 2.1,
      ),
      floor,
    );

    switch (mode) {
      case GameMode.classic:
        _paintClassic(canvas, cx, cy, unit);
      case GameMode.daily:
        _paintDaily(canvas, cx, cy, unit);
      case GameMode.zen:
        _paintZen(canvas, cx, cy, unit);
    }
  }

  void _paintClassic(Canvas canvas, double cx, double cy, double u) {
    final colors = palette.blocks;
    // Trophy-like stack of 3D cubes
    final positions = <(double, double, Color)>[
      (-1.1, 0.6, colors[0]),
      (0.0, 0.6, colors[1]),
      (1.1, 0.6, colors[2]),
      (-0.55, -0.15, colors[3]),
      (0.55, -0.15, colors[4 % colors.length]),
      (0.0, -0.9, accent),
    ];
    for (final (dx, dy, c) in positions) {
      _drawIsoCube(
        canvas,
        Offset(cx + dx * u * 1.35, cy + dy * u * 1.35),
        u * 0.95,
        c,
      );
    }
    // Crown gem
    _drawGem(canvas, Offset(cx, cy - u * 2.05), u * 0.55, glow);
  }

  void _paintDaily(Canvas canvas, double cx, double cy, double u) {
    // Calendar base
    _drawIsoCube(canvas, Offset(cx, cy + u * 0.15), u * 2.1, palette.surface);
    _drawIsoCube(
      canvas,
      Offset(cx, cy - u * 0.55),
      u * 2.1,
      Color.lerp(accent, Colors.white, 0.15)!,
    );
    // Date tiles
    final tileColors = [
      palette.blocks[0],
      palette.blocks[2],
      glow,
      accent,
    ];
    var i = 0;
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 2; col++) {
        _drawIsoCube(
          canvas,
          Offset(
            cx + (col - 0.5) * u * 1.05,
            cy - u * 0.35 + row * u * 0.85,
          ),
          u * 0.72,
          tileColors[i++],
        );
      }
    }
    // Star badge
    _drawGem(canvas, Offset(cx + u * 1.55, cy - u * 1.55), u * 0.42, glow);
  }

  void _paintZen(Canvas canvas, double cx, double cy, double u) {
    // Soft lotus / stacked pebbles
    final greens = [
      Color.lerp(accent, Colors.black, 0.15)!,
      accent,
      Color.lerp(accent, Colors.white, 0.2)!,
      glow,
    ];
    _drawIsoCube(canvas, Offset(cx - u * 0.9, cy + u * 0.5), u * 1.1, greens[0]);
    _drawIsoCube(canvas, Offset(cx + u * 0.9, cy + u * 0.5), u * 1.1, greens[1]);
    _drawIsoCube(canvas, Offset(cx, cy - u * 0.15), u * 1.25, greens[2]);
    _drawIsoCube(canvas, Offset(cx, cy - u * 1.15), u * 0.95, greens[3]);
    // Leaf ring
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = u * 0.12
      ..color = glow.withValues(alpha: 0.7);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + u * 1.35),
        width: u * 4.2,
        height: u * 1.2,
      ),
      ring,
    );
  }

  void _drawIsoCube(Canvas canvas, Offset center, double size, Color base) {
    final w = size * 0.55;
    final h = size * 0.32;
    final d = size * 0.55;

    final top = Path()
      ..moveTo(center.dx, center.dy - h)
      ..lineTo(center.dx + w, center.dy - h * 0.35)
      ..lineTo(center.dx, center.dy + h * 0.3)
      ..lineTo(center.dx - w, center.dy - h * 0.35)
      ..close();

    final left = Path()
      ..moveTo(center.dx - w, center.dy - h * 0.35)
      ..lineTo(center.dx, center.dy + h * 0.3)
      ..lineTo(center.dx, center.dy + h * 0.3 + d)
      ..lineTo(center.dx - w, center.dy - h * 0.35 + d)
      ..close();

    final right = Path()
      ..moveTo(center.dx + w, center.dy - h * 0.35)
      ..lineTo(center.dx, center.dy + h * 0.3)
      ..lineTo(center.dx, center.dy + h * 0.3 + d)
      ..lineTo(center.dx + w, center.dy - h * 0.35 + d)
      ..close();

    final topC = Color.lerp(base, Colors.white, 0.28)!;
    final leftC = Color.lerp(base, Colors.black, 0.22)!;
    final rightC = Color.lerp(base, Colors.black, 0.08)!;

    canvas.drawPath(left, Paint()..color = leftC);
    canvas.drawPath(right, Paint()..color = rightC);
    canvas.drawPath(top, Paint()..color = topC);

    // Specular edge
    canvas.drawPath(
      top,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _drawGem(Canvas canvas, Offset c, double r, Color color) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r * 0.7, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r * 0.7, c.dy)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(color, Colors.white, 0.45)!,
            color,
            Color.lerp(color, Colors.black, 0.2)!,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant _ModeScenePainter oldDelegate) =>
      oldDelegate.mode != mode ||
      oldDelegate.palette != palette ||
      oldDelegate.accent != accent ||
      oldDelegate.glow != glow;
}
