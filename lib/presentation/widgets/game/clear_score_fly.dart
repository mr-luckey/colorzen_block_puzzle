import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/perf_tier.dart';

/// Single 2.8s reward: title above a one-shot 0→N count, then fly to SCORE.
class ClearScoreFly extends StatefulWidget {
  const ClearScoreFly({
    super.key,
    required this.amount,
    required this.palette,
    required this.targetKey,
    required this.onArrived,
    this.lines = 0,
    this.allClear = false,
  });

  final int amount;
  final int lines;
  final bool allClear;
  final ColorPalette palette;
  final GlobalKey targetKey;
  final VoidCallback onArrived;

  static const duration = Duration(milliseconds: 2800);

  @override
  State<ClearScoreFly> createState() => _ClearScoreFlyState();
}

class _ClearScoreFlyState extends State<ClearScoreFly>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<int> _count;
  final _pointsKey = GlobalKey();
  Offset? _flyFrom;
  Offset? _flyTo;
  bool _notified = false;
  int _shown = 0;

  static const _titleInEnd = 0.14;
  static const _countStart = 0.10;
  static const _countEnd = 0.62;
  static const _titleOutStart = 0.64;
  static const _titleOutEnd = 0.74;
  static const _flyStart = 0.74;

  bool get _hasTitle {
    if (widget.allClear) return true;
    return RankingEngine.bigClearTitle(
      widget.lines,
      allClear: false,
    ).isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: ClearScoreFly.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _arrive();
      });
    _count = IntTween(begin: 0, end: math.max(0, widget.amount)).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(
          _countStart,
          _countEnd,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _arrive() {
    if (_notified) return;
    _notified = true;
    widget.onArrived();
  }

  void _captureFly() {
    final overlay = context.findRenderObject() as RenderBox?;
    final fromBox = _pointsKey.currentContext?.findRenderObject() as RenderBox?;
    final toBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (overlay == null ||
        fromBox == null ||
        toBox == null ||
        !overlay.hasSize ||
        !fromBox.hasSize ||
        !toBox.hasSize) {
      return;
    }
    _flyFrom = overlay.globalToLocal(
      fromBox.localToGlobal(fromBox.size.center(Offset.zero)),
    );
    _flyTo = overlay.globalToLocal(
      toBox.localToGlobal(toBox.size.center(Offset.zero)),
    );
  }

  Offset _quad(Offset a, Offset b, Offset c, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * b.dx + t * t * c.dx,
      u * u * a.dy + 2 * u * t * b.dy + t * t * c.dy,
    );
  }

  double _span(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final gold = widget.palette.comboGold;
    final accent = widget.allClear
        ? const Color(0xFFFFEA00)
        : widget.palette.accentSecondary;
    final title = RankingEngine.bigClearTitle(
      widget.lines,
      allClear: widget.allClear,
    );
    final subtitle = RankingEngine.lineCountLabel(
      widget.allClear ? math.max(widget.lines, 1) : widget.lines,
    );
    final titleText = title.isEmpty ? 'LEGENDARY!' : title;

    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            final next = _count.value;
            if (next > _shown) _shown = next;
            final flyT = Curves.easeInCubic.transform(
              _span(t, _flyStart, 1.0),
            );
            final flying = flyT > 0;
            if (_flyFrom == null && t >= _flyStart - 0.04) {
              _captureFly();
            }
            final titleIn = Curves.easeOutCubic.transform(
              _span(t, 0.0, _titleInEnd),
            );
            final titleOut = Curves.easeIn.transform(
              _span(t, _titleOutStart, _titleOutEnd),
            );
            final titleOpacity = _hasTitle
                ? (titleIn * (1.0 - titleOut)).clamp(0.0, 1.0)
                : 0.0;
            final scoreIn = Curves.easeOut.transform(
              _span(t, _countStart, _countStart + 0.08),
            );
            final fill = _span(t, _countStart, _countEnd);
            final pulse = 1.0 + 0.10 * math.sin(fill * math.pi);
            final tickPop = 1.0 + 0.08 * math.sin(_shown * 0.9).abs();
            final countScale = flying ? 1.0 : pulse * tickPop;
            final fillColor = Color.lerp(
              Colors.white,
              gold,
              Curves.easeOut.transform(fill),
            )!;
            final label = '+${NumberFormat('#,###').format(_shown)}';
            final size = MediaQuery.sizeOf(context);
            final ringT = Curves.easeOutCubic.transform(_span(t, 0.0, 0.5));
            final ringFade = (1.0 - _span(t, 0.42, 0.70)).clamp(0.0, 1.0);

            Widget scoreText({required Key? key, required double sizePx}) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (!flying)
                    CustomPaint(
                      size: const Size(240, 88),
                      painter: _ScoreGlowPainter(
                        fill: fill,
                        gold: gold,
                        opacity: scoreIn,
                      ),
                    ),
                  Transform.scale(
                    scale: countScale,
                    child: Text(
                      label,
                      key: key,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.score(fillColor).copyWith(
                        fontSize: sizePx,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        shadows: [
                          Shadow(
                            color: gold.withValues(alpha: 0.95),
                            blurRadius: 8 + 18 * fill,
                          ),
                          Shadow(
                            color: const Color(0xFFFF6D00)
                                .withValues(alpha: 0.45 * fill),
                            blurRadius: 28,
                          ),
                          const Shadow(
                            color: Colors.black54,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            final start = _flyFrom ?? Offset(size.width / 2, size.height * 0.58);
            final end = _flyTo ?? Offset(size.width * 0.52, 96);
            final lift = Offset(
              (start.dx + end.dx) / 2,
              math.min(start.dy, end.dy) - 40,
            );
            final flyPos = _quad(start, lift, end, flyT);
            final flyScale = (1.0 - 0.52 * flyT).clamp(0.38, 1.0);
            final flyOpacity = flyT > 0.88
                ? (1.0 - (flyT - 0.88) / 0.12).clamp(0.0, 1.0)
                : 1.0;

            return Stack(
              children: [
                if (_hasTitle && ringFade > 0.02)
                  CustomPaint(
                    size: size,
                    painter: _RewardRingsPainter(
                      t: ringT,
                      fade: ringFade * titleOpacity.clamp(0.35, 1.0),
                      allClear: widget.allClear,
                      gold: gold,
                      accent: accent,
                      sparks: PerfTier.instance.isLowEnd ? 8 : 14,
                      originY: size.height * 0.50,
                    ),
                  ),
                // Title + count stacked so they never share one line.
                Align(
                  alignment: const Alignment(0, 0.22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasTitle)
                        Opacity(
                          opacity: titleOpacity,
                          child: Transform.scale(
                            scale: 0.86 + 0.14 * titleIn,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (subtitle.isNotEmpty)
                                  Text(
                                    subtitle,
                                    style: AppTextStyles.section(accent)
                                        .copyWith(
                                      fontSize: 15,
                                      letterSpacing: 2.2,
                                      shadows: [
                                        Shadow(
                                          color: accent.withValues(alpha: 0.8),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                Text(
                                  titleText,
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.praise(gold).copyWith(
                                    fontSize: widget.allClear ? 38 : 32,
                                    height: 1.05,
                                    shadows: [
                                      Shadow(
                                        color: gold.withValues(alpha: 0.85),
                                        blurRadius: 26,
                                      ),
                                      const Shadow(
                                        color: Colors.black54,
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_hasTitle) const SizedBox(height: 28),
                      Opacity(
                        opacity: flying ? 0 : scoreIn,
                        child: scoreText(
                          key: flying ? null : _pointsKey,
                          sizePx: _hasTitle ? 40 : 48,
                        ),
                      ),
                    ],
                  ),
                ),
                if (flying)
                  Positioned(
                    left: flyPos.dx - 120,
                    top: flyPos.dy - 28,
                    width: 240,
                    child: Opacity(
                      opacity: flyOpacity,
                      child: Transform.scale(
                        scale: flyScale,
                        child: scoreText(key: null, sizePx: 36),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RewardRingsPainter extends CustomPainter {
  _RewardRingsPainter({
    required this.t,
    required this.fade,
    required this.allClear,
    required this.gold,
    required this.accent,
    required this.sparks,
    required this.originY,
  });

  final double t;
  final double fade;
  final bool allClear;
  final Color gold;
  final Color accent;
  final int sparks;
  final double originY;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, originY);
    final rings = allClear ? 3 : 2;
    for (var i = 0; i < rings; i++) {
      final r = 24.0 + t * (90.0 + i * 55);
      canvas.drawCircle(
        origin,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = allClear ? 4.5 : 3.2
          ..color = (i.isEven ? gold : accent).withValues(alpha: 0.5 * fade),
      );
    }
    for (var i = 0; i < sparks; i++) {
      final angle = (i / sparks) * math.pi * 2;
      final dist = (allClear ? 58.0 : 42.0) + (i % 5) * 14;
      canvas.drawCircle(
        Offset(
          origin.dx + math.cos(angle) * dist * t,
          origin.dy + math.sin(angle) * dist * t,
        ),
        2.4,
        Paint()
          ..color = (i.isEven ? Colors.white : gold).withValues(alpha: fade),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RewardRingsPainter old) =>
      old.t != t || old.fade != fade || old.originY != originY;
}

class _ScoreGlowPainter extends CustomPainter {
  _ScoreGlowPainter({
    required this.fill,
    required this.gold,
    required this.opacity,
  });

  final double fill;
  final Color gold;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.04) return;
    final c = Offset(size.width / 2, size.height / 2);
    final r = 22.0 + 38.0 * fill;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.55 * opacity),
            gold.withValues(alpha: 0.40 * opacity),
            const Color(0xFFFF6D00).withValues(alpha: 0.18 * opacity),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreGlowPainter old) =>
      old.fill != fill || old.opacity != opacity;
}
