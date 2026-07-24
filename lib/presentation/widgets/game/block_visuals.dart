import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Shared emoji + 3D glass look for colored blocks (same color → same emoji).
class BlockVisuals {
  BlockVisuals._();

  static const bombEmoji = '💣';
  static const megaBombEmoji = '💥';

  static String emojiFor(BlockColor color) => switch (color) {
        BlockColor.color0 => '😀',
        BlockColor.color1 => '😎',
        BlockColor.color2 => '🤩',
        BlockColor.color3 => '🥰',
        BlockColor.color4 => '😂',
        BlockColor.color5 => '🥳',
      };

  /// Chunky 3D tile with contrast emoji badge. Fits exactly in [size].
  static Widget glassBlock({
    required double size,
    required Color base,
    required String emoji,
    BorderRadius? borderRadius,
    bool elevated = false,
    bool showEmoji = true,
  }) {
    final s = size.clamp(0.0, 1000.0);
    final radius = borderRadius ?? BorderRadius.circular(s * 0.22);
    final depth = elevated ? s * 0.12 : s * 0.08;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Extruded bottom face (3D thickness).
          Positioned(
            left: 0,
            right: 0,
            top: depth * 0.35,
            bottom: -depth * 0.15,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: Color.lerp(base, Colors.black, 0.55),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: elevated ? 0.55 : 0.35),
                    blurRadius: elevated ? 14 : 5,
                    offset: Offset(0, elevated ? 7 : 3),
                  ),
                  BoxShadow(
                    color: base.withValues(alpha: 0.45),
                    blurRadius: elevated ? 16 : 8,
                    spreadRadius: 0.4,
                  ),
                ],
              ),
            ),
          ),
          // Main face.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(base, Colors.white, 0.28)!,
                          base,
                          Color.lerp(base, Colors.black, 0.32)!,
                          Color.lerp(base, Colors.black, 0.48)!,
                        ],
                        stops: const [0.0, 0.38, 0.78, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                        width: 1.2,
                      ),
                    ),
                  ),
                  // Left bevel (light).
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.14,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right / bottom bevel (dark).
                  Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.16,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.black.withValues(alpha: 0.28),
                              Colors.black.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Top gloss.
                  Align(
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.4,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(s * 0.22),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.38),
                              Colors.white.withValues(alpha: 0.08),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Specular chip.
                  Positioned(
                    top: s * 0.1,
                    left: s * 0.12,
                    child: Container(
                      width: s * 0.28,
                      height: s * 0.1,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(s),
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                  ),
                  if (showEmoji)
                    Center(
                      child: Container(
                        width: s * 0.72,
                        height: s * 0.72,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          emoji,
                          style: TextStyle(
                            fontSize: (s * 0.46).clamp(10.0, 30.0),
                            height: 1,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bomb emoji with lub-dub heartbeat (layout-safe).
class BeatingBombEmoji extends StatelessWidget {
  const BeatingBombEmoji({
    super.key,
    required this.size,
    this.mega = false,
    this.urgent = false,
  });

  final double size;
  final bool mega;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final emoji =
        mega ? BlockVisuals.megaBombEmoji : BlockVisuals.bombEmoji;
    final peak = urgent ? 1.22 : 1.14;

    return Text(
      emoji,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: (size * 0.9).clamp(12.0, 32.0),
        height: 1,
        shadows: [
          Shadow(
            color: (mega ? const Color(0xFFB388FF) : const Color(0xFFFF5252))
                .withValues(alpha: 0.75),
            blurRadius: urgent ? 12 : 7,
          ),
        ],
      ),
    )
        .animate(
          key: ValueKey('heartbeat_${mega}_$urgent'),
          onPlay: (c) => c.repeat(),
        )
        .scale(
          begin: const Offset(1, 1),
          end: Offset(peak, peak),
          duration: 160.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: Offset(peak, peak),
          end: const Offset(1, 1),
          duration: 140.ms,
          curve: Curves.easeIn,
        )
        .then(delay: 60.ms)
        .scale(
          begin: const Offset(1, 1),
          end: Offset(peak * 0.92, peak * 0.92),
          duration: 140.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: Offset(peak * 0.92, peak * 0.92),
          end: const Offset(1, 1),
          duration: 160.ms,
          curve: Curves.easeIn,
        )
        .then(delay: urgent ? 220.ms : 420.ms);
  }
}
