import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/ads/banner_ad_bar.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:colorzen_block_puzzle/services/iap_service.dart';

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
          bottom: false,
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
                    const SizedBox(height: 14),
                    _SettingsCard(
                      palette: palette,
                      title: 'Ads (test units)',
                      children: [
                        Text(
                          'Google sample ads — banner, interstitial & rewarded.',
                          style: AppTextStyles.mini(palette.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          label: 'SHOW INTERSTITIAL',
                          style: AppButtonStyle.secondary,
                          onTap: settings.adsRemoved
                              ? null
                              : () async {
                                  final shown = await sl<AdService>()
                                      .showInterstitial(
                                    adsRemoved: settings.adsRemoved,
                                    ignoreCooldown: true,
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        shown
                                            ? 'Interstitial shown.'
                                            : 'Interstitial not ready / cooldown.',
                                      ),
                                    ),
                                  );
                                },
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'SHOW REWARDED',
                          style: AppButtonStyle.secondary,
                          onTap: () async {
                            final ok = await sl<AdService>().showRewarded(
                              onEarned: () {},
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Reward earned.'
                                      : 'Rewarded ad not ready. Try again.',
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          settings.adsRemoved
                              ? 'Banner hidden — ads removed.'
                              : 'Banner also shows at the bottom of this screen.',
                          style: AppTextStyles.mini(palette.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      palette: palette,
                      title: 'Store',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            settings.adsRemoved
                                ? 'Ads Removed ✓'
                                : 'Remove Ads',
                            style: AppTextStyles.body(palette.textPrimary),
                          ),
                          subtitle: Text(
                            settings.adsRemoved
                                ? 'Thank you for supporting ColorZen'
                                : 'One-time · hides banner & interstitial',
                            style: AppTextStyles.mini(palette.textSecondary),
                          ),
                          trailing: Icon(
                            settings.adsRemoved
                                ? Icons.check_circle_rounded
                                : Icons.chevron_right_rounded,
                            color: settings.adsRemoved
                                ? palette.accentPrimary
                                : palette.textSecondary,
                          ),
                          onTap: settings.adsRemoved
                              ? null
                              : () async {
                                  final ok = await sl<IapService>()
                                      .purchaseRemoveAds();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        ok
                                            ? 'Purchase started…'
                                            : 'Store unavailable. Try again later.',
                                      ),
                                    ),
                                  );
                                },
                        ),
                        const Divider(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Restore Purchases',
                            style: AppTextStyles.body(palette.textPrimary),
                          ),
                          trailing: Icon(
                            Icons.restore_rounded,
                            color: palette.textSecondary,
                          ),
                          onTap: () async {
                            final ok =
                                await sl<IapService>().restorePurchases();
                            if (!context.mounted) return;
                            await Future<void>.delayed(
                              const Duration(milliseconds: 400),
                            );
                            if (!context.mounted) return;
                            final removed =
                                context.read<SettingsCubit>().state.adsRemoved;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  removed
                                      ? 'Purchases restored — ads removed.'
                                      : (ok
                                          ? 'Restore requested. Nothing found yet.'
                                          : 'Nothing to restore.'),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SettingsCard(
                      palette: palette,
                      title: 'Info',
                      children: [
                        _LinkRow(
                          palette: palette,
                          label: 'Rate the App',
                          onTap: () => launchUrl(
                            Uri.parse(
                              'https://play.google.com/store/apps/details?id=com.appwaretech.colorzen.puzzle',
                            ),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        _LinkRow(
                          palette: palette,
                          label: 'Privacy Policy',
                          onTap: () => launchUrl(
                            Uri.parse('https://appwaretech.com/privacy'),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                        _LinkRow(
                          palette: palette,
                          label: 'Terms of Service',
                          onTap: () => launchUrl(
                            Uri.parse('https://appwaretech.com/terms'),
                            mode: LaunchMode.externalApplication,
                          ),
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
              BannerAdBar(adsRemoved: settings.adsRemoved),
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final ColorPalette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.body(palette.textPrimary)),
      trailing: Icon(Icons.open_in_new_rounded, color: palette.textSecondary),
      onTap: onTap,
    );
  }
}
