import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/core/constants/hive_constants.dart';
import 'package:colorzen_block_puzzle/data/hive/hive_storage.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

abstract class GameRepository {
  Future<GameSession?> loadSession(GameMode mode);
  Future<void> saveSession(GameSession session);
  Future<void> clearSession(GameMode mode);
  Future<AppSettings> loadSettings();
  Future<void> saveSettings(AppSettings settings);
  Future<ThemeStateData> loadThemeState();
  Future<void> saveThemeState(ThemeStateData state);
  Future<LifetimeStats> loadStats();
  Future<void> saveStats(LifetimeStats stats);
  Future<RankingBoard> loadRanking();
  Future<void> saveRanking(RankingBoard board);
  Future<DailyChallengeRecord?> loadDaily(String date);
  Future<void> saveDaily(DailyChallengeRecord record);
}

class HiveGameRepository implements GameRepository {
  static const _sessionKey = 'session';
  static const _settingsKey = 'settings';
  static const _themeKey = 'theme';
  static const _statsKey = 'stats';
  static const _rankingKey = 'ranking';

  @override
  Future<GameSession?> loadSession(GameMode mode) async {
    final box = Hive.box<Map>(HiveStorage.boxForMode(mode));
    final raw = box.get(_sessionKey);
    if (raw == null) return null;
    try {
      return GameSession.fromMap(Map<dynamic, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveSession(GameSession session) async {
    final box = Hive.box<Map>(HiveStorage.boxForMode(session.mode));
    await box.put(_sessionKey, session.toMap());
  }

  @override
  Future<void> clearSession(GameMode mode) async {
    final box = Hive.box<Map>(HiveStorage.boxForMode(mode));
    await box.delete(_sessionKey);
  }

  @override
  Future<AppSettings> loadSettings() async {
    final box = Hive.box<Map>(HiveBoxNames.settings);
    final raw = box.get(_settingsKey);
    if (raw == null) return const AppSettings();
    return AppSettings.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final box = Hive.box<Map>(HiveBoxNames.settings);
    await box.put(_settingsKey, settings.toMap());
  }

  @override
  Future<ThemeStateData> loadThemeState() async {
    final box = Hive.box<Map>(HiveBoxNames.themeState);
    final raw = box.get(_themeKey);
    if (raw == null) return const ThemeStateData();
    return ThemeStateData.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  @override
  Future<void> saveThemeState(ThemeStateData state) async {
    final box = Hive.box<Map>(HiveBoxNames.themeState);
    await box.put(_themeKey, state.toMap());
  }

  @override
  Future<LifetimeStats> loadStats() async {
    final box = Hive.box<Map>(HiveBoxNames.lifetimeStats);
    final raw = box.get(_statsKey);
    if (raw == null) return const LifetimeStats();
    return LifetimeStats.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  @override
  Future<void> saveStats(LifetimeStats stats) async {
    final box = Hive.box<Map>(HiveBoxNames.lifetimeStats);
    await box.put(_statsKey, stats.toMap());
  }

  @override
  Future<RankingBoard> loadRanking() async {
    final box = Hive.box<Map>(HiveBoxNames.rankingBoard);
    final raw = box.get(_rankingKey);
    if (raw == null) return const RankingBoard();
    return RankingBoard.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  @override
  Future<void> saveRanking(RankingBoard board) async {
    final box = Hive.box<Map>(HiveBoxNames.rankingBoard);
    await box.put(_rankingKey, board.toMap());
  }

  @override
  Future<DailyChallengeRecord?> loadDaily(String date) async {
    final box = Hive.box<Map>(HiveBoxNames.dailyChallenges);
    final raw = box.get(date);
    if (raw == null) return null;
    return DailyChallengeRecord.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  @override
  Future<void> saveDaily(DailyChallengeRecord record) async {
    final box = Hive.box<Map>(HiveBoxNames.dailyChallenges);
    await box.put(record.date, record.toMap());
  }

  static String todayKey([DateTime? date]) =>
      DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
}
