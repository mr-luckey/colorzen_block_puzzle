import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';

enum ReviewPromptResult { rate, later, never }

/// Soft ask for a Play Store review while the user is in the app.
Future<ReviewPromptResult?> showReviewPromptDialog({
  required BuildContext context,
  required ColorPalette palette,
}) {
  return showGeneralDialog<ReviewPromptResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Rate ColorZen',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: 280.ms,
    pageBuilder: (ctx, anim, secondary) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: _ReviewCard(palette: palette),
        ),
      );
    },
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.palette});

  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(palette.surface, Colors.white, 0.12)!,
                    palette.surface,
                    Color.lerp(palette.surface, palette.accentSecondary, 0.22)!,
                  ],
                ),
                border: Border.all(
                  color: palette.accentSecondary.withValues(alpha: 0.55),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accentSecondary.withValues(alpha: 0.28),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    decoration: TextDecoration.none,
                    decorationColor: Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              palette.accentSecondary.withValues(alpha: 0.55),
                              palette.accentSecondary.withValues(alpha: 0.12),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          size: 42,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'ENJOYING COLORZEN?',
                        style: AppTextStyles.gameOver(palette.textPrimary)
                            .copyWith(
                          decoration: TextDecoration.none,
                          letterSpacing: 0.5,
                          height: 1.05,
                          fontSize: 24,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A quick Play Store review helps more players '
                        'discover the game. It only takes a moment.',
                        style: AppTextStyles.body(palette.textSecondary)
                            .copyWith(decoration: TextDecoration.none),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'RATE ON PLAY STORE',
                        onTap: () => Navigator.of(context)
                            .pop(ReviewPromptResult.rate),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'MAYBE LATER',
                        style: AppButtonStyle.secondary,
                        onTap: () => Navigator.of(context)
                            .pop(ReviewPromptResult.later),
                      ),
                      const SizedBox(height: 6),
                      AppButton(
                        label: 'DON\'T ASK AGAIN',
                        style: AppButtonStyle.ghost,
                        onTap: () => Navigator.of(context)
                            .pop(ReviewPromptResult.never),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
