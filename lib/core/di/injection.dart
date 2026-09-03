import 'package:get_it/get_it.dart';

import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/piece_generator.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/ad_service.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:colorzen_block_puzzle/services/iap_service.dart';
import 'package:colorzen_block_puzzle/services/review_service.dart';
import 'package:colorzen_block_puzzle/services/share_service.dart';

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
  // Non-blocking: audio init can hang on some Android devices (setAudioContext).
  // MusicBootstrap will kick playback after first frame anyway.
  try {
    await audio.init().timeout(const Duration(seconds: 3));
  } catch (_) {
    // Swallow — audio will stay silent rather than blocking splash forever.
  }
  sl.registerSingleton<AudioService>(audio);
  settingsCubit.bindOnChanged(audio.syncFromSettings);
  MusicBootstrapHooks.ensureMusic = audio.ensureMusicPlaying;
  MusicBootstrapHooks.onPaused = audio.onAppPaused;
  MusicBootstrapHooks.onResumed = audio.onAppResumed;
  // Don't rely on this alone — Android may block until UI/gesture.
  try {
    await audio.syncFromSettings(settingsCubit.state).timeout(const Duration(seconds: 2));
  } catch (_) {}

  // Register only — never await AdMob here. Offline / slow GMS was hanging
  // native splash forever. Bootstrap after first UI frame (see HomeScreen).
  sl.registerSingleton<AdService>(AdMobService());

  final iap = InAppPurchaseService();
  // Non-blocking: Play Services / billing can stall on some devices → ANR.
  try {
    await iap.init(
      onAdsOwnershipChanged: (removed) {
        if (removed) {
          sl<SettingsCubit>().setAdsRemoved(true);
        }
      },
    ).timeout(const Duration(seconds: 4));
  } catch (_) {
    // IAP unavailable — user just won't see purchase options.
  }
  sl.registerSingleton<IapService>(iap);

  sl.registerLazySingleton<ShareService>(() => SharePlusService());
  sl.registerLazySingleton<ReviewService>(() => InAppReviewService());
}
