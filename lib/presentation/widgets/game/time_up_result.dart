import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';

/// Time-up result — same glass dialog language as the pause sheet.
class TimeUpResultView extends StatelessWidget {
  const TimeUpResultView({
    super.key,
    required this.session,
    required this.isNewBest,
    required this.palette,
    required this.busy,
    required this.onRestart,
    required this.onHome,
    required this.onWatchAd,
  });

  final GameSession session;
  final bool isNewBest;
  final ColorPalette palette;
  final bool busy;
  final VoidCallback onRestart;
  final VoidCallback onHome;
  final VoidCallback onWatchAd;

  @override
  Widget build(BuildContext context) {
    final gold = palette.comboGold;
    final red = palette.invalidRed;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
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
                          Color.lerp(
                            palette.surface,
                            palette.accentPrimary,
                            0.25,
                          )!,
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
                                    red.withValues(alpha: 0.7),
                                    red.withValues(alpha: 0.12),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Icon(
                                Icons.hourglass_empty_rounded,
                                size: 44,
                                color: palette.textPrimary,
                              )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .rotate(
                                    begin: -0.1,
                                    end: 0.1,
                                    duration: 800.ms,
                                  )
                                  .scale(
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.12, 1.12),
                                    duration: 700.ms,
                                  ),
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(0.4, 0.4),
                                  end: const Offset(1, 1),
                                  duration: 520.ms,
                                  curve: Curves.elasticOut,
                                )
                                .fadeIn(duration: 200.ms),
                            const SizedBox(height: 14),
                            Text(
                              "TIME'S UP",
                              style: AppTextStyles.gameOver(red).copyWith(
                                decoration: TextDecoration.none,
                                letterSpacing: 1.2,
                                height: 1.05,
                                shadows: [
                                  Shadow(
                                    color: red.withValues(alpha: 0.55),
                                    blurRadius: 16,
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 80.ms, duration: 280.ms)
                                .scale(
                                  begin: const Offset(0.7, 0.7),
                                  end: const Offset(1, 1),
                                  delay: 80.ms,
                                  duration: 500.ms,
                                  curve: Curves.elasticOut,
                                )
                                .shimmer(
                                  delay: 500.ms,
                                  duration: 1400.ms,
                                  color: gold,
                                ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.black.withValues(alpha: 0.28),
                                border: Border.all(
                                  color: palette.accentSecondary
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'SCORE',
                                    style: AppTextStyles.mini(
                                      palette.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TweenAnimationBuilder<int>(
                                    tween: IntTween(
                                      begin: 0,
                                      end: session.score,
                                    ),
                                    duration: 900.ms,
                                    curve: Curves.easeOutCubic,
                                    builder: (_, value, child) => Text(
                                      NumberFormat('#,###').format(value),
                                      style: AppTextStyles.score(
                                        palette.accentSecondary,
                                      ).copyWith(fontSize: 28),
                                    ),
                                  ),
                                  if (isNewBest) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'NEW BEST!',
                                      style: AppTextStyles.section(gold),
                                    )
                                        .animate(
                                          onPlay: (c) =>
                                              c.repeat(reverse: true),
                                        )
                                        .scale(
                                          begin: const Offset(1, 1),
                                          end: const Offset(1.08, 1.08),
                                          duration: 600.ms,
                                        ),
                                  ],
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(delay: 180.ms, duration: 320.ms)
                                .slideY(begin: 0.2, end: 0, delay: 180.ms),
                            const SizedBox(height: 20),
                            AppButton(
                              label: 'RESTART',
                              onTap: onRestart,
                            )
                                .animate()
                                .fadeIn(delay: 280.ms)
                                .slideY(begin: 0.25, end: 0, delay: 280.ms),
                            const SizedBox(height: 10),
                            AppButton(
                              label: 'HOME',
                              style: AppButtonStyle.secondary,
                              onTap: onHome,
                            )
                                .animate()
                                .fadeIn(delay: 360.ms)
                                .slideY(begin: 0.25, end: 0, delay: 360.ms),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 220.ms)
                  .scale(
                    begin: const Offset(0.88, 0.88),
                    end: const Offset(1, 1),
                    duration: 420.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 18),
              _WatchAdHero(
                busy: busy,
                palette: palette,
                gold: gold,
                seconds: AppConstants.surviveAdBonusSec,
                onTap: onWatchAd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Separate layer — shake + heart pump so the eye lands here first.
class _WatchAdHero extends StatelessWidget {
  const _WatchAdHero({
    required this.busy,
    required this.palette,
    required this.gold,
    required this.seconds,
    required this.onTap,
  });

  final bool busy;
  final ColorPalette palette;
  final Color gold;
  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [
              gold,
              Color.lerp(gold, const Color(0xFFFF6D00), 0.45)!,
            ],
          ),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.7),
              blurRadius: 24,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: palette.invalidRed.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_fill_rounded,
              color: const Color(0xFF102018),
              size: 30,
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.18, 1.18),
                  duration: 420.ms,
                ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                busy ? 'LOADING…' : 'WATCH AD  ·  +${seconds}s',
                textAlign: TextAlign.center,
                style: AppTextStyles.button(const Color(0xFF102018)).copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(delay: 480.ms, duration: 280.ms)
          .slideY(
            begin: 0.4,
            end: 0,
            delay: 480.ms,
            duration: 480.ms,
            curve: Curves.easeOutBack,
          )
          .then(delay: 200.ms)
          .shake(
            hz: 4,
            duration: 700.ms,
            offset: const Offset(7, 0),
            rotation: 0.04,
          )
          .then(delay: 400.ms)
          .animate(onPlay: (c) => c.repeat())
          .shake(
            hz: 3.5,
            duration: 650.ms,
            delay: 1800.ms,
            offset: const Offset(6, 0),
            rotation: 0.035,
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 650.ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}
