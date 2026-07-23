import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  final _board = ValueNotifier<RankingBoard?>(null);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final board = await sl<GameRepository>().loadRanking();
    if (!mounted) return;
    _board.value = board;
  }

  /// Local "TOP X%" based on position among saved runs.
  String _topPercent(int index, int total) {
    if (total <= 1) return 'TOP 1%';
    final pct = (((index + 1) / total) * 100).clamp(1, 99).round();
    return 'TOP $pct%';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);

    return ValueListenableBuilder<RankingBoard?>(
      valueListenable: _board,
      builder: (context, board, _) {
        final loading = board == null;
        final entries = board?.entries ?? const <RankingEntry>[];
        return _buildBody(context, palette, loading, entries);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    ColorPalette palette,
    bool loading,
    List<RankingEntry> entries,
  ) {
    return Scaffold(
      body: WoodBackground(
        palette: palette,
        dimmed: true,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: palette.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Survival Rank',
                        style: AppTextStyles.appBar(palette.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Ranked by moves survived — idle standing does not count.',
                  style: AppTextStyles.body(palette.textSecondary),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: loading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: palette.accentPrimary,
                        ),
                      )
                    : entries.isEmpty
                        ? Center(
                            child: Text(
                              'No runs yet.\nPlay Classic and climb!',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.body(palette.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: entries.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final e = entries[i];
                              final tier = RankingEngine.tierFor(
                                movesMade: e.movesMade,
                                activeSurviveMs: e.activeSurviveMs,
                              );
                              return _RankTile(
                                rank: i + 1,
                                topLabel: _topPercent(i, entries.length),
                                entry: e,
                                tier: tier,
                                palette: palette,
                              )
                                  .animate()
                                  .fadeIn(delay: (40 * i).ms)
                                  .slideX(begin: 0.08, end: 0);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.rank,
    required this.topLabel,
    required this.entry,
    required this.tier,
    required this.palette,
  });

  final int rank;
  final String topLabel;
  final RankingEntry entry;
  final RankTier tier;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C7D1),
      3 => const Color(0xFFCD7F32),
      _ => palette.accentPrimary,
    };
    final date = DateFormat('MMM d').format(
      DateTime.fromMillisecondsSinceEpoch(entry.playedAtMs),
    );
    final mode = entry.mode == GameMode.daily ? 'Daily' : 'Classic';

    return WoodPanel(
      palette: palette,
      borderColor: medal.withValues(alpha: rank <= 3 ? 0.7 : 0.25),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: medal.withValues(alpha: 0.2),
            child: Text(
              '#$rank',
              style: AppTextStyles.mini(medal).copyWith(fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RankingEngine.tierLabel(tier),
                  style: AppTextStyles.section(palette.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  '$mode · ${entry.movesMade} moves · $date',
                  style: AppTextStyles.mini(palette.textSecondary),
                ),
                Text(
                  'Score ${NumberFormat('#,###').format(entry.score)} · $topLabel',
                  style: AppTextStyles.mini(
                    palette.accentSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.rankPoints}',
            style: AppTextStyles.score(medal).copyWith(fontSize: 18),
          ),
        ],
      ),
    );
  }
}
