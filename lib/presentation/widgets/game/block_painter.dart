import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/presentation/widgets/game/block_visuals.dart';

/// Canvas twin of [BlockVisuals.glassBlock] — one layer, no widget tree.
/// Same gradients / emoji / 3D depth so the board and drag sprite match.
class BlockPainter {
  BlockPainter._();

  static final Map<String, TextPainter> _emoji = {};

  static TextPainter _emojiPainter(String emoji, double side) {
    final key = '$emoji:${side.toStringAsFixed(1)}';
    final cached = _emoji[key];
    if (cached != null) return cached;
    // Cap cache so cell-size changes don't leak painters.
    if (_emoji.length > 48) {
      _emoji.remove(_emoji.keys.first);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(
          fontSize: side,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
          shadows: [
            Shadow(
              color: Colors.black54,
              blurRadius: side > 20 ? 3 : 1.5,
              offset: const Offset(0, 0.5),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    _emoji[key] = tp;
    return tp;
  }

  static void paintEmptyCell(
    Canvas canvas,
    Rect rect,
    Color cellEmpty,
  ) {
    final radius = Radius.circular(rect.width * 0.2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.drawRRect(
      rrect,
      Paint()..color = cellEmpty.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08),
    );
  }

  static void paintGlassBlock(
    Canvas canvas,
    Rect rect,
    Color base, {
    String? emoji,
    bool elevated = false,
    bool showEmoji = true,
  }) {
    final s = rect.width;
    if (s <= 0) return;
    final radius = Radius.circular(s * 0.22);
    final depth = s < 22 ? s * 0.04 : (elevated ? s * 0.1 : s * 0.06);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    // Cheap contact shadow — no MaskFilter (saveLayer) so low-end stays smooth.
    final shadowAlpha = elevated ? 0.45 : 0.28;
    final shadowDy = elevated ? 5.0 : 2.0;
    canvas.drawRRect(
      rrect.shift(Offset(0, shadowDy)),
      Paint()..color = Colors.black.withValues(alpha: shadowAlpha * 0.7),
    );

    if (depth > 0.5) {
      final depthRect = Rect.fromLTRB(
        rect.left,
        rect.top + depth * 0.4,
        rect.right,
        rect.bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(depthRect, radius),
        Paint()..color = Color.lerp(base, Colors.black, 0.55)!,
      );
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, Colors.white, 0.28)!,
            base,
            Color.lerp(base, Colors.black, 0.32)!,
            Color.lerp(base, Colors.black, 0.48)!,
          ],
          stops: const [0.0, 0.38, 0.78, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rrect);
    if (s >= 18) {
      final left = Rect.fromLTWH(rect.left, rect.top, s * 0.12, s);
      canvas.drawRect(
        left,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.3),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(left),
      );
      final top = Rect.fromLTWH(rect.left, rect.top, s, s * 0.35);
      canvas.drawRect(
        top,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.32),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(top),
      );
    }

    if (showEmoji && emoji != null && emoji.isNotEmpty) {
      final emojiBox = s * (s < 22 ? 0.72 : 0.82);
      final badgeR = emojiBox * 0.5;
      canvas.drawCircle(
        rect.center,
        badgeR,
        Paint()..color = Colors.black.withValues(alpha: 0.22),
      );
      final tp = _emojiPainter(emoji, emojiBox * 0.92);
      tp.paint(
        canvas,
        rect.center - Offset(tp.width / 2, tp.height / 2),
      );
    }
    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s < 22 ? 0.8 : 1.2
        ..color = Colors.white.withValues(alpha: 0.42),
    );
  }

  static Size pieceSize(Piece piece, double cell, double gap) {
    return Size(
      piece.cols * cell + (piece.cols - 1) * gap,
      piece.rows * cell + (piece.rows - 1) * gap,
    );
  }

  static void paintPiece(
    Canvas canvas, {
    required Piece piece,
    required ColorPalette palette,
    required double cell,
    required double gap,
    bool elevated = false,
  }) {
    final base = palette.blockColor(piece.color);
    final emoji = BlockVisuals.emojiFor(piece.color);
    final bombLocal = piece.isBomb ? piece.occupiedCells.first : null;
    final stride = cell + gap;

    for (var r = 0; r < piece.rows; r++) {
      for (var c = 0; c < piece.cols; c++) {
        if (!piece.shape[r][c]) continue;
        final rect = Rect.fromLTWH(c * stride, r * stride, cell, cell);
        final isBomb = bombLocal != null &&
            bombLocal.$1 == r &&
            bombLocal.$2 == c;
        paintGlassBlock(
          canvas,
          rect,
          isBomb ? const Color(0xFFB71C1C) : base,
          emoji: isBomb ? BlockVisuals.bombEmoji : emoji,
          elevated: elevated,
        );
      }
    }
  }

  /// Record a GPU-friendly picture once; drag just translates it every frame.
  static ui.Picture recordPiece({
    required Piece piece,
    required ColorPalette palette,
    required double cell,
    required double gap,
    bool elevated = true,
  }) {
    final size = pieceSize(piece, cell, gap);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paintPiece(
      canvas,
      piece: piece,
      palette: palette,
      cell: cell,
      gap: gap,
      elevated: elevated,
    );
    // Touch the recorded size so the picture's cull rect is tight.
    canvas.drawRect(
      Rect.fromLTWH(size.width - 0.01, size.height - 0.01, 0.01, 0.01),
      Paint()..color = const Color(0x00000000),
    );
    return recorder.endRecording();
  }

  static void paintBoard(
    Canvas canvas, {
    required List<List<BlockColor?>> grid,
    required ColorPalette palette,
    required double cell,
    required double gap,
    int? skipBombRow,
    int? skipBombCol,
  }) {
    final stride = cell + gap;
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final rect = Rect.fromLTWH(c * stride, r * stride, cell, cell);
        if (skipBombRow == r && skipBombCol == c && grid[r][c] != null) {
          continue;
        }
        final color = grid[r][c];
        if (color == null) {
          paintEmptyCell(canvas, rect, palette.cellEmpty);
        } else {
          paintGlassBlock(
            canvas,
            rect,
            palette.blockColor(color),
            emoji: BlockVisuals.emojiFor(color),
          );
        }
      }
    }
  }
}
