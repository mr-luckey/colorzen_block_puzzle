import 'package:get_it/get_it.dart';

import 'package:colorzen_block_puzzle/core/config/ads_config.dart';
import 'package:colorzen_block_puzzle/core/navigation/app_navigator.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/piece_generator.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/analytics_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:colorzen_block_puzzle/services/iap_service.dart';
import 'package:colorzen_block_puzzle/services/local_notification_service.dart';
import 'package:colorzen_block_puzzle/services/review_service.dart';
import 'package:colorzen_block_puzzle/services/share_service.dart';
import 'package:colorzen_block_puzzle/services/update_service.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final repo = HiveGameRepository();
  sl.registerSingleton<GameRepository>(repo);

  sl.registerLazySingleton(() => PieceGenerator());
  sl.registerLazySingleton(() => LineClearEngine());

  final settingsCubit = SettingsCubit(repo);
  await settingsCubit.load();
  sl.registerSingleton<SettingsCubit>(settingsCubit);

  final themeCubit = ThemeCubit(repo);
  await themeCubit.load();
  sl.registerSingleton<ThemeCubit>(themeCubit);

  sl.registerLazySingleton<HapticService>(
    () => FlutterHapticService(
      settingsProvider: () => sl<SettingsCubit>().state,
    ),
  );

  final audio = AudioPlayersService(
    settingsProvider: () => sl<SettingsCubit>().state,
  );
  await audio.init();
  sl.registerSingleton<AudioService>(audio);
  settingsCubit.bindOnChanged(audio.syncFromSettings);
  MusicBootstrapHooks.ensureMusic = audio.ensureMusicPlaying;
  MusicBootstrapHooks.onPaused = audio.onAppPaused;
  MusicBootstrapHooks.onResumed = audio.onAppResumed;
  // Don't rely on this alone — Android may block until UI/gesture.
  await audio.syncFromSettings(settingsCubit.state);

  sl.registerLazySingleton<AnalyticsService>(AnalyticsService.new);

  sl.registerLazySingleton<LocalNotificationService>(
    () => LocalNotificationService(
      onTap: (payload) {
        sl<AnalyticsService>().logNotificationOpened(
          notificationId: payload,
          source: 'local',
        );
        appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      },
    ),
  );

  // Register only — never await AdMob here. Offline / slow GMS was hanging
  // native splash forever. Bootstrap after first UI frame (see HomeScreen).
  sl.registerSingleton<AdService>(AdsService(config: colorZenAdsConfig()));

  final iap = InAppPurchaseService();
  await iap.init(
    onAdsOwnershipChanged: (removed) {
      if (removed) {
        sl<SettingsCubit>().setAdsRemoved(true);
      }
    },
  );
  sl.registerSingleton<IapService>(iap);

  sl.registerLazySingleton<ShareService>(() => SharePlusService());
  sl.registerLazySingleton<UpdateService>(() => PlayUpdateService());
  sl.registerLazySingleton<ReviewService>(() => InAppReviewService());
}
