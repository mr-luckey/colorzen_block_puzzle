import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Fun confetti-style burst when lines clear.
class ClearBurst extends StatelessWidget {
  const ClearBurst({
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
        children: List.generate(18, (i) {
          final angle = (i / 18) * math.pi * 2 + rng.nextDouble() * 0.4;
          final dist = 40.0 + rng.nextDouble() * 90;
          final size = 6.0 + rng.nextDouble() * 8;
          final color = colors[i % colors.length];
          return Align(
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(
                math.cos(angle) * dist * 0.2,
                math.sin(angle) * dist * 0.2,
              ),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              )
                  .animate()
                  .move(
                    begin: Offset.zero,
                    end: Offset(math.cos(angle) * dist, math.sin(angle) * dist),
                    duration: 650.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeOut(delay: 280.ms, duration: 380.ms)
                  .rotate(begin: 0, end: rng.nextDouble() * 2 - 1),
            ),
          );
        }),
      ),
    );
  }
}
