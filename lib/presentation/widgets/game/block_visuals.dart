import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Shared emoji + glass look for colored blocks (same color → same emoji).
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

  /// Glass tile with color tint + centered emoji. Fits exactly in [size].
  static Widget glassBlock({
    required double size,
    required Color base,
    required String emoji,
    BorderRadius? borderRadius,
    bool elevated = false,
    bool showEmoji = true,
  }) {
    final s = size.clamp(0.0, 1000.0);
    final radius = borderRadius ?? BorderRadius.circular(s * 0.2);

    return SizedBox(
      width: s,
      height: s,
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
                    // Dark glass so yellow face emojis stay readable.
                    Color.lerp(base, Colors.white, 0.1)!,
                    base,
                    Color.lerp(base, Colors.black, 0.35)!,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.28),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: elevated ? 0.4 : 0.25),
                    blurRadius: elevated ? 10 : 3,
                    offset: Offset(0, elevated ? 5 : 1.5),
                  ),
                  BoxShadow(
                    color: base.withValues(alpha: 0.4),
                    blurRadius: elevated ? 12 : 6,
                    spreadRadius: 0.2,
                  ),
                ],
              ),
            ),
            const ColoredBox(color: Color(0x10FFFFFF)),
            Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.38,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(s * 0.2),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.04),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: s * 0.1,
              left: s * 0.12,
              child: Container(
                width: s * 0.26,
                height: s * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(s),
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
            ),
            if (showEmoji)
              Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: (s * 0.5).clamp(10.0, 28.0),
                    height: 1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
