import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_visuals.dart';

/// Board bomb cell — self-ticking countdown (no parent setState).
class BombCell extends StatefulWidget {
  const BombCell({
    super.key,
    required this.size,
    required this.bomb,
    required this.palette,
  });

  final double size;
  final TimeBomb bomb;
  final ColorPalette palette;

  @override
  State<BombCell> createState() => _BombCellState();
}

class _BombCellState extends State<BombCell>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _secs = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _tick();
    _ticker = createTicker((_) => _tick())..start();
  }

  @override
  void didUpdateWidget(covariant BombCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bomb.expiresAtMs != widget.bomb.expiresAtMs) {
      _tick();
    }
  }

  void _tick() {
    final next = (widget.bomb.remainingMs() / 1000)
        .ceil()
        .clamp(0, AppConstants.bombDurationSec);
    if (_secs.value != next) _secs.value = next;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _secs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _secs,
      builder: (context, secs, _) {
        final progress = (widget.bomb.remainingMs() /
                (AppConstants.bombDurationSec * 1000))
            .clamp(0.0, 1.0);
        final urgent = secs <= 5;
        final mega = widget.bomb.kind == BombKind.combo;
        final s = widget.size.clamp(0.0, 1000.0);
        final ring = mega
            ? (urgent ? const Color(0xFFE040FB) : const Color(0xFF7C4DFF))
            : (urgent ? const Color(0xFFFF1744) : const Color(0xFFD50000));
        // Dark bases — never yellow/orange (emoji contrast).
        final glassBase = mega
            ? const Color(0xFF4527A0)
            : const Color(0xFFB71C1C);

        return SizedBox(
          width: s,
          height: s,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            children: [
              BlockVisuals.glassBlock(
                size: s,
                base: glassBase,
                emoji: BlockVisuals.bombEmoji,
                showEmoji: false,
              ),
              CustomPaint(
                size: Size(s * 0.9, s * 0.9),
                painter: _BombRingPainter(
                  progress: progress,
                  color: ring,
                  track: Colors.white.withValues(alpha: 0.28),
                  stroke: mega ? 2.2 : 1.8,
                ),
              ),
              // Emoji + timer fitted inside cell — no Column overflow.
              Padding(
                padding: EdgeInsets.all(s * 0.06),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BeatingBombEmoji(
                        size: s * 0.55,
                        mega: mega,
                        urgent: urgent,
                      ),
                      Text(
                        '$secs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          height: 1,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BombRingPainter extends CustomPainter {
  _BombRingPainter({
    required this.progress,
    required this.color,
    required this.track,
    this.stroke = 2.5,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 1.5;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BombRingPainter old) =>
      old.progress != progress || old.color != color || old.stroke != stroke;
}

/// Full-board nuke celebration overlay.
class BoardNukeOverlay extends StatelessWidget {
  const BoardNukeOverlay({
    super.key,
    required this.palette,
    required this.bonus,
  });

  final ColorPalette palette;
  final int bonus;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.white.withValues(alpha: 0.12))
              .animate()
              .fadeIn(duration: 80.ms)
              .then()
              .fadeOut(duration: 500.ms),
          ...List.generate(24, (i) {
            final angle = (i / 24) * math.pi * 2;
            final dist = 60.0 + (i % 5) * 28;
            final color = [
              const Color(0xFF7C4DFF),
              const Color(0xFFE040FB),
              const Color(0xFFFF1744),
              palette.accentPrimary,
              Colors.white,
            ][i % 5];
            return Align(
              child: Transform.translate(
                offset: Offset(
                  math.cos(angle) * 8,
                  math.sin(angle) * 8,
                ),
                child: Container(
                  width: 10 + (i % 3) * 4,
                  height: 10 + (i % 3) * 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .move(
                      begin: Offset.zero,
                      end: Offset(
                        math.cos(angle) * dist,
                        math.sin(angle) * dist,
                      ),
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeOut(delay: 350.ms, duration: 500.ms)
                    .rotate(begin: 0, end: 1.2),
              ),
            );
          }),
          Align(
            alignment: const Alignment(0, -0.2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BOARD CLEAR!',
                  style: AppTextStyles.praise(const Color(0xFFE040FB)).copyWith(
                    fontSize: 34,
                    shadows: [
                      Shadow(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.9),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.4, 0.4),
                      end: const Offset(1.12, 1.12),
                      duration: 380.ms,
                      curve: Curves.easeOutBack,
                    )
                    .then()
                    .scale(
                      begin: const Offset(1.12, 1.12),
                      end: const Offset(1, 1),
                      duration: 140.ms,
                    )
                    .then(delay: 700.ms)
                    .fadeOut(duration: 300.ms),
                if (bonus > 0)
                  Text(
                    '+$bonus',
                    style: AppTextStyles.score(Colors.white).copyWith(
                      fontSize: 28,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 120.ms)
                      .moveY(begin: 12, end: -20, duration: 900.ms)
                      .fadeOut(delay: 500.ms, duration: 350.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BombArmedBanner extends StatelessWidget {
  const BombArmedBanner({
    super.key,
    required this.palette,
    this.kind = BombKind.conveyor,
  });

  final ColorPalette palette;
  final BombKind kind;

  @override
  Widget build(BuildContext context) {
    final isCombo = kind == BombKind.combo;
    final label = isCombo
        ? 'MEGA BOMB · ${AppConstants.bombDurationSec}s'
        : 'AREA BOMB · ${AppConstants.bombDurationSec}s';
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.72),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: isCombo
                  ? const [Color(0xFF7C4DFF), Color(0xFF4527A0)]
                  : const [Color(0xFFD50000), Color(0xFFB71C1C)],
            ),
            border: Border.all(color: Colors.white70, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF1744).withValues(alpha: 0.55),
                blurRadius: 18,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCombo
                    ? Icons.flash_on_rounded
                    : Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.section(Colors.white),
              ),
            ],
          ),
        )
            .animate()
            .slideY(
              begin: -0.4,
              end: 0,
              duration: 320.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 200.ms)
            .then(delay: 1400.ms)
            .fadeOut(duration: 280.ms),
      ),
    );
  }
}
