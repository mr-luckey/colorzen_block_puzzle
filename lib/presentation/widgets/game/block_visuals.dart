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

  /// Centered emoji that always fits inside [side] (no clipping).
  static Widget centeredEmoji({
    required String emoji,
    required double side,
    Color? shadowColor,
  }) {
    final box = side.clamp(6.0, 200.0);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          child: Text(
            emoji,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 64,
              height: 1,
              leadingDistribution: TextLeadingDistribution.even,
              shadows: [
                Shadow(
                  color: shadowColor ?? Colors.black54,
                  blurRadius: box > 20 ? 3 : 1.5,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
    // Less extrusion on tiny tray cells so emoji stays centered & visible.
    final depth = s < 22
        ? s * 0.04
        : (elevated ? s * 0.1 : s * 0.06);
    // Emoji fills most of the tile while staying clipped-safe.
    final emojiBox = s * (s < 22 ? 0.72 : 0.82);

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.center,
        children: [
          // Extruded bottom face (3D thickness) — kept inside bounds.
          if (depth > 0.5)
            Positioned(
              left: 0,
              right: 0,
              top: depth * 0.4,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  color: Color.lerp(base, Colors.black, 0.55),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: elevated ? 0.45 : 0.28,
                      ),
                      blurRadius: elevated ? 10 : 3,
                      offset: Offset(0, elevated ? 5 : 2),
                    ),
                  ],
                ),
              ),
            ),
          // Main face — fills cell so emoji centers on the tile.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
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
                        width: s < 22 ? 0.8 : 1.2,
                      ),
                    ),
                  ),
                  if (s >= 18) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.12,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.3),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topCenter,
                      child: FractionallySizedBox(
                        heightFactor: 0.35,
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.32),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (showEmoji)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.22),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(emojiBox * 0.04),
                          child: centeredEmoji(
                            emoji: emoji,
                            side: emojiBox * 0.92,
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
    final peak = urgent ? 1.18 : 1.12;
    final box = size.clamp(10.0, 48.0);

    return SizedBox(
      width: box,
      height: box,
      child: BlockVisuals.centeredEmoji(
        emoji: emoji,
        side: box,
        shadowColor:
            (mega ? const Color(0xFFB388FF) : const Color(0xFFFF5252))
                .withValues(alpha: 0.75),
      ),
    )
        .animate(
          key: ValueKey('heartbeat_${mega}_$urgent'),
          onPlay: (c) => c.repeat(),
        )
        .scale(
          begin: const Offset(1, 1),
          end: Offset(peak, peak),
          duration: 100.ms,
          curve: Curves.easeOut,
        )
        .then()
        .scale(
          begin: Offset(peak, peak),
          end: const Offset(1, 1),
          duration: 90.ms,
          curve: Curves.easeIn,
        )
        .then(delay: urgent ? 120.ms : 220.ms);
  }
}
