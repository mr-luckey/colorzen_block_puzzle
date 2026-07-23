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
];

/// Weights aligned 1:1 with [kPieceShapes]. Singles/small are boosted.
const List<int> kShapeWeights = [
  70, // 0 single
  48, 48, // 1-2
  36, 36, 36, 36, 36, 36, // 3-8
  28, 28, 30, 28, 28, 26, 26, 26, 26, 26, 26, // 9-19
  18, 18, 18, 16, 14, 14, 12, 12, 8, // 20-28
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
