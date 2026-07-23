import 'package:flutter_test/flutter_test.dart';

import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/score_calculator.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

void main() {
  group('GameEngine', () {
    test('places piece on empty grid', () {
      final grid = GameSession.emptyGrid();
      const piece = Piece(
        shape: [
          [true, true],
        ],
        color: BlockColor.color0,
        shapeIndex: 1,
      );
      expect(GameEngine.canPlace(grid, piece, 0, 0), isTrue);
      final next = GameEngine.place(grid, piece, 0, 0);
      expect(next[0][0], BlockColor.color0);
      expect(next[0][1], BlockColor.color0);
      expect(next[0][2], isNull);
    });

    test('rejects occupied cell', () {
      var grid = GameSession.emptyGrid();
      grid[0][0] = BlockColor.color1;
      const piece = Piece(
        shape: [
          [true],
        ],
        color: BlockColor.color0,
        shapeIndex: 0,
      );
      expect(GameEngine.canPlace(grid, piece, 0, 0), isFalse);
    });
  });

  group('LineClearEngine', () {
    test('clears a full row', () {
      final grid = GameSession.emptyGrid();
      for (var c = 0; c < 9; c++) {
        grid[0][c] = BlockColor.color0;
      }
      final result = LineClearEngine().detectAndClear(grid);
      expect(result.clearedRows, [0]);
      expect(result.linesCleared, 1);
      expect(grid[0].every((c) => c == null), isFalse); // original unchanged
      expect(result.grid[0].every((c) => c == null), isTrue);
    });
  });

  group('ScoreCalculator', () {
    test('1 line no bonus', () {
      expect(
        ScoreCalculator.calculate(
          linesCleared: 1,
          colorBonusFlags: [false],
          consecutiveClearMovesAfter: 1,
          scoringEnabled: true,
        ),
        100,
      );
    });

    test('2 lines both color bonus', () {
      expect(
        ScoreCalculator.calculate(
          linesCleared: 2,
          colorBonusFlags: [true, true],
          consecutiveClearMovesAfter: 1,
          scoringEnabled: true,
        ),
        500,
      );
    });

    test('zen disables scoring', () {
      expect(
        ScoreCalculator.calculate(
          linesCleared: 3,
          colorBonusFlags: [false, false, false],
          consecutiveClearMovesAfter: 5,
          scoringEnabled: false,
        ),
        0,
      );
    });
  });
}
