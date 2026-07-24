import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);
    final settings = context.watch<SettingsCubit>().state;

    return Scaffold(
      body: WoodBackground(
        palette: palette,
        dimmed: true,
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: palette.textPrimary),
                title: Text(
                  'Settings',
                  style: AppTextStyles.appBar(palette.textPrimary),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _SettingsCard(
                      palette: palette,
                      title: 'Themes',
                      children: [
                        Text(
                          'Enchanted Night is free. Unlock more with Classic score or a rewarded ad.',
                          style: AppTextStyles.mini(palette.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        _ThemesGrid(uiPalette: palette),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      palette: palette,
                      title: 'Audio',
                      children: [
                        _SwitchRow(
                          palette: palette,
                          label: 'Sound Effects',
                          value: settings.sfxEnabled,
                          onChanged: (_) async {
                            final cubit = context.read<SettingsCubit>();
                            await cubit.toggleSfx();
                            sl<HapticService>().selection();
                            if (cubit.state.sfxEnabled) {
                              sl<AudioService>().playSfx(SfxType.tap);
                            }
                          },
                        ),
                        _SwitchRow(
                          palette: palette,
                          label: 'Music',
                          value: settings.musicEnabled,
                          onChanged: (_) async {
                            await context.read<SettingsCubit>().toggleMusic();
                            sl<HapticService>().selection();
                            await sl<AudioService>().ensureMusicPlaying();
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                          child: Text(
                            'Music Volume',
                            style: AppTextStyles.body(palette.textPrimary),
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: palette.accentPrimary,
                            inactiveTrackColor:
                                palette.textSecondary.withValues(alpha: 0.25),
                            thumbColor: palette.accentSecondary,
                            overlayColor:
                                palette.accentPrimary.withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: settings.musicVolume,
                            onChanged: settings.musicEnabled
                                ? (v) =>
                                    context.read<SettingsCubit>().setVolume(v)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      palette: palette,
                      title: 'Feel',
                      children: [
                        _SwitchRow(
                          palette: palette,
                          label: 'Haptic Feedback',
                          value: settings.hapticEnabled,
                          onChanged: (_) async {
                            await context.read<SettingsCubit>().toggleHaptic();
                            sl<HapticService>().selection();
                          },
                        ),
                        _SwitchRow(
                          palette: palette,
                          label: 'Daily Reminder',
                          subtitle: settings.notificationsEnabled
                              ? 'On — preference saved'
                              : 'Off',
                          value: settings.notificationsEnabled,
                          onChanged: (_) async {
                            await context
                                .read<SettingsCubit>()
                                .toggleNotifications();
                            if (!context.mounted) return;
                            final on = context
                                .read<SettingsCubit>()
                                .state
                                .notificationsEnabled;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  on
                                      ? 'Daily reminder preference saved.'
                                      : 'Daily reminder turned off.',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'ColorZen v1.0.0',
                        style: AppTextStyles.mini(palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.palette,
    required this.title,
    required this.children,
  });

  final ColorPalette palette;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return WoodPanel(
      palette: palette,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.section(palette.accentSecondary)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final ColorPalette palette;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.body(palette.textPrimary)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: AppTextStyles.mini(palette.textSecondary)),
      value: value,
      activeThumbColor: palette.accentPrimary,
      activeTrackColor: palette.accentPrimary.withValues(alpha: 0.45),
      inactiveThumbColor: palette.textSecondary,
      inactiveTrackColor: Colors.black.withValues(alpha: 0.35),
      onChanged: onChanged,
    );
  }
}

class _ThemesGrid extends StatelessWidget {
  const _ThemesGrid({required this.uiPalette});

  final ColorPalette uiPalette;

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeCubit>().state;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.35,
      children: AppThemeId.values.map((id) {
        final unlocked = themeState.isUnlocked(id);
        final selected = themeState.selected == id;
        final p = AppPalettes.of(id);
        return _ThemeTile(
          id: id,
          palette: p,
          uiPalette: uiPalette,
          unlocked: unlocked,
          selected: selected,
          onSelect: () => context.read<ThemeCubit>().selectTheme(id),
          onUnlockAd: () async {
            final ok = await sl<AdService>().showRewarded(onEarned: () {});
            if (!context.mounted) return;
            if (ok) {
              await context.read<ThemeCubit>().unlockTheme(id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${AppPalettes.nameOf(id)} unlocked!'),
                ),
              );
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
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: unlocked
            ? onSelect
            : () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: uiPalette.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
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
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? palette.accentPrimary
                  : palette.accentPrimary.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppPalettes.nameOf(id),
                    style: AppTextStyles.mini(palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: palette.blocks
                        .take(4)
                        .map(
                          (c) => Container(
                            width: 14,
                            height: 14,
                            margin: const EdgeInsets.only(right: 3),
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const Spacer(),
                  Text(
                    selected
                        ? 'SELECTED'
                        : (!unlocked
                            ? '${AppPalettes.unlockScore(id)} pts'
                            : 'TAP'),
                    style: AppTextStyles.mini(
                      selected
                          ? palette.accentSecondary
                          : palette.textSecondary,
                    ),
                  ),
                ],
              ),
              if (!unlocked)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
