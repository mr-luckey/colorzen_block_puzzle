import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';

/// Soft prompt when a newer Play Store build is available.
Future<bool> showUpdateAvailableDialog({
  required BuildContext context,
  required ColorPalette palette,
}) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Update available',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: 280.ms,
    pageBuilder: (ctx, anim, secondary) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, secondary, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
          child: _UpdateCard(palette: palette),
        ),
      );
    },
  );
  return result ?? false;
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.palette});

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
                          Icons.system_update_rounded,
                          size: 40,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'UPDATE AVAILABLE',
                        style: AppTextStyles.gameOver(palette.textPrimary)
                            .copyWith(
                          decoration: TextDecoration.none,
                          letterSpacing: 0.6,
                          height: 1.05,
                          fontSize: 26,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'A newer version of ColorZen is on the Play Store. '
                        'Update for the latest fixes and improvements.',
                        style: AppTextStyles.body(palette.textSecondary)
                            .copyWith(decoration: TextDecoration.none),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'UPDATE NOW',
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'LATER',
                        style: AppButtonStyle.secondary,
                        onTap: () => Navigator.of(context).pop(false),
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
