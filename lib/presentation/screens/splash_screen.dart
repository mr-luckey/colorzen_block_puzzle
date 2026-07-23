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
    Future<void>.delayed(1600.ms, () async {
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
      // After home is visible, kick BGM again (Android audio focus).
      Future<void>.delayed(300.ms, () {
        sl<AudioService>().ensureMusicPlaying();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalettes.of(context.watch<ThemeCubit>().state.selected);
    return Scaffold(
      body: WoodBackground(
        palette: palette,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final c = palette.blocks[i % palette.blocks.length];
                  return Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(c, Colors.white, 0.35)!,
                          c,
                          Color.lerp(c, Colors.black, 0.2)!,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.55),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  )
                      .animate(delay: (80 * i).ms)
                      .fadeIn()
                      .scale(begin: const Offset(0.4, 0.4));
                }),
              ),
              const SizedBox(height: 28),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    palette.accentPrimary,
                    palette.accentSecondary,
                  ],
                ).createShader(bounds),
                child: Text(
                  AppConstants.appName.toUpperCase(),
                  style: AppTextStyles.logo(Colors.white),
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 10),
              Text(
                AppConstants.tagline,
                style: AppTextStyles.tagline(palette.textSecondary),
              ).animate(delay: 500.ms).fadeIn(),
              const SizedBox(height: 36),
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: palette.surface,
                    color: palette.accentPrimary,
                  ),
                ),
              ).animate(delay: 400.ms).fadeIn(),
            ],
          ),
        ),
      ),
    );
  }
}
