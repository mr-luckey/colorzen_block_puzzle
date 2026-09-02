import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/bloc/game/game_bloc.dart';

/// Compact survive clock — sits on the board; last 10s heartbeat + red.
class SurviveTimerHud extends StatelessWidget {
  const SurviveTimerHud({super.key, required this.palette});

  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<GameBloc, GameState, int>(
      selector: (state) =>
          state is GamePlaying ? state.surviveRemainingMs : -1,
      builder: (context, remainingMs) {
        if (remainingMs < 0) return const SizedBox.shrink();
        return _SurviveTimerBadge(
          remainingMs: remainingMs,
          palette: palette,
        );
      },
    );
  }
}

class _SurviveTimerBadge extends StatefulWidget {
  const _SurviveTimerBadge({
    required this.remainingMs,
    required this.palette,
  });

  final int remainingMs;
  final ColorPalette palette;

  @override
  State<_SurviveTimerBadge> createState() => _SurviveTimerBadgeState();
}

class _SurviveTimerBadgeState extends State<_SurviveTimerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pump;

  bool get _urgent =>
      widget.remainingMs <= AppConstants.surviveWarningSec * 1000;

  @override
  void initState() {
    super.initState();
    _pump = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    if (_urgent) _pump.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SurviveTimerBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasUrgent =
        oldWidget.remainingMs <= AppConstants.surviveWarningSec * 1000;
    if (_urgent && !wasUrgent) {
      _pump.repeat(reverse: true);
    } else if (!_urgent && wasUrgent) {
      _pump
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ms = widget.remainingMs;
    final sec = (ms / 1000).ceil().clamp(0, AppConstants.surviveTimerSec);
    final progress =
        (ms / (AppConstants.surviveTimerSec * 1000)).clamp(0.0, 1.0);
    final accent = _urgent
        ? widget.palette.invalidRed
        : widget.palette.accentSecondary;
    final label =
        '0:${sec.toString().padLeft(2, '0')}';

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: widget.palette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: _urgent ? 0.95 : 0.55),
          width: _urgent ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: _urgent ? 0.55 : 0.28),
            blurRadius: _urgent ? 18 : 10,
            spreadRadius: _urgent ? 1 : 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress,
                color: accent,
                track: accent.withValues(alpha: 0.22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.countdown(accent).copyWith(
              fontSize: _urgent ? 20 : 18,
              height: 1,
              shadows: _urgent
                  ? [
                      Shadow(
                        color: accent.withValues(alpha: 0.7),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
          ),
        ],
      ),
    );

    if (!_urgent) {
      return badge;
    }

    return AnimatedBuilder(
      animation: _pump,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pump.value);
        final scale = 1.0 + 0.14 * t;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: badge,
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
