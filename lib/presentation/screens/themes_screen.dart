import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: 1000.ms);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeCubit>().state;
    final palette = AppPalettes.of(themeState.selected);

    return Scaffold(
      body: WoodBackground(
        palette: palette,
        dimmed: true,
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: palette.textPrimary),
              title: Text(
                'Themes',
                style: AppTextStyles.appBar(palette.textPrimary),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.85,
              children: AppThemeId.values.map((id) {
                final unlocked = themeState.isUnlocked(id);
                final selected = themeState.selected == id;
                final p = AppPalettes.of(id);
                return _ThemeCard(
                  id: id,
                  palette: p,
                  uiPalette: palette,
                  unlocked: unlocked,
                  selected: selected,
                  onSelect: () => context.read<ThemeCubit>().selectTheme(id),
                  onUnlockAd: () async {
                    final ok = await sl<AdService>().showRewarded(
                      onEarned: () {},
                    );
                    if (!context.mounted) return;
                    if (ok) {
                      await context.read<ThemeCubit>().unlockTheme(id);
                      _confetti.play();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${AppPalettes.nameOf(id)} unlocked!',
                            ),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Rewarded ad not ready. Try again in a moment.',
                          ),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      colors: palette.blocks,
                      numberOfParticles: 30,
                      maxBlastForce: 20,
                      minBlastForce: 10,
                      emissionFrequency: 0.02,
                      gravity: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.id,
    required this.palette,
    required this.uiPalette,
    required this.unlocked,
    required this.selected,
    required this.onSelect,
    required this.onUnlockAd,
  });

  final AppThemeId id;
  final ColorPalette palette;
  final ColorPalette uiPalette;
  final bool unlocked;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onUnlockAd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: unlocked
          ? onSelect
          : () {
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: uiPalette.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unlock ${AppPalettes.nameOf(id)}',
                        style: AppTextStyles.section(uiPalette.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reach ${AppPalettes.unlockScore(id)} Classic points, or watch a rewarded ad.',
                        style: AppTextStyles.body(uiPalette.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: uiPalette.accentPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onUnlockAd();
                        },
                        child: const Text('Watch Ad to Unlock'),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              );
            },
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? palette.accentPrimary
                : palette.accentPrimary.withValues(alpha: 0.15),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: palette.accentPrimary.withValues(alpha: 0.45),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppPalettes.nameOf(id),
                  style: AppTextStyles.section(palette.textPrimary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: palette.blocks
                      .take(5)
                      .map(
                        (c) => Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white24,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Spacer(),
                if (selected)
                  Text(
                    'SELECTED',
                    style: AppTextStyles.mini(palette.accentSecondary),
                  )
                else if (!unlocked)
                  Text(
                    '${AppPalettes.unlockScore(id)} pts',
                    style: AppTextStyles.mini(palette.textSecondary),
                  ),
              ],
            ),
            if (!unlocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_rounded, color: Colors.white70, size: 32),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
