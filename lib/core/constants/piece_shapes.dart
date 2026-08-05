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
];

/// Weights aligned 1:1 with [kPieceShapes].
/// Wide / flat pieces boosted; tall / height pieces kept rare.
const List<int> kShapeWeights = [
  12, // 0 single
  90, 8, // 1 horizontal ── / 2 vertical │ (rare)
  40, 8, 28, 28, 28, 28, // 3 H-tromino, 4 V rare, 5-8 L
  72, 8, 100, 45, 20, 30, 30, 30, 30, 40, 40, // 9 H-I4, 10 V rare, 11=2×2 top
  6, 6, 6, // 20-22
  110, // 23 → 2×3 horizontal (top priority)
  5, 5, 3, 3, 1, // 24-28
  6, 70, 5, // 29 tall 3×2 rare, 30 H-I6, 31 V-I6 rare
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
