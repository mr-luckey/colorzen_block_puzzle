import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/data/hive/hive_storage.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/daily/daily_challenge_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/settings/settings_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await HiveStorage.init();
  await configureDependencies();

  runApp(const ColorZenApp());
}

class ColorZenApp extends StatelessWidget {
  const ColorZenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<ThemeCubit>()),
        BlocProvider.value(value: sl<SettingsCubit>()),
        BlocProvider(
          create: (_) => DailyChallengeCubit(sl<GameRepository>())..start(),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeStateData>(
        builder: (context, themeState) {
          final palette = AppPalettes.of(themeState.selected);
          return MaterialApp(
            title: 'ColorZen',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: palette.background,
              colorScheme: ColorScheme.dark(
                primary: palette.accentPrimary,
                secondary: palette.accentSecondary,
                surface: palette.surface,
              ),
            ),
            home: const SplashScreen(),
            builder: (context, child) {
              return MusicBootstrap(child: child ?? const SizedBox.shrink());
            },
          );
        },
      ),
    );
  }
}
