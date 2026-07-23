import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/core/theme/app_theme.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

abstract class ShareService {
  Future<void> shareDailyResult({
    required GameSession session,
    required GlobalKey repaintKey,
  });
}

class SharePlusService implements ShareService {
  static const _emoji = ['🟥', '🟨', '🟩', '🟦', '🟪', '🟧'];

  @override
  Future<void> shareDailyResult({
    required GameSession session,
    required GlobalKey repaintKey,
  }) async {
    final boundary = repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      await Share.share(_textCard(session));
      return;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      await Share.share(_textCard(session));
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/colorzen_daily.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    await Share.shareXFiles(
      [XFile(file.path)],
      text: _textCard(session),
    );
  }

  String _textCard(GameSession session) {
    final date = DateFormat('MMMM d, yyyy').format(DateTime.now());
    final buffer = StringBuffer()
      ..writeln('${AppConstants.appName}')
      ..writeln('Daily Challenge — $date')
      ..writeln('Score: ${session.score}')
      ..writeln()
      ..writeln(_emojiGrid(session.grid))
      ..writeln()
      ..writeln(AppConstants.tagline);
    return buffer.toString();
  }

  String _emojiGrid(List<List<BlockColor?>> grid) {
    final start = 2;
    final lines = <String>[];
    for (var r = start; r < start + 5; r++) {
      final row = StringBuffer();
      for (var c = start; c < start + 5; c++) {
        final cell = grid[r][c];
        row.write(cell == null ? '⬛' : _emoji[cell.index % _emoji.length]);
      }
      lines.add(row.toString());
    }
    return lines.join('\n');
  }
}

class ShareCardPainter {
  static Widget buildCard({
    required GameSession session,
    required ColorPalette palette,
  }) {
    final date = DateFormat('MMMM d, yyyy').format(DateTime.now());
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.accentPrimary.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppConstants.appName, style: AppTextStyles.logo(palette.accentPrimary)),
          const SizedBox(height: 8),
          Text(
            'Daily Challenge — $date',
            style: AppTextStyles.body(palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat('#,###').format(session.score),
            style: AppTextStyles.score(palette.textPrimary),
          ),
          const SizedBox(height: 16),
          _MiniGrid(grid: session.grid, palette: palette),
          const SizedBox(height: 16),
          Text(
            AppConstants.tagline,
            style: AppTextStyles.tagline(palette.accentSecondary),
          ),
        ],
      ),
    );
  }
}

class _MiniGrid extends StatelessWidget {
  const _MiniGrid({required this.grid, required this.palette});

  final List<List<BlockColor?>> grid;
  final ColorPalette palette;

  @override
  Widget build(BuildContext context) {
    const start = 2;
    return Column(
      children: List.generate(5, (r) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (c) {
            final cell = grid[start + r][start + c];
            return Container(
              width: 18,
              height: 18,
              margin: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: cell == null
                    ? palette.cellEmpty
                    : palette.blockColor(cell),
              ),
            );
          }),
        );
      }),
    );
  }
}
