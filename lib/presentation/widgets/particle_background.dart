import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Lightweight floating particles (menus only). Throttled ~20fps.
class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key, required this.palette});

  final ColorPalette palette;

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<_Particle> _particles;
  final _random = Random(42);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  var _accum = 0.0;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(12, (_) => _randomParticle());
    _ticker = createTicker((elapsed) {
      if (_last == Duration.zero) {
        _last = elapsed;
        return;
      }
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (dt <= 0 || dt > 0.08) return;
      _accum += dt;
      // ~20 updates/sec — enough for soft drift, cheap for UI thread.
      if (_accum < 0.05) return;
      _accum = 0;
      for (final p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        if (p.x < -0.05) p.x = 1.05;
        if (p.x > 1.05) p.x = -0.05;
        if (p.y < -0.05) p.y = 1.05;
        if (p.y > 1.05) p.y = -0.05;
      }
      _frame.value++;
    })
      ..start();
  }

  _Particle _randomParticle() {
    final color = widget.palette.blocks[_random.nextInt(6)];
    final speed = 0.00012 + _random.nextDouble() * 0.00018;
    final angle = _random.nextDouble() * pi * 2;
    return _Particle(
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      radius: 2.5 + _random.nextDouble() * 3,
      color: color.withValues(alpha: 0.2),
      vx: cos(angle) * speed,
      vy: sin(angle) * speed,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: _frame,
        builder: (context, _, __) {
          return CustomPaint(
            painter: _ParticlePainter(_particles),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Particle {
  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.vx,
    required this.vy,
  });

  double x;
  double y;
  final double radius;
  final Color color;
  final double vx;
  final double vy;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.particles);

  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      paint.color = p.color;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
