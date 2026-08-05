import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Confetti burst — few particles, one-shot, light on GPU.
class ClearBurst extends StatelessWidget {
  const ClearBurst({
    super.key,
    required this.colors,
    this.seed = 1,
    this.intense = false,
  });

  final List<Color> colors;
  final int seed;
  final bool intense;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed);
    final particleCount = intense ? 18 : 14;
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft gold bloom flash (Block Blast style).
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  const Color(0xFFFFE082).withValues(alpha: 0.7),
                  const Color(0xFFFF9800).withValues(alpha: 0.25),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.4, 0.4),
                end: const Offset(4.2, 4.2),
                duration: 420.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(delay: 40.ms, duration: 320.ms),
          ...List.generate(particleCount, (i) {
            final angle =
                (i / particleCount) * math.pi * 2 + rng.nextDouble() * 0.25;
            final dist = 52.0 + rng.nextDouble() * 90;
            final size = 4.0 + rng.nextDouble() * 7;
            final color = colors[i % colors.length];
            final isSpark = i.isEven;
            return Align(
              child: (isSpark
                      ? CustomPaint(
                          size: Size(size * 1.6, size * 1.6),
                          painter: _SparkPainter(
                            color: Color.lerp(color, Colors.white, 0.45)!,
                          ),
                        )
                      : Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.55),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ))
                  .animate()
                  .move(
                    begin: Offset.zero,
                    end: Offset(
                      math.cos(angle) * dist,
                      math.sin(angle) * dist - 14,
                    ),
                    duration: 420.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeOut(delay: 80.ms, duration: 260.ms)
                  .rotate(
                    begin: 0,
                    end: (rng.nextDouble() - 0.5) * 1.2,
                    duration: 420.ms,
                  ),
            );
          }),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final b = a + math.pi / 4;
      path.moveTo(cx, cy);
      path.lineTo(cx + math.cos(a) * r, cy + math.sin(a) * r);
      path.lineTo(cx + math.cos(b) * r * 0.28, cy + math.sin(b) * r * 0.28);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.color != color;
}

/// Block-Blast-style clear FX — white flash → gold bloom → shatter sparks.
/// Timing matched from Hungry Studio Block Blast gameplay footage.
class ClearFxOverlay extends StatefulWidget {
  const ClearFxOverlay({
    super.key,
    required this.clearedRows,
    required this.clearedCols,
    required this.blastCells,
    required this.clearFxColors,
    required this.cell,
    required this.gap,
    required this.boardW,
    required this.palette,
  });

  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<(int, int)> blastCells;
  final Map<(int, int), BlockColor> clearFxColors;
  final double cell;
  final double gap;
  final double boardW;
  final ColorPalette palette;

  @override
  State<ClearFxOverlay> createState() => _ClearFxOverlayState();
}

class _ClearFxOverlayState extends State<ClearFxOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// ~520ms line clear — matches Block Blast flash→glow→shatter cadence.
  static const _lineMs = 520;
  static const _blastMs = 560;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _lineMs),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant ClearFxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.clearedRows != widget.clearedRows ||
        oldWidget.clearedCols != widget.clearedCols ||
        oldWidget.blastCells != widget.blastCells ||
        oldWidget.clearFxColors != widget.clearFxColors;
    if (changed) {
      _ctrl
        ..duration = Duration(
          milliseconds:
              widget.blastCells.isNotEmpty ? _blastMs : _lineMs,
        )
        ..forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.clearFxColors.isEmpty &&
        widget.clearedRows.isEmpty &&
        widget.clearedCols.isEmpty &&
        widget.blastCells.isEmpty) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          // Smooth overall ease — Block Blast never feels linear.
          final t = Curves.easeOutCubic.transform(_ctrl.value);
          return CustomPaint(
            size: Size(widget.boardW, widget.boardW),
            painter: _ClearFxPainter(
              t: t,
              rawT: _ctrl.value,
              clearedRows: widget.clearedRows,
              clearedCols: widget.clearedCols,
              blastCells: widget.blastCells,
              clearFxColors: widget.clearFxColors,
              cell: widget.cell,
              gap: widget.gap,
              palette: widget.palette,
            ),
          );
        },
      ),
    );
  }
}

class _ClearFxPainter extends CustomPainter {
  _ClearFxPainter({
    required this.t,
    required this.rawT,
    required this.clearedRows,
    required this.clearedCols,
    required this.blastCells,
    required this.clearFxColors,
    required this.cell,
    required this.gap,
    required this.palette,
  });

  final double t;
  final double rawT;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<(int, int)> blastCells;
  final Map<(int, int), BlockColor> clearFxColors;
  final double cell;
  final double gap;
  final ColorPalette palette;

  static const _gold = Color(0xFFFFE082);
  static const _hotOrange = Color(0xFFFF9800);
  static const _rimOrange = Color(0xFFFF6D00);

  @override
  void paint(Canvas canvas, Size size) {
    final stride = cell + gap;
    final radius = Radius.circular(cell * 0.22);
    final blastSet = blastCells.toSet();
    final glowAlive = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);

    // ── Board rim bloom (seen on Block Blast during clears) ──
    if (glowAlive > 0.02) {
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.18
        ..color = _gold.withValues(alpha: 0.35 * glowAlive)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.45);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(cell * 0.3),
        ),
        rim,
      );
    }

    // ── Energy beam sweep along cleared rows ──
    for (final r in clearedRows) {
      _paintLineBeam(
        canvas,
        size,
        horizontal: true,
        index: r,
        stride: stride,
        radius: radius,
      );
    }
    for (final c in clearedCols) {
      _paintLineBeam(
        canvas,
        size,
        horizontal: false,
        index: c,
        stride: stride,
        radius: radius,
      );
    }

    // ── Per-block flash → rim → shatter (core Block Blast sequence) ──
    clearFxColors.forEach((pos, blockColor) {
      final r = pos.$1;
      final c = pos.$2;
      final isBlast = blastSet.contains(pos);

      // Stagger along the line — wave feel like Block Blast.
      final stagger = isBlast
          ? ((r + c) % 5) / 5.0 * 0.14
          : (clearedRows.contains(r) ? c / 8.0 : r / 8.0) * 0.22;
      final local = ((rawT - stagger) / (1.0 - stagger).clamp(0.35, 1.0))
          .clamp(0.0, 1.0);
      if (local <= 0) return;

      final cx = c * stride + cell / 2;
      final cy = r * stride + cell / 2;
      final base = palette.blockColor(blockColor);

      // Phase windows (from footage): flash 0–.28 → rim glow .18–.55 → shatter .42–1
      final flash = _smoothstep(0.0, 0.28, local);
      final rim = _smoothstep(0.16, 0.48, local) *
          (1.0 - _smoothstep(0.52, 0.78, local));
      final shatter = _smoothstep(0.42, 0.72, local);
      final fade = 1.0 - _smoothstep(0.55, 1.0, local);

      // Soft gold bloom behind the cell (bleeding light between tiles).
      if (flash > 0.05 && fade > 0.05) {
        final bloomR = cell * (0.75 + 0.55 * flash);
        canvas.drawCircle(
          Offset(cx, cy),
          bloomR,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.75 * flash * fade),
                _gold.withValues(alpha: 0.55 * flash * fade),
                _hotOrange.withValues(alpha: 0.18 * flash * fade),
                Colors.transparent,
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: bloomR),
            ),
        );
      }

      // Solid block: color → white, slight punch scale, neon rim.
      if (fade > 0.04 && shatter < 0.95) {
        final punch = 1.0 + 0.14 * math.sin(flash * math.pi) * (1 - shatter);
        final side = cell * punch * (1.0 - shatter * 0.35);
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: side,
            height: side,
          ),
          Radius.circular(side * 0.22),
        );

        final fill = Color.lerp(
          base,
          Colors.white,
          (0.35 + 0.65 * flash).clamp(0.0, 1.0),
        )!;
        final blastTint = isBlast
            ? Color.lerp(fill, const Color(0xFFFF6D00), local * 0.35)!
            : fill;

        canvas.drawRRect(
          rect,
          Paint()..color = blastTint.withValues(alpha: fade),
        );

        // Neon-orange luminous rim (Block Blast white core + orange outline).
        if (rim > 0.02) {
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.12 * rim
              ..color = _rimOrange.withValues(alpha: 0.95 * rim * fade)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.08),
          );
          canvas.drawRRect(
            rect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = cell * 0.05
              ..color = Colors.white.withValues(alpha: 0.9 * rim * fade),
          );
        }
      }

      // Shatter shards + sparkles flying out.
      if (shatter > 0.02) {
        _paintShatter(
          canvas,
          cx: cx,
          cy: cy,
          color: base,
          progress: shatter,
          fade: fade,
          seed: r * 31 + c * 17,
          isBlast: isBlast,
        );
      }
    });
  }

  void _paintLineBeam(
    Canvas canvas,
    Size size, {
    required bool horizontal,
    required int index,
    required double stride,
    required Radius radius,
  }) {
    // Travelling hot core along the line (ease across).
    final sweep = Curves.easeInOut.transform(rawT.clamp(0.0, 1.0));
    final glow = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    if (glow < 0.02) return;

    final Rect lineRect;
    final Alignment begin;
    final Alignment end;
    if (horizontal) {
      lineRect = Rect.fromLTWH(0, index * stride, size.width, cell);
      begin = Alignment(-1.4 + sweep * 2.8, 0);
      end = Alignment(-0.6 + sweep * 2.8, 0);
    } else {
      lineRect = Rect.fromLTWH(index * stride, 0, cell, size.height);
      begin = Alignment(0, -1.4 + sweep * 2.8);
      end = Alignment(0, -0.6 + sweep * 2.8);
    }

    final rrect = RRect.fromRectAndRadius(lineRect, radius);

    // Soft gold wash across whole line.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [
            _gold.withValues(alpha: 0),
            _gold.withValues(alpha: 0.35 * glow),
            Colors.white.withValues(alpha: 0.55 * glow),
            _gold.withValues(alpha: 0.35 * glow),
            _gold.withValues(alpha: 0),
          ],
        ).createShader(lineRect),
    );

    // Hot travelling highlight.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.85 * glow),
            _hotOrange.withValues(alpha: 0.55 * glow),
            Colors.transparent,
          ],
        ).createShader(lineRect)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.15),
    );
  }

  void _paintShatter(
    Canvas canvas, {
    required double cx,
    required double cy,
    required Color color,
    required double progress,
    required double fade,
    required int seed,
    required bool isBlast,
  }) {
    final rng = math.Random(seed);
    final shardCount = isBlast ? 7 : 5;
    final ease = Curves.easeOutCubic.transform(progress);
    final alpha = (1.0 - progress) * fade;

    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * math.pi * 2 + rng.nextDouble() * 0.4;
      final dist = cell * (0.35 + rng.nextDouble() * 1.15) * ease;
      final px = cx + math.cos(angle) * dist;
      final py = cy + math.sin(angle) * dist - ease * cell * 0.15;
      final side = cell * (0.18 + rng.nextDouble() * 0.16) * (1.0 - ease * 0.45);
      final rot = (rng.nextDouble() - 0.5) * ease * 2.2;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rot);
      final shardColor = Color.lerp(
        color,
        Colors.white,
        0.35 + rng.nextDouble() * 0.4,
      )!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          Radius.circular(side * 0.2),
        ),
        Paint()..color = shardColor.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    // Tiny sparkles (4-point) — Block Blast floating stars.
    final sparkN = isBlast ? 5 : 4;
    for (var i = 0; i < sparkN; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = cell * (0.5 + rng.nextDouble() * 1.4) * ease;
      final px = cx + math.cos(angle) * dist;
      final py = cy + math.sin(angle) * dist - ease * cell * 0.35;
      final s = cell * (0.08 + rng.nextDouble() * 0.1) * (1 - progress * 0.3);
      final sparkColor = i.isEven ? Colors.white : _gold;
      _drawSpark(
        canvas,
        Offset(px, py),
        s,
        sparkColor.withValues(alpha: alpha * 0.95),
      );
    }
  }

  void _drawSpark(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 4;
      final b = a + math.pi / 4;
      path.moveTo(c.dx, c.dy);
      path.lineTo(c.dx + math.cos(a) * r, c.dy + math.sin(a) * r);
      path.lineTo(
        c.dx + math.cos(b) * r * 0.28,
        c.dy + math.sin(b) * r * 0.28,
      );
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );
    canvas.drawPath(path, Paint()..color = color);
  }

  static double _smoothstep(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(covariant _ClearFxPainter old) =>
      old.t != t ||
      old.rawT != rawT ||
      old.clearedRows != clearedRows ||
      old.clearedCols != clearedCols ||
      old.blastCells != blastCells ||
      old.clearFxColors != clearFxColors ||
      old.cell != cell;
}

/// Local explosion for conveyor bomb area blasts.
class BlastBurst extends StatelessWidget {
  const BlastBurst({
    super.key,
    required this.colors,
    this.seed = 1,
  });

  final List<Color> colors;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final rng = math.Random(seed);
    return IgnorePointer(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white,
                  const Color(0xFFFF6D00).withValues(alpha: 0.65),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.35, 0.35),
                end: const Offset(3.2, 3.2),
                duration: 380.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeOut(delay: 40.ms, duration: 280.ms),
          ...List.generate(16, (i) {
            final angle = (i / 16) * math.pi * 2 + rng.nextDouble() * 0.2;
            final dist = 40.0 + rng.nextDouble() * 72;
            final size = 5.0 + rng.nextDouble() * 6;
            final color = [
              const Color(0xFFFF6D00),
              const Color(0xFFFF1744),
              Colors.white,
              const Color(0xFFFFE082),
              ...colors,
            ][i % (4 + colors.length)];
            return Align(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 5,
                    ),
                  ],
                ),
              )
                  .animate()
                  .move(
                    begin: Offset.zero,
                    end: Offset(
                      math.cos(angle) * dist,
                      math.sin(angle) * dist,
                    ),
                    duration: 400.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeOut(delay: 60.ms, duration: 240.ms),
            );
          }),
        ],
      ),
    );
  }
}
