import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';

enum AppButtonStyle { primary, secondary, ghost }

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = AppButtonStyle.primary,
    this.leading,
    this.subtitle,
  });

  final String label;
  final VoidCallback? onTap;
  final AppButtonStyle style;
  final Widget? leading;
  final String? subtitle;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  final ValueNotifier<bool> _pressed = ValueNotifier(false);

  @override
  void dispose() {
    _pressed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);
    final isPrimary = widget.style == AppButtonStyle.primary;
    final isGhost = widget.style == AppButtonStyle.ghost;

    // Bright PLAY uses theme accent; secondary = glass panel + gold text.
    final textColor = isPrimary
        ? const Color(0xFF102018)
        : (isGhost ? palette.textSecondary : palette.accentSecondary);

    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => _pressed.value = true,
        onTapUp: widget.onTap == null
            ? null
            : (_) {
                _pressed.value = false;
                sl<HapticService>().selection();
                sl<AudioService>().playSfx(SfxType.tap);
                widget.onTap?.call();
              },
        onTapCancel: () => _pressed.value = false,
        child: ValueListenableBuilder<bool>(
          valueListenable: _pressed,
          builder: (context, pressed, _) {
            return AnimatedScale(
              scale: pressed ? 0.96 : 1.0,
              duration: const Duration(milliseconds: 80),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                constraints: const BoxConstraints(minHeight: 58),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: isPrimary
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(palette.accentPrimary, Colors.white, 0.35)!,
                            palette.accentPrimary,
                            Color.lerp(palette.accentPrimary, Colors.black, 0.15)!,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color.lerp(palette.surface, Colors.white, 0.14)!,
                            palette.surface,
                            Color.lerp(palette.surface, Colors.black, 0.12)!,
                          ],
                        ),
                  color: isGhost ? Colors.transparent : null,
                  border: Border.all(
                    color: isPrimary
                        ? Colors.white.withValues(alpha: 0.55)
                        : palette.accentSecondary.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  boxShadow: isGhost
                      ? null
                      : [
                          BoxShadow(
                            color: isPrimary
                                ? palette.accentPrimary.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 7),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.leading != null) ...[
                          IconTheme(
                            data: IconThemeData(color: textColor, size: 26),
                            child: widget.leading!,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            style: AppTextStyles.button(textColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: AppTextStyles.mini(
                          textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
