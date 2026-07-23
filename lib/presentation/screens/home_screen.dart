import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/daily/daily_challenge_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/screens/game_screen.dart';
import 'package:colorzen_block_puzzle/presentation/screens/ranking_screen.dart';
import 'package:colorzen_block_puzzle/presentation/screens/settings_screen.dart';
import 'package:colorzen_block_puzzle/presentation/screens/themes_screen.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/ads/banner_ad_bar.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/app_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openGame(
    BuildContext context,
    GameMode mode, {
    bool forceNew = false,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: 320.ms,
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(mode: mode, forceNew: forceNew),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ).then((_) {
      // Refresh continue state when returning home.
      if (context.mounted) {
        (context as Element).markNeedsBuild();
      }
    });
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: 300.ms,
        pageBuilder: (c, a, s) => page,
        transitionsBuilder: (c, a, s, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Future<GameSession?> _savedClassic() async {
    final s = await sl<GameRepository>().loadSession(GameMode.classic);
    if (s == null || s.isGameOver) return null;
    final hasPieces = s.currentPieces.any((p) => p != null);
    final hasBlocks = s.grid.any((row) => row.any((c) => c != null));
    if (!hasPieces && !hasBlocks && s.movesMade <= 0) return null;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeCubit>().state;
    final palette = AppPalettes.of(themeState.selected);
    final daily = context.watch<DailyChallengeCubit>().state;
    final adsRemoved = context.watch<SettingsCubit>().state.adsRemoved;
    final pad = (MediaQuery.sizeOf(context).width * 0.055).clamp(16.0, 26.0);

    return Scaffold(
      body: WoodBackground(
        palette: palette,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final content = Column(
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const SizedBox(width: 48),
                              const Spacer(),
                              FutureBuilder(
                                future: sl<GameRepository>().loadStats(),
                                builder: (context, snap) {
                                  final best = snap.data?.classicBest ?? 0;
                                  return Row(
                                    children: [
                                      Icon(
                                        Icons.emoji_events_rounded,
                                        color: palette.accentSecondary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        NumberFormat('#,###').format(best),
                                        style: AppTextStyles.section(
                                          palette.accentSecondary,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () =>
                                    _open(context, const SettingsScreen()),
                                icon: Icon(
                                  Icons.settings_rounded,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 8),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          palette.accentPrimary,
                          palette.accentSecondary,
                          palette.accentPrimary,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        AppConstants.appName.toUpperCase(),
                        style: AppTextStyles.logo(Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(begin: -0.1, end: 0),
                    const SizedBox(height: 4),
                    Text(
                      'Block Puzzle',
                      style: AppTextStyles.tagline(palette.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    _ModeCard(
                      title: 'CLASSIC',
                      subtitle: 'Score · Bombs · Ranking',
                      icon: Icons.emoji_events_rounded,
                      iconColor: palette.accentSecondary,
                      palette: palette,
                      onTap: () => _openGame(context, GameMode.classic),
                    )
                        .animate()
                        .fadeIn(delay: 60.ms)
                        .slideY(begin: 0.12, end: 0),
                    const SizedBox(height: 10),
                    _ModeCard(
                      title: 'DAILY CHALLENGE',
                      subtitle: daily.completed
                          ? 'Done · Score ${daily.score}'
                          : 'Shared puzzle · 1.5× · ${daily.countdown}',
                      icon: Icons.calendar_month_rounded,
                      iconColor: const Color(0xFF42A5F5),
                      palette: palette,
                      onTap: () => _openGame(context, GameMode.daily),
                    )
                        .animate()
                        .fadeIn(delay: 120.ms)
                        .slideY(begin: 0.12, end: 0),
                    const SizedBox(height: 10),
                    _ModeCard(
                      title: 'ZEN MODE',
                      subtitle: 'No score · No bombs · Never ends',
                      icon: Icons.spa_rounded,
                      iconColor: const Color(0xFF66BB6A),
                      palette: palette,
                      onTap: () => _openGame(context, GameMode.zen),
                    )
                        .animate()
                        .fadeIn(delay: 180.ms)
                        .slideY(begin: 0.12, end: 0),
                    const Spacer(),
                    FutureBuilder<GameSession?>(
                      future: _savedClassic(),
                      builder: (context, snap) {
                        final saved = snap.data;
                        if (saved != null) {
                          return Column(
                            children: [
                              AppButton(
                                label: 'CONTINUE',
                                subtitle:
                                    'Score ${NumberFormat('#,###').format(saved.score)} · ${saved.movesMade} moves',
                                leading:
                                    const Icon(Icons.play_arrow_rounded),
                                onTap: () => _openGame(
                                  context,
                                  GameMode.classic,
                                ),
                              ),
                              const SizedBox(height: 10),
                              AppButton(
                                label: 'NEW GAME',
                                style: AppButtonStyle.secondary,
                                leading: const Icon(Icons.refresh_rounded),
                                onTap: () => _openGame(
                                  context,
                                  GameMode.classic,
                                  forceNew: true,
                                ),
                              ),
                            ],
                          );
                        }
                        return AppButton(
                          label: 'PLAY',
                          leading: const Icon(Icons.play_arrow_rounded),
                          onTap: () =>
                              _openGame(context, GameMode.classic),
                        );
                      },
                    )
                        .animate()
                        .fadeIn(delay: 220.ms)
                        .scale(
                          begin: const Offset(0.96, 0.96),
                          end: const Offset(1, 1),
                        ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _NavChip(
                          icon: Icons.leaderboard_rounded,
                          label: 'Rank',
                          palette: palette,
                          onTap: () => _open(context, const RankingScreen()),
                        ),
                        _NavChip(
                          icon: Icons.bar_chart_rounded,
                          label: 'Stats',
                          palette: palette,
                          onTap: () => _showStats(context, palette),
                        ),
                        _NavChip(
                          icon: Icons.palette_rounded,
                          label: 'Themes',
                          palette: palette,
                          onTap: () => _open(context, const ThemesScreen()),
                        ),
                        _NavChip(
                          icon: Icons.settings_rounded,
                          label: 'Setting',
                          palette: palette,
                          onTap: () =>
                              _open(context, const SettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                );

                if (constraints.maxHeight < 620) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(child: content),
                    ),
                  );
                }
                return content;
                    },
                  ),
                ),
              ),
              BannerAdBar(adsRemoved: adsRemoved),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showStats(BuildContext context, ColorPalette palette) async {
    final stats = await sl<GameRepository>().loadStats();
    final board = await sl<GameRepository>().loadRanking();
    if (!context.mounted) return;
    final best = board.entries.isEmpty ? null : board.entries.first;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WoodPanel(
        palette: palette,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Journey',
              style: AppTextStyles.section(palette.textPrimary),
            ),
            const SizedBox(height: 14),
            _row('Games', '${stats.totalGamesPlayed}', palette),
            _row(
              'Classic best',
              NumberFormat('#,###').format(stats.classicBest),
              palette,
            ),
            _row('Lines cleared', '${stats.totalLinesCleared}', palette),
            if (best != null) ...[
              _row('Best rank points', '${best.rankPoints}', palette),
              _row('Best moves run', '${best.movesMade}', palette),
            ],
            const SizedBox(height: 16),
            AppButton(
              label: 'CLOSE',
              style: AppButtonStyle.secondary,
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, ColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.body(palette.textSecondary)),
          ),
          Text(value, style: AppTextStyles.section(palette.accentSecondary)),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final ColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: WoodPanel(
          palette: palette,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: iconColor.withValues(alpha: 0.18),
                  border: Border.all(color: iconColor.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.section(palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.mini(palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavChip extends StatelessWidget {
  const _NavChip({
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(palette.surface, Colors.white, 0.1)!,
                    palette.surface,
                  ],
                ),
                border: Border.all(
                  color: palette.accentSecondary.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, color: palette.accentSecondary, size: 22),
            ),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.mini(palette.textSecondary)),
          ],
        ),
      ),
    );
  }
}
