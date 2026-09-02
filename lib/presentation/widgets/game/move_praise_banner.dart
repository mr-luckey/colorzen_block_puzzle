import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

/// Big animated praise that pops after a strong clear.
class MovePraiseBanner extends StatelessWidget {
  const MovePraiseBanner({
    super.key,
    required this.praise,
    required this.palette,
  });

  final MovePraise praise;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    if (praise == MovePraise.none) return const SizedBox.shrink();

    final label = RankingEngine.praiseLabel(praise);
    final color = switch (praise) {
      MovePraise.nice => palette.accentPrimary,
      MovePraise.great => const Color(0xFF5B8CFF),
      MovePraise.awesome => palette.accentSecondary,
      MovePraise.legendary => palette.comboGold,
      MovePraise.allClear => const Color(0xFFFFEA00),
      MovePraise.none => palette.textPrimary,
    };

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.55),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.praise(color).copyWith(
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.7), blurRadius: 22),
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 120.ms)
                .scale(
                  begin: const Offset(0.35, 0.35),
                  end: const Offset(1.15, 1.15),
                  duration: 320.ms,
                  curve: Curves.easeOutBack,
                )
                .then()
                .scale(
                  begin: const Offset(1.15, 1.15),
                  end: const Offset(1, 1),
                  duration: 120.ms,
                )
                .then(delay: 420.ms)
                .fadeOut(duration: 280.ms)
                .moveY(begin: 0, end: -28, duration: 280.ms),
            if (praise == MovePraise.legendary ||
                praise == MovePraise.awesome ||
                praise == MovePraise.allClear)
              Text(
                praise == MovePraise.allClear
                    ? 'Board wiped — keep going!'
                    : praise == MovePraise.legendary
                        ? 'Unstoppable streak!'
                        : 'Keep the heat!',
                style: AppTextStyles.body(palette.textPrimary).copyWith(
                  color: palette.textPrimary.withValues(alpha: 0.9),
                ),
              )
                  .animate()
                  .fadeIn(delay: 80.ms, duration: 200.ms)
                  .then(delay: 500.ms)
                  .fadeOut(duration: 250.ms),
          ],
        ),
      ),
    );
  }
}
