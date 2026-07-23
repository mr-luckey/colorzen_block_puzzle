import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';

/// Gaming-style leave confirmation (not a plain AlertDialog).
Future<bool> showGameExitSheet({
  required BuildContext context,
  required ColorPalette palette,
  required GameMode mode,
  int score = 0,
  int moves = 0,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Leave game',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: 280.ms,
    pageBuilder: (ctx, anim, secondary) {
      return const SizedBox.shrink();
    },
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: _GameExitCard(
            palette: palette,
            mode: mode,
            score: score,
            moves: moves,
          ),
        ),
      );
    },
  );
  return result ?? false;
}

class _GameExitCard extends StatelessWidget {
  const _GameExitCard({
    required this.palette,
    required this.mode,
    required this.score,
    required this.moves,
  });

  final ColorPalette palette;
  final GameMode mode;
  final int score;
  final int moves;

  String get _modeLabel => switch (mode) {
        GameMode.classic => 'CLASSIC',
        GameMode.daily => 'DAILY',
        GameMode.zen => 'ZEN',
      };

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
                    Color.lerp(palette.surface, palette.accentPrimary, 0.25)!,
                  ],
                ),
                border: Border.all(
                  color: palette.accentPrimary.withValues(alpha: 0.65),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.accentPrimary.withValues(alpha: 0.35),
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
                            palette.accentPrimary.withValues(alpha: 0.55),
                            palette.accentPrimary.withValues(alpha: 0.12),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        Icons.pause_circle_filled_rounded,
                        size: 44,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'PAUSE',
                      style: AppTextStyles.gameOver(palette.textPrimary).copyWith(
                        decoration: TextDecoration.none,
                        decorationColor: Colors.transparent,
                        letterSpacing: 0.8,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave this $_modeLabel run?',
                      style: AppTextStyles.body(palette.textSecondary).copyWith(
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatPill(
                            label: mode == GameMode.zen ? 'MOVES' : 'SCORE',
                            value: mode == GameMode.zen
                                ? '$moves'
                                : NumberFormat('#,###').format(score),
                            palette: palette,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatPill(
                            label: 'SAVE',
                            value: 'AUTO',
                            palette: palette,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Progress is saved — continue anytime from Home.',
                      style: AppTextStyles.mini(
                        palette.textSecondary.withValues(alpha: 0.9),
                      ).copyWith(decoration: TextDecoration.none),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    AppButton(
                      label: 'KEEP PLAYING',
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(height: 10),
                    AppButton(
                      label: 'EXIT TO HOME',
                      style: AppButtonStyle.secondary,
                      onTap: () => Navigator.of(context).pop(true),
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

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.palette,
  });

  final String label;
  final String value;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.28),
        border: Border.all(
          color: palette.accentSecondary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Text(label, style: AppTextStyles.mini(palette.textSecondary)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.score(palette.accentSecondary).copyWith(
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}
