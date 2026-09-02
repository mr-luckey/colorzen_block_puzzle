import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/perf_tier.dart';

/// Big 4 / 6 / 9 / ALL CLEAR celebration — one CustomPaint, vsync ticker.
/// Does not touch drag / board smoothness.
class ClearCelebration extends StatefulWidget {
  const ClearCelebration({
    super.key,
    required this.lines,
    required this.allClear,
    required this.bonus,
    required this.palette,
  });

  final int lines;
  final bool allClear;
  final int bonus;
  final ColorPalette palette;

  @override
  State<ClearCelebration> createState() => _ClearCelebrationState();
}

class _ClearCelebrationState extends State<ClearCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.allClear ? 1500 : 1280),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.bonus >= 0);
    final title = RankingEngine.bigClearTitle(
      widget.lines,
      allClear: widget.allClear,
    );
    final count = RankingEngine.lineCountLabel(
      widget.allClear ? math.max(widget.lines, 1) : widget.lines,
    );
    final gold = widget.palette.comboGold;
    final accent = widget.allClear
        ? const Color(0xFFFFEA00)
        : widget.palette.accentSecondary;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                painter: _CelePainter(
                  t: t,
                  rawT: _ctrl.value,
                  allClear: widget.allClear,
                  gold: gold,
                  accent: accent,
              sparks: PerfTier.instance.isLowEnd ? 10 : 16,
            ),
                child: const SizedBox.expand(),
              ),
              child!,
            ],
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count.isNotEmpty)
              Text(
                count,
                style: AppTextStyles.section(accent).copyWith(
                  fontSize: 18,
                  letterSpacing: 2.4,
                  shadows: [
                    Shadow(color: accent.withValues(alpha: 0.8), blurRadius: 16),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 80.ms)
                  .slideY(begin: 0.4, end: 0, duration: 220.ms, curve: Curves.easeOut),
            Text(
              title.isEmpty ? 'LEGENDARY!' : title,
              textAlign: TextAlign.center,
              style: AppTextStyles.praise(gold).copyWith(
                fontSize: widget.allClear ? 42 : 36,
                shadows: [
                  Shadow(color: gold.withValues(alpha: 0.85), blurRadius: 28),
                  const Shadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 3)),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 90.ms)
                .scale(
                  begin: const Offset(0.4, 0.4),
                  end: const Offset(1.12, 1.12),
                  duration: 280.ms,
                  curve: Curves.easeOutBack,
                )
                .then()
                .scale(
                  begin: const Offset(1.12, 1.12),
                  end: const Offset(1, 1),
                  duration: 120.ms,
                ),
          ],
        ),
      ),
    );
  }
}

class _CelePainter extends CustomPainter {
  _CelePainter({
    required this.t,
    required this.rawT,
    required this.allClear,
    required this.gold,
    required this.accent,
    required this.sparks,
  });

  final double t;
  final double rawT;
  final bool allClear;
  final Color gold;
  final Color accent;
  final int sparks;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height / 2);
    final fade = (1.0 - Curves.easeIn.transform((rawT - 0.35).clamp(0.0, 1.0)))
        .clamp(0.0, 1.0);
    final rings = allClear ? 3 : 2;
    for (var i = 0; i < rings; i++) {
      final r = 28.0 + t * (110.0 + i * 70);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = allClear ? 5 : 3.5
        ..color = (i.isEven ? gold : accent).withValues(alpha: 0.55 * fade);
      canvas.drawCircle(origin, r, paint);
    }

    final bloomR = 40 + t * (allClear ? 160 : 90);
    canvas.drawCircle(
      origin,
      bloomR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55 * fade),
            gold.withValues(alpha: 0.28 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: origin, radius: bloomR)),
    );

    for (var i = 0; i < sparks; i++) {
      final angle = (i / sparks) * math.pi * 2;
      final dist = (allClear ? 70.0 : 48.0) + (i % 5) * 18;
      final px = origin.dx + math.cos(angle) * dist * t;
      final py = origin.dy + math.sin(angle) * dist * t;
      final side = 5.0 + (i % 3) * 2.5;
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(t * (i.isEven ? 1.2 : -1.2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          const Radius.circular(2),
        ),
        Paint()
          ..color = (i.isEven ? Colors.white : gold).withValues(alpha: fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelePainter old) => old.t != t || old.rawT != rawT;
}
