import 'package:flutter/material.dart';

/// Expanded piece shape library — singles, small, medium, large.
const List<List<List<bool>>> kPieceShapes = [
  // 0 — Monomino (single)
  [
    [true]
  ],
  // 1-2 — Dominoes
  [
    [true, true]
  ],
  [
    [true],
    [true]
  ],
  // 3-8 — Trominoes / small L
  [
    [true, true, true]
  ],
  [
    [true],
    [true],
    [true]
  ],
  [
    [true, false],
    [true, true]
  ],
  [
    [false, true],
    [true, true]
  ],
  [
    [true, true],
    [true, false]
  ],
  [
    [true, true],
    [false, true]
  ],
  // 9-19 — Tetrominoes + variants
  [
    [true, true, true, true]
  ],
  [
    [true],
    [true],
    [true],
    [true]
  ],
  [
    [true, true],
    [true, true]
  ],
  [
    [true, true, true],
    [false, true, false]
  ],
  [
    [false, true],
    [true, true],
    [false, true]
  ],
  [
    [true, false],
    [true, false],
    [true, true]
  ],
  [
    [false, true],
    [false, true],
    [true, true]
  ],
  [
    [true, true],
    [true, false],
    [true, false]
  ],
  [
    [true, true],
    [false, true],
    [false, true]
  ],
  [
    [false, true, true],
    [true, true, false]
  ],
  [
    [true, true, false],
    [false, true, true]
  ],
  // 20-28 — Medium / large
  [
    [false, true, false],
    [true, true, true],
    [false, true, false]
  ],
  [
    [true, true, true],
    [true, false, true]
  ],
  [
    [true, false, true],
    [true, true, true]
  ],
  // 23 — 2×3 hexomino (6)
  [
    [true, true, true],
    [true, true, true]
  ],
  [
    [true, false],
    [true, false],
    [true, false],
    [true, true]
  ],
  [
    [false, true],
    [false, true],
    [false, true],
    [true, true]
  ],
  [
    [true, true, true, true, true]
  ],
  [
    [true],
    [true],
    [true],
    [true],
    [true]
  ],
  [
    [true, true, true],
    [true, true, true],
    [true, true, true]
  ],
  // 29 — 3×2 hexomino (6)
  [
    [true, true],
    [true, true],
    [true, true]
  ],
  // 30 — straight hexomino (6)
  [
    [true, true, true, true, true, true]
  ],
  // 31 — vertical straight hexomino (6)
  [
    [true],
    [true],
    [true],
    [true],
    [true],
    [true]
  ],
  // 32 — 2×4 rectangle
  [
    [true, true, true, true],
    [true, true, true, true]
  ],
  // 33 — 4×2 rectangle
  [
    [true, true],
    [true, true],
    [true, true],
    [true, true]
  ],
  // 34 — 4×4 square
  [
    [true, true, true, true],
    [true, true, true, true],
    [true, true, true, true],
    [true, true, true, true]
  ],
];

/// Weights aligned 1:1 with [kPieceShapes].
/// Fat rectangles (2×2 / 2×3 / 3×2 / 3×3 / 2×4 / 4×2 / 4×4) stay in the mix;
/// 1-block is rare; L/T/I still appear between them.
const List<int> kShapeWeights = [
  8, // 0 single — rare, not gone
  26, 14, // 1–2 dominoes
  22, 12, 20, 20, 20, 20, // 3–8 tromino / small L
  24, 10, 36, 18, 14, 16, 16, 16, 16, 18, 18, // 9–19 tetrominoes (11=2×2)
  8, 8, 8, // 20–22
  34, // 23 2×3
  6, 6, 10, 8, 32, // 24–27, 28=3×3
  30, 12, 6, // 29 3×2, 30 H-I6, 31 V-I6
  28, 24, 22, // 32 2×4, 33 4×2, 34 4×4
];

extension ColorBrightness on Color {
  Color lighten([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color darken([double amount = 0.1]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
