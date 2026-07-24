import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/particle_background.dart';

/// Bright, jewel-tone themes — deep enough for yellow face emojis.
class AppPalettes {
  /// Woodland — vivid greens + jewel blocks.
  static const woodland = ColorPalette(
    background: Color(0xFF14241A),
    gridBackground: Color(0xFF1E3A2A),
    gridLine: Color(0xFF2E5A40),
    cellEmpty: Color(0xFF183028),
    surface: Color(0xFF2A4A38),
    accentPrimary: Color(0xFF69F0AE),
    accentSecondary: Color(0xFFFFF176),
    textPrimary: Color(0xFFF5FFF8),
    textSecondary: Color(0xFFB8E0C8),
    blocks: [
      Color(0xFFC62828), // ruby red
      Color(0xFF2E7D32), // emerald
      Color(0xFF1565C0), // sapphire
      Color(0xFF6A1B9A), // amethyst
      Color(0xFF00838F), // teal
      Color(0xFFAD1457), // magenta
    ],
    comboGold: Color(0xFFFFF59D),
    invalidRed: Color(0xFFFF5252),
  );

  /// Ocean Breeze.
  static const oceanBreeze = ColorPalette(
    background: Color(0xFF06263A),
    gridBackground: Color(0xFF0C3D5C),
    gridLine: Color(0xFF15658F),
    cellEmpty: Color(0xFF0A3048),
    surface: Color(0xFF145078),
    accentPrimary: Color(0xFF40C4FF),
    accentSecondary: Color(0xFFFFF59D),
    textPrimary: Color(0xFFF0FBFF),
    textSecondary: Color(0xFFA8D8F0),
    blocks: [
      Color(0xFFD32F2F),
      Color(0xFF00695C),
      Color(0xFF1976D2),
      Color(0xFF7B1FA2),
      Color(0xFF303F9F),
      Color(0xFFC2185B),
    ],
    comboGold: Color(0xFFFFF59D),
  );

  /// Sunset Glow — magenta / violet (no muddy browns).
  static const sunsetGlow = ColorPalette(
    background: Color(0xFF2A1030),
    gridBackground: Color(0xFF3D1848),
    gridLine: Color(0xFF5C2868),
    cellEmpty: Color(0xFF321440),
    surface: Color(0xFF4A2058),
    accentPrimary: Color(0xFFFF80AB),
    accentSecondary: Color(0xFFFFE082),
    textPrimary: Color(0xFFFFF5FA),
    textSecondary: Color(0xFFF0C0D8),
    blocks: [
      Color(0xFFB71C1C),
      Color(0xFF33691E),
      Color(0xFF283593),
      Color(0xFF6A1B9A),
      Color(0xFF00695C),
      Color(0xFF880E4F),
    ],
    comboGold: Color(0xFFFFE082),
  );

  /// Enchanted Night — default (cyan / magenta neon on moonlit forest).
  static const enchantedNight = ColorPalette(
    background: Color(0xFF0A1230),
    gridBackground: Color(0xCC0A0E28),
    gridLine: Color(0xFF1A2A55),
    cellEmpty: Color(0x99081228),
    surface: Color(0xE6121A3A),
    accentPrimary: Color(0xFF00D2FF),
    accentSecondary: Color(0xFFFFD700),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8C8E8),
    blocks: [
      Color(0xFFE91E63), // pink / hearts
      Color(0xFF00BCD4), // cyan laugh
      Color(0xFF7C4DFF), // violet
      Color(0xFFFF80AB), // soft pink
      Color(0xFF40C4FF), // sky cyan
      Color(0xFF69F0AE), // mint
    ],
    comboGold: Color(0xFFFFD700),
    invalidRed: Color(0xFFFF5252),
  );

  static ColorPalette of(AppThemeId id) => switch (id) {
        AppThemeId.enchantedNight => enchantedNight,
        AppThemeId.midnightZen => woodland,
        AppThemeId.desiRangoli => oceanBreeze,
        AppThemeId.arcticIce => sunsetGlow,
      };

  static String nameOf(AppThemeId id) => switch (id) {
        AppThemeId.enchantedNight => 'Enchanted Night',
        AppThemeId.midnightZen => 'Woodland',
        AppThemeId.desiRangoli => 'Ocean Breeze',
        AppThemeId.arcticIce => 'Sunset Glow',
      };

  static String backgroundAsset(AppThemeId id) => switch (id) {
        AppThemeId.enchantedNight => 'assets/images/bg_enchanted_night.png',
        AppThemeId.midnightZen => 'assets/images/bg_woodland.png',
        AppThemeId.desiRangoli => 'assets/images/bg_ocean.png',
        AppThemeId.arcticIce => 'assets/images/bg_sunset.png',
      };

  static int unlockScore(AppThemeId id) => switch (id) {
        AppThemeId.enchantedNight => 0,
        AppThemeId.midnightZen => AppConstants.woodlandUnlockScore,
        AppThemeId.desiRangoli => AppConstants.desiUnlockScore,
        AppThemeId.arcticIce => AppConstants.arcticUnlockScore,
      };

  static bool usesNeonFrame(AppThemeId id) =>
      id == AppThemeId.enchantedNight;
}

class AppTextStyles {
  static TextStyle logo(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 38,
        letterSpacing: 1.2,
        color: color,
      );

  static TextStyle tagline(Color color) => GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle score(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 28,
        color: color,
      );

  static TextStyle gameOver(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 26,
        color: color,
        decoration: TextDecoration.none,
      );

  static TextStyle button(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 17,
        letterSpacing: 0.5,
        color: color,
        decoration: TextDecoration.none,
      );

  static TextStyle section(Color color) => GoogleFonts.nunito(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        letterSpacing: 0.4,
        color: color,
      );

  static TextStyle body(Color color) => GoogleFonts.nunito(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: color,
      );

  static TextStyle countdown(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: color,
      );

  static TextStyle mini(Color color) => GoogleFonts.nunito(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        letterSpacing: 0.5,
        color: color,
      );

  static TextStyle appBar(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: color,
      );

  static TextStyle praise(Color color) => GoogleFonts.fredoka(
        fontWeight: FontWeight.w700,
        fontSize: 36,
        letterSpacing: 1.2,
        color: color,
      );
}

/// Soft atmospheric BG with optional 3D parallax (no setState).
class WoodBackground extends StatefulWidget {
  const WoodBackground({
    super.key,
    required this.palette,
    this.themeId,
    this.child,
    /// Extra dark wash so text stays readable (settings / lists).
    this.dimmed = false,
    /// Home/menus: soft parallax. Gameplay: static (ANR/jank safe).
    this.animated = true,
  });

  final ColorPalette palette;
  final AppThemeId? themeId;
  final Widget? child;
  final bool dimmed;
  final bool animated;

  @override
  State<WoodBackground> createState() => _WoodBackgroundState();
}

class _WoodBackgroundState extends State<WoodBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  final ValueNotifier<Offset> _tilt = ValueNotifier(Offset.zero);

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    if (widget.animated) _drift.repeat();
  }

  @override
  void didUpdateWidget(covariant WoodBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!widget.animated && _drift.isAnimating) {
      _drift.stop();
      _tilt.value = Offset.zero;
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _tilt.dispose();
    super.dispose();
  }

  void _onPointer(Offset local, Size size) {
    if (!widget.animated) return;
    if (size.width <= 0 || size.height <= 0) return;
    final nx = ((local.dx / size.width) - 0.5).clamp(-0.5, 0.5) * 2;
    final ny = ((local.dy / size.height) - 0.5).clamp(-0.5, 0.5) * 2;
    _tilt.value = Offset(nx, ny);
  }

  Widget _layers({
    required String asset,
    required ColorPalette palette,
    double rotX = 0,
    double rotY = 0,
    Offset slide = Offset.zero,
    double px = 0,
    double py = 0,
  }) {
    final bg = Image.asset(
      asset,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => ColoredBox(color: palette.background),
    );

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        if (widget.animated)
          Transform.translate(
            offset: slide * 1.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.2 + px * 0.3, -0.35 + py * 0.25),
                  radius: 1.15,
                  colors: [
                    Color.lerp(palette.accentPrimary, Colors.white, 0.25)!
                        .withValues(alpha: 0.45),
                    palette.background.withValues(alpha: 0.2),
                    palette.background,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          )
        else
          ColoredBox(color: palette.background),
        if (widget.animated)
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.00115)
              ..rotateX(rotX)
              ..rotateY(-rotY)
              ..scaleByDouble(1.12, 1.12, 1.12, 1),
            child: Transform.translate(offset: slide, child: bg),
          )
        else
          bg,
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: widget.dimmed ? 0.32 : 0.08),
                palette.background.withValues(
                  alpha: widget.dimmed ? 0.48 : 0.18,
                ),
                Colors.black.withValues(alpha: widget.dimmed ? 0.58 : 0.28),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
          ),
        ),
        if (widget.dimmed)
          ColoredBox(color: Colors.black.withValues(alpha: 0.22)),
        if (widget.animated)
          IgnorePointer(child: ParticleBackground(palette: palette)),
        ?widget.child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.themeId ?? context.watch<ThemeCubit>().state.selected;
    final asset = AppPalettes.backgroundAsset(id);
    final palette = widget.palette;

    if (!widget.animated) {
      return _layers(asset: asset, palette: palette);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) => _onPointer(e.localPosition, size),
          onPointerMove: (e) => _onPointer(e.localPosition, size),
          child: AnimatedBuilder(
            animation: Listenable.merge([_drift, _tilt]),
            builder: (context, _) {
              final t = _drift.value * math.pi * 2;
              final autoX = math.sin(t) * 0.05;
              final autoY = math.cos(t * 0.9) * 0.035;
              final px = _tilt.value.dx;
              final py = _tilt.value.dy;
              return _layers(
                asset: asset,
                palette: palette,
                rotX: autoY + py * 0.08,
                rotY: autoX + px * 0.1,
                slide: Offset(
                  (autoX + px * 0.25) * 18,
                  (autoY + py * 0.25) * 14,
                ),
                px: px,
                py: py,
              );
            },
          ),
        );
      },
    );
  }
}

/// Recessed glass panel — Enchanted Night uses cyan→magenta neon frame.
class WoodPanel extends StatelessWidget {
  const WoodPanel({
    super.key,
    required this.palette,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.borderColor,
    this.neon = false,
  });

  final ColorPalette palette;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final bool neon;

  @override
  Widget build(BuildContext context) {
    final useNeon =
        neon || palette.accentPrimary == AppPalettes.enchantedNight.accentPrimary;

    final inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(useNeon ? radius - 1.2 : radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(palette.surface, Colors.white, 0.12)!,
            palette.surface,
            Color.lerp(palette.surface, palette.accentPrimary, 0.18)!,
          ],
        ),
        border: useNeon
            ? null
            : Border.all(
                color:
                    borderColor ?? palette.accentPrimary.withValues(alpha: 0.55),
                width: 1.6,
              ),
        boxShadow: useNeon
            ? null
            : [
                BoxShadow(
                  color: palette.accentPrimary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );

    if (!useNeon) return inner;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF00D2FF),
            Color(0xFF7C4DFF),
            Color(0xFFFF00AA),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFFF00AA).withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.7),
      child: inner,
    );
  }
}
