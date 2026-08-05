import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/di/injection.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/theme/theme_cubit.dart';
import 'package:colorzen_block_puzzle/presentation/screens/home_screen.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Short branded beat only — ads bootstrap happens on Home, not here.
    Future<void>.delayed(700.ms, () async {
      await sl<AudioService>().ensureMusicPlaying();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: 400.ms,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
      Future<void>.delayed(300.ms, () {
        sl<AudioService>().ensureMusicPlaying();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);
    final logoSide =
        (MediaQuery.sizeOf(context).shortestSide * 0.58).clamp(220.0, 300.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // No fadeIn — logo must be visible immediately (native → Flutter handoff).
            Image.asset(
              AppConstants.appLogoAsset,
              width: logoSide,
              height: logoSide,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Icon(
                Icons.grid_view_rounded,
                size: logoSide * 0.4,
                color: palette.accentPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppConstants.tagline,
              style: AppTextStyles.tagline(palette.textSecondary),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Colors.white12,
                  color: palette.accentPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
