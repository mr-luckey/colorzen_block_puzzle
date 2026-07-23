import 'package:hive_flutter/hive_flutter.dart';

import 'package:colorzen_block_puzzle/core/constants/hive_constants.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class HiveStorage {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(HiveBoxNames.gameSessionClassic),
      Hive.openBox<Map>(HiveBoxNames.gameSessionDaily),
      Hive.openBox<Map>(HiveBoxNames.gameSessionZen),
      Hive.openBox<Map>(HiveBoxNames.settings),
      Hive.openBox<Map>(HiveBoxNames.themeState),
      Hive.openBox<Map>(HiveBoxNames.dailyChallenges),
      Hive.openBox<Map>(HiveBoxNames.lifetimeStats),
      Hive.openBox<Map>(HiveBoxNames.rankingBoard),
    ]);
  }

  static String boxForMode(GameMode mode) => switch (mode) {
        GameMode.classic => HiveBoxNames.gameSessionClassic,
        GameMode.daily => HiveBoxNames.gameSessionDaily,
        GameMode.zen => HiveBoxNames.gameSessionZen,
      };
}
