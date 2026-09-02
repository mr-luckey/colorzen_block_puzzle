import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/core/constants/app_constants.dart';
import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/engines/game_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/line_clear_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/piece_generator.dart';
import 'package:colorzen_block_puzzle/domain/engines/ranking_engine.dart';
import 'package:colorzen_block_puzzle/domain/engines/score_calculator.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';
import 'package:colorzen_block_puzzle/services/audio_service.dart';
import 'package:colorzen_block_puzzle/services/haptic_service.dart';
import 'package:uuid/uuid.dart';

// ── Events ──────────────────────────────────────────────────────────

sealed class GameEvent extends Equatable {
  const GameEvent();
  @override
  List<Object?> get props => [];
}

class GameStarted extends GameEvent {
  const GameStarted(this.mode, {this.forceNew = false});
  final GameMode mode;
  final bool forceNew;
  @override
  List<Object?> get props => [mode, forceNew];
}

class PiecePlaced extends GameEvent {
  const PiecePlaced({
    required this.pieceId,
    required this.row,
    required this.col,
  });
  final int pieceId;
  final int row;
  final int col;
  @override
  List<Object?> get props => [pieceId, row, col];
}

class GameReset extends GameEvent {
  const GameReset();
}

class GamePaused extends GameEvent {
  const GamePaused();
}

class GameResumed extends GameEvent {
  const GameResumed();
}

class BombExpired extends GameEvent {
  const BombExpired();
}

class ConveyorRecycled extends GameEvent {
  const ConveyorRecycled({required this.newPiece});
  final Piece newPiece;
  @override
  List<Object?> get props => [newPiece];
}

class SanitizeBelt extends GameEvent {
  const SanitizeBelt();
}

class SurviveClockTicked extends GameEvent {
  const SurviveClockTicked();
}

class SurviveExtraTimeGranted extends GameEvent {
  const SurviveExtraTimeGranted();
}

class SurviveGiveUp extends GameEvent {
  const SurviveGiveUp();
}

// ── States ──────────────────────────────────────────────────────────

sealed class GameState extends Equatable {
  const GameState();
  @override
  List<Object?> get props => [];
}

class GameInitial extends GameState {
  const GameInitial();
}

class GameLoading extends GameState {
  const GameLoading();
}

class GamePlaying extends GameState {
  const GamePlaying(
    this.session, {
    this.lastScoreGained = 0,
    this.clearedRows = const [],
    this.clearedCols = const [],
    this.hadColorBonus = false,
    this.showCombo = false,
    this.placementAnimCells = const [],
    this.blastCells = const [],
    this.clearFxColors = const {},
    this.praise = MovePraise.none,
    this.bombSpawned = false,
    this.boardNuked = false,
    this.bombDefused = false,
    this.allClear = false,
    this.linesJustCleared = 0,
    this.surviveRemainingMs = 0,
  });

  final GameSession session;
  final int lastScoreGained;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final bool hadColorBonus;
  final bool showCombo;
  final List<(int, int)> placementAnimCells;
  /// Cells removed by a conveyor bomb area blast.
  final List<(int, int)> blastCells;
  /// Colors to paint during clear/blast anim (grid is already emptied).
  final Map<(int, int), BlockColor> clearFxColors;
  final MovePraise praise;
  final bool bombSpawned;
  final bool boardNuked;
  final bool bombDefused;
  /// True when the board has zero blocks left after this move.
  final bool allClear;
  /// Rows+cols popped this move (for 4 / 6 / 9 callouts).
  final int linesJustCleared;

  /// Line-clear survive clock (HUD only — parent buildWhen ignores this).
  final int surviveRemainingMs;

  GamePlaying copyWith({
    GameSession? session,
    int? lastScoreGained,
    List<int>? clearedRows,
    List<int>? clearedCols,
    bool? hadColorBonus,
    bool? showCombo,
    List<(int, int)>? placementAnimCells,
    List<(int, int)>? blastCells,
    Map<(int, int), BlockColor>? clearFxColors,
    MovePraise? praise,
    bool? bombSpawned,
    bool? boardNuked,
    bool? bombDefused,
    bool? allClear,
    int? linesJustCleared,
    int? surviveRemainingMs,
  }) {
    return GamePlaying(
      session ?? this.session,
      lastScoreGained: lastScoreGained ?? this.lastScoreGained,
      clearedRows: clearedRows ?? this.clearedRows,
      clearedCols: clearedCols ?? this.clearedCols,
      hadColorBonus: hadColorBonus ?? this.hadColorBonus,
      showCombo: showCombo ?? this.showCombo,
      placementAnimCells: placementAnimCells ?? this.placementAnimCells,
      blastCells: blastCells ?? this.blastCells,
      clearFxColors: clearFxColors ?? this.clearFxColors,
      praise: praise ?? this.praise,
      bombSpawned: bombSpawned ?? this.bombSpawned,
      boardNuked: boardNuked ?? this.boardNuked,
      bombDefused: bombDefused ?? this.bombDefused,
      allClear: allClear ?? this.allClear,
      linesJustCleared: linesJustCleared ?? this.linesJustCleared,
      surviveRemainingMs: surviveRemainingMs ?? this.surviveRemainingMs,
    );
  }

  @override
  List<Object?> get props => [
        session,
        lastScoreGained,
        clearedRows,
        clearedCols,
        hadColorBonus,
        showCombo,
        placementAnimCells,
        blastCells,
        clearFxColors,
        praise,
        bombSpawned,
        boardNuked,
        bombDefused,
        allClear,
        linesJustCleared,
        surviveRemainingMs,
      ];
}

class GameTimeUpState extends GameState {
  const GameTimeUpState(this.session, {required this.isNewBest});
  final GameSession session;
  final bool isNewBest;
  @override
  List<Object?> get props => [session, isNewBest];
}

class GameOverState extends GameState {
  const GameOverState(this.session, {required this.isNewBest});
  final GameSession session;
  final bool isNewBest;
  @override
  List<Object?> get props => [session, isNewBest];
}

// ── Bloc ────────────────────────────────────────────────────────────

class GameBloc extends Bloc<GameEvent, GameState> {
  GameBloc({
    required GameRepository repo,
    required PieceGenerator pieceGen,
    required LineClearEngine clearEngine,
    required HapticService haptics,
    required AudioService audio,
    required Future<void> Function(ThemeStateData) onThemeMaybeUnlock,
    required Future<ThemeStateData> Function() loadTheme,
  })  : _repo = repo,
        _pieceGen = pieceGen,
        _clearEngine = clearEngine,
        _haptics = haptics,
        _audio = audio,
        _onThemeMaybeUnlock = onThemeMaybeUnlock,
        _loadTheme = loadTheme,
        super(const GameInitial()) {
    on<GameStarted>(_onStarted);
    on<PiecePlaced>(_onPiecePlaced);
    on<GameReset>(_onReset);
    on<GamePaused>(_onPaused);
    on<GameResumed>(_onResumed);
    on<BombExpired>(_onBombExpired);
    on<ConveyorRecycled>(_onConveyorRecycled);
    on<SanitizeBelt>(_onSanitizeBelt);
    on<SurviveClockTicked>(_onSurviveClockTicked);
    on<SurviveExtraTimeGranted>(_onSurviveExtraTimeGranted);
    on<SurviveGiveUp>(_onSurviveGiveUp);
  }

  final GameRepository _repo;
  final PieceGenerator _pieceGen;
  final LineClearEngine _clearEngine;
  final HapticService _haptics;
  final AudioService _audio;
  final Future<void> Function(ThemeStateData) _onThemeMaybeUnlock;
  final Future<ThemeStateData> Function() _loadTheme;

  GameMode? _mode;

  Timer? _surviveClock;
  int _surviveDeadlineMs = 0;
  int _lastSurviveSec = AppConstants.surviveTimerSec;
  bool _paused = false;
  int _pausedRemainMs = 0;
  int? _pauseStartedMs;

  int _remainMs() {
    final left =
        _surviveDeadlineMs - DateTime.now().millisecondsSinceEpoch;
    return left < 0 ? 0 : left;
  }

  void _armSurvive(int seconds) => _armSurviveMs(seconds * 1000);

  void _armSurviveMs(int ms) {
    if (ms <= 0) {
      _stopSurviveClock();
      return;
    }
    _surviveDeadlineMs = DateTime.now().millisecondsSinceEpoch + ms;
    _lastSurviveSec = (ms / 1000).ceil();
    _surviveClock?.cancel();
    _surviveClock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      add(const SurviveClockTicked());
    });
  }

  void _stopSurviveClock() {
    _surviveClock?.cancel();
    _surviveClock = null;
  }

  GamePlaying _stampClock(GamePlaying playing) {
    if (_paused) {
      return playing.copyWith(
        surviveRemainingMs: _pausedRemainMs > 0
            ? _pausedRemainMs
            : playing.surviveRemainingMs,
      );
    }
    return playing.copyWith(
      surviveRemainingMs: _surviveClock != null
          ? _remainMs()
          : AppConstants.surviveTimerSec * 1000,
    );
  }

  Future<void> _onStarted(
    GameStarted event,
    Emitter<GameState> emit,
  ) async {
    emit(const GameLoading());
    _paused = false;
    _pausedRemainMs = 0;
    _pauseStartedMs = null;
    _stopSurviveClock();
    _mode = event.mode;
    _configureGenerator(event.mode);

    if (event.mode == GameMode.daily) {
      final today = HiveGameRepository.todayKey();
      final daily = await _repo.loadDaily(today);
      if (daily != null && daily.completed && !event.forceNew) {
        // Resume completed — show result via empty session marker
        final stats = await _repo.loadStats();
        final session = GameSession(
          mode: GameMode.daily,
          grid: GameSession.emptyGrid(),
          currentPieces: const [null, null, null],
          nextPieces: const [],
          score: daily.score,
          bestScore: stats.dailyBest,
          linesCleared: 0,
          blocksPlaced: 0,
          comboCount: 0,
          isGameOver: true,
        );
        emit(GameOverState(session, isNewBest: false));
        return;
      }
    }

    // New Game: wipe run progress (score + moves) but keep lifetime best.
    if (event.forceNew) {
      await _repo.clearSession(event.mode);
    }

    GameSession? saved;
    if (!event.forceNew) {
      saved = await _repo.loadSession(event.mode);
      if (saved != null && saved.isGameOver) saved = null;
    }

    final stats = await _repo.loadStats();
    final lifetimeBest = switch (event.mode) {
      GameMode.classic => stats.classicBest,
      GameMode.daily => stats.dailyBest,
      GameMode.zen => 0,
    };

    late final GameSession session;
    if (saved != null) {
      // Fold any leftover run score into lifetime best before resetting.
      final best = [
        lifetimeBest,
        saved.bestScore,
        saved.score,
      ].reduce((a, b) => a > b ? a : b);
      if (event.mode != GameMode.zen && best > lifetimeBest) {
        await _persistLifetimeBest(event.mode, best);
      }

      if (event.mode == GameMode.classic) {
        // Continue: keep board + pieces; score/moves always restart at 0.
        // BEST HUD shows all-time high.
        session = _normalizeBelt(
          saved.copyWith(
            score: 0,
            movesMade: 0,
            bestScore: best,
            comboCount: 0,
            consecutiveClearMoves: 0,
            activeSurviveMs: 0,
            clearLastMove: true,
          ),
        );
      } else {
        // Daily / other: restore full run progress.
        session = _normalizeBelt(saved.copyWith(bestScore: best));
      }
    } else {
      // Fresh run: score + moves start at 0; best shows all-time high.
      session = _normalizeBelt(_createNewSession(event.mode, lifetimeBest));
    }

    await _repo.saveSession(session);
    _stopSurviveClock();
    emit(_stampClock(GamePlaying(session)));
  }

  void _configureGenerator(GameMode mode) {
    if (mode == GameMode.daily) {
      _pieceGen.setSeed(PieceGenerator.seedFromDate(DateTime.now()));
    } else {
      _pieceGen.useSystemRandom();
    }
  }

  GameSession _createNewSession(GameMode mode, int best) {
    var grid = GameSession.emptyGrid();
    // Daily: seeded opening pattern so every player gets the same board start.
    if (mode == GameMode.daily) {
      grid = _dailyOpeningPattern();
    }
    _pieceGen.setBoard(grid);
    _pieceGen.setBoardFillRatio(_countFilled(grid) / 81.0);
    var belt = _pieceGen.generateSet(count: AppConstants.beltSize);
    // Zen: calm endless play — no bombs on the conveyor.
    if (mode == GameMode.zen) {
      belt = belt.map((p) => p.copyWith(isBomb: false)).toList();
    }
    return GameSession(
      mode: mode,
      grid: grid,
      currentPieces: belt,
      nextPieces: const [],
      score: 0,
      bestScore: best,
      linesCleared: 0,
      blocksPlaced: 0,
      comboCount: 0,
      isGameOver: false,
    );
  }

  /// Deterministic starter clutter for today's shared daily puzzle.
  List<List<BlockColor?>> _dailyOpeningPattern() {
    final grid = GameSession.emptyGrid();
    final rng = _pieceGen; // already seeded for today
    // Place ~14 scattered blocks using the same daily stream feel.
    final coords = <(int, int)>[
      (0, 1), (0, 2), (0, 6), (0, 7),
      (2, 0), (2, 4), (2, 8),
      (4, 2), (4, 3), (4, 5), (4, 6),
      (6, 0), (6, 4), (6, 8),
      (8, 1), (8, 2), (8, 6), (8, 7),
    ];
    for (var i = 0; i < coords.length; i++) {
      final (r, c) = coords[i];
      grid[r][c] = BlockColor.values[i % BlockColor.values.length];
    }
    // Touch rng so piece stream stays unique after pattern (consume a few).
    for (var i = 0; i < 3; i++) {
      rng.nextConveyorPiece();
    }
    return grid;
  }

  /// Migrate old 3-slot + next-tray saves into an 8-piece conveyor belt.
  GameSession _normalizeBelt(GameSession session) {
    _pieceGen.setBoard(session.grid);
    _pieceGen.setBoardFillRatio(_countFilled(session.grid) / 81.0);
    final existing = session.currentPieces.whereType<Piece>().toList();
    final fromNext = session.nextPieces;
    var pool = [...existing, ...fromNext];
    final tiny = pool.where((p) => p.blockCount <= 1).length;
    // Old saves were full of 1-blocks — throw the belt out and rebuild.
    if (pool.isEmpty || tiny >= 2) {
      pool = List.generate(
        AppConstants.beltSize,
        (_) => _pieceGen.nextConveyorPiece(),
      );
    } else {
      pool = pool
          .map((p) => p.blockCount <= 1 ? _pieceGen.nextConveyorPiece() : p)
          .toList();
      while (pool.length < AppConstants.beltSize) {
        pool.add(_pieceGen.nextConveyorPiece());
      }
    }
    var belt = pool.take(AppConstants.beltSize).toList();
    if (session.mode == GameMode.zen) {
      belt = belt.map((p) => p.copyWith(isBomb: false)).toList();
    } else if (!belt.any((p) => p.isBomb)) {
      final i = (belt.length / 2).floor().clamp(0, belt.length - 1);
      belt[i] = belt[i].copyWith(isBomb: true);
    }
    return session.copyWith(
      currentPieces: belt,
      nextPieces: const [],
    );
  }

  Future<void> _onPiecePlaced(
    PiecePlaced event,
    Emitter<GameState> emit,
  ) async {
    if (_paused) return;
    final current = state;
    if (current is! GamePlaying) return;
    final session = current.session;
    final trayIndex =
        session.currentPieces.indexWhere((p) => p?.id == event.pieceId);
    if (trayIndex < 0) return;
    final piece = session.currentPieces[trayIndex];
    if (piece == null) return;

    if (!GameEngine.canPlace(
      session.grid,
      piece,
      event.row,
      event.col,
    )) {
      _haptics.invalidShake();
      return;
    }

    _haptics.light();
    final placedGrid = GameEngine.place(
      session.grid,
      piece,
      event.row,
      event.col,
    );
    final placementCells = piece.occupiedCells
        .map((e) => (event.row + e.$1, event.col + e.$2))
        .toList();

    final clearResult = _clearEngine.detectAndClear(placedGrid);
    final lines = clearResult.linesCleared;

    // Snapshot colors for line-clear pop anim (logic grid is already empty).
    final clearFxColors = <(int, int), BlockColor>{};
    for (final r in clearResult.clearedRows) {
      for (var c = 0; c < 9; c++) {
        final color = placedGrid[r][c];
        if (color != null) clearFxColors[(r, c)] = color;
      }
    }
    for (final c in clearResult.clearedCols) {
      for (var r = 0; r < 9; r++) {
        final color = placedGrid[r][c];
        if (color != null) clearFxColors[(r, c)] = color;
      }
    }

    var consecutive = session.consecutiveClearMoves;
    if (lines > 0) {
      consecutive += 1;
      _haptics.medium();
      // Engaging arpeggio on line clear — don't await.
      // ignore: discarded_futures
      _audio.playSfx(SfxType.lineClear);
      if (consecutive >= 3) {
        // ignore: discarded_futures
        _audio.playSfx(SfxType.combo);
      }
    } else {
      consecutive = 0;
    }

    final scoringEnabled = session.mode != GameMode.zen;
    final modeMultiplier = session.mode == GameMode.daily
        ? AppConstants.dailyScoreMultiplier
        : 1.0;
    var gained = ScoreCalculator.calculate(
      linesCleared: lines,
      colorBonusFlags: clearResult.colorBonusFlags,
      consecutiveClearMovesAfter: consecutive,
      scoringEnabled: scoringEnabled,
      modeMultiplier: modeMultiplier,
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final activeMs = RankingEngine.tickActiveSurvive(
      previousActiveMs: session.activeSurviveMs,
      lastMoveEpochMs: session.lastMoveEpochMs,
      nowMs: nowMs,
    );
    final movesMade = session.movesMade + 1;
    final hadColorBonus = clearResult.colorBonusFlags.any((b) => b);

    var workingGrid = clearResult.grid;
    var bomb = session.timeBomb;
    var boardNuked = false;
    var bombDefused = false;
    var bombSpawned = false;
    var blastCells = <(int, int)>[];
    var animRows = List<int>.from(clearResult.clearedRows);
    var animCols = List<int>.from(clearResult.clearedCols);

    // Expire stale bomb if timer already ran out.
    if (bomb != null && bomb.expiresAtMs <= nowMs) {
      bomb = null;
    }

    // Conveyor bomb piece → arm only if no bomb already on the board.
    TimeBomb? placedBomb;
    if (piece.isBomb &&
        session.mode != GameMode.zen &&
        bomb == null) {
      final (br, bc) = placementCells.first;
      placedBomb = TimeBomb(
        row: br,
        col: bc,
        color: piece.color,
        expiresAtMs: nowMs + AppConstants.bombDurationSec * 1000,
        kind: BombKind.conveyor,
      );
    }

    // Defuse ONLY a bomb that was already armed on the board.
    // Never blast on the same move the bomb is first placed — that felt
    // like "put = instant explode" before the player could finish a line.
    final defuseTarget = bomb;
    if (defuseTarget != null &&
        lines > 0 &&
        (clearResult.clearedRows.contains(defuseTarget.row) ||
            clearResult.clearedCols.contains(defuseTarget.col))) {
      bombDefused = true;
      bomb = null;
      placedBomb = null;
      _haptics.heavy();
      // ignore: discarded_futures
      _audio.playSfx(SfxType.blast);
      // ignore: discarded_futures
      _audio.playSfx(SfxType.combo);

      if (defuseTarget.isFullWipe) {
        // Combo bomb → wipe entire board.
        final filled = _countFilled(workingGrid);
        for (var r = 0; r < 9; r++) {
          for (var c = 0; c < 9; c++) {
            final color = workingGrid[r][c];
            if (color != null) clearFxColors[(r, c)] = color;
          }
        }
        workingGrid = GameSession.emptyGrid();
        final nukeBonus = scoringEnabled
            ? AppConstants.bombBoardClearBonus +
                filled * AppConstants.bombPerBlockBonus
            : 0;
        gained += nukeBonus;
        boardNuked = true;
      } else {
        // Conveyor bomb → blast a local square around the bomb cell.
        final preBlast = workingGrid;
        final blast = _applyAreaBlast(
          workingGrid,
          defuseTarget.row,
          defuseTarget.col,
          AppConstants.bombAreaRadius,
        );
        workingGrid = blast.grid;
        blastCells = blast.cells;
        for (final cell in blast.cells) {
          final color = preBlast[cell.$1][cell.$2];
          if (color != null) clearFxColors[cell] = color;
        }
        var areaBonus = scoringEnabled
            ? AppConstants.bombAreaClearBonus +
                blast.removed * AppConstants.bombPerBlockBonus
            : 0;

        // Cascading line clears created by the blast hole.
        final cascade = _clearEngine.detectAndClear(workingGrid);
        if (cascade.linesCleared > 0) {
          for (final r in cascade.clearedRows) {
            for (var c = 0; c < 9; c++) {
              final color = workingGrid[r][c];
              if (color != null) clearFxColors[(r, c)] = color;
            }
          }
          for (final c in cascade.clearedCols) {
            for (var r = 0; r < 9; r++) {
              final color = workingGrid[r][c];
              if (color != null) clearFxColors[(r, c)] = color;
            }
          }
          workingGrid = cascade.grid;
          if (scoringEnabled) {
            areaBonus += ScoreCalculator.calculate(
              linesCleared: cascade.linesCleared,
              colorBonusFlags: cascade.colorBonusFlags,
              consecutiveClearMovesAfter: consecutive,
              scoringEnabled: true,
              modeMultiplier: modeMultiplier,
            );
          }
          // Flash cascaded lines too.
          animRows.addAll(cascade.clearedRows);
          animCols.addAll(cascade.clearedCols);
        }
        gained += areaBonus;
      }
    } else if (placedBomb != null) {
      // Arm timer after put. If this place also cleared the bomb cell via a
      // normal line clear, skip arming (no instant area blast).
      if (workingGrid[placedBomb.row][placedBomb.col] != null) {
        bomb = placedBomb;
        bombSpawned = true;
        _haptics.medium();
        // ignore: discarded_futures
        _audio.playSfx(SfxType.pickup);
      }
    }

    // Drop bomb marker if its cell vanished.
    if (bomb != null && workingGrid[bomb.row][bomb.col] == null) {
      bomb = null;
    }

    // 2+ lines in one move → always arm the mega (full-wipe) fire bomb.
    final uniqueLines = {...animRows}.length + {...animCols}.length;
    if (!bombDefused &&
        session.mode != GameMode.zen &&
        (lines >= 2 || uniqueLines >= 2)) {
      final armed = _spawnComboBomb(workingGrid, nowMs);
      if (armed != null) {
        bomb = armed;
        bombSpawned = true;
        _haptics.medium();
        // ignore: discarded_futures
        _audio.playSfx(SfxType.pickup);
      }
    }

    final calloutLines = boardNuked
        ? 9
        : ({...animRows}.length + {...animCols}.length);
    // Any move that empties a board that had blocks — line clear, combo
    // nuke, or area blast — is an all-clear (bonus + celebration only).
    final emptiedBoard = _countFilled(workingGrid) == 0 &&
        _countFilled(session.grid) > 0;
    final allClear = emptiedBoard;
    if (allClear && scoringEnabled) {
      gained += (AppConstants.allClearBonus * modeMultiplier).round();
    }
    if (allClear) {
      _haptics.heavy();
      // ignore: discarded_futures
      _audio.playSfx(SfxType.combo);
    } else if (calloutLines >= 4) {
      _haptics.heavy();
      if (consecutive < 3) {
        // ignore: discarded_futures
        _audio.playSfx(SfxType.combo);
      }
    }

    var praise = RankingEngine.praiseFor(
      linesCleared: calloutLines > 0 ? calloutLines : lines,
      consecutiveClearMoves: consecutive,
      hadColorBonus: hadColorBonus,
      scoreGained: gained,
      allClear: allClear,
    );
    if (praise == MovePraise.none && blastCells.isNotEmpty) {
      praise = MovePraise.great;
    }

    final newTray = List<Piece?>.from(session.currentPieces);
    // Remove used piece and append a fresh one — infinite conveyor.
    if (trayIndex >= 0 && trayIndex < newTray.length) {
      newTray.removeAt(trayIndex);
    }
    final filledNow = _countFilled(workingGrid);
    _pieceGen.setBoard(workingGrid);
    _pieceGen.setBoardFillRatio(filledNow / 81.0);
    newTray.add(_pieceGen.nextConveyorPiece());
    while (newTray.length < AppConstants.beltSize) {
      newTray.add(_pieceGen.nextConveyorPiece());
    }
    var tray = newTray.take(AppConstants.beltSize).toList();
    if (session.mode == GameMode.zen) {
      tray = tray
          .map((p) => p?.copyWith(isBomb: false))
          .toList();
    }

    final newScore = session.score + gained;
    final newBest = newScore > session.bestScore ? newScore : session.bestScore;
    final comboCount = consecutive >= 3 ? consecutive : 0;

    if (lines >= 1 || allClear || boardNuked) {
      _armSurvive(AppConstants.surviveTimerSec);
    }

    var newSession = session.copyWith(
      grid: workingGrid,
      currentPieces: tray,
      nextPieces: const [],
      score: scoringEnabled ? newScore : session.score,
      bestScore: scoringEnabled ? newBest : session.bestScore,
      linesCleared: session.linesCleared + lines,
      blocksPlaced: session.blocksPlaced + piece.blockCount,
      comboCount: comboCount,
      consecutiveClearMoves: consecutive,
      movesMade: movesMade,
      activeSurviveMs: activeMs,
      lastMoveEpochMs: nowMs,
      isGameOver: false,
      timeBomb: bomb,
      clearBomb: bomb == null,
    );

    final gameOver = GameEngine.isGameOver(
      newSession.grid,
      newSession.currentPieces,
    );

    if (gameOver && session.mode == GameMode.zen) {
      // Silent reset for zen
      final reset = _createNewSession(GameMode.zen, 0);
      await _repo.saveSession(reset);
      _stopSurviveClock();
      emit(_stampClock(GamePlaying(reset)));
      return;
    }

    if (gameOver) {
      newSession = newSession.copyWith(isGameOver: true);
      await _repo.saveSession(newSession);
      await _updateStatsOnGameOver(newSession);
      _haptics.heavy();
      await _audio.playSfx(SfxType.gameOver);
      _stopSurviveClock();

      if (session.mode == GameMode.daily) {
        await _repo.saveDaily(
          DailyChallengeRecord(
            date: HiveGameRepository.todayKey(),
            completed: true,
            score: newSession.score,
          ),
        );
      }

      emit(
        _stampClock(
          GamePlaying(
            newSession,
            lastScoreGained: gained,
            clearedRows: animRows,
            clearedCols: animCols,
            hadColorBonus: hadColorBonus,
            showCombo: consecutive >= 3 && lines > 0,
            placementAnimCells: placementCells,
            blastCells: blastCells,
            clearFxColors: clearFxColors,
            praise: praise,
            bombSpawned: bombSpawned,
            boardNuked: boardNuked,
            bombDefused: bombDefused,
            allClear: allClear,
            linesJustCleared: calloutLines,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 720));
      emit(
        GameOverState(
          newSession,
          isNewBest: newSession.score > session.bestScore &&
              newSession.score > 0,
        ),
      );
      return;
    }

    // Emit clear FX first — persist in background so anim isn't delayed.
    emit(
      _stampClock(
        GamePlaying(
          newSession,
          lastScoreGained: gained,
          clearedRows: boardNuked
              ? List.generate(9, (i) => i)
              : animRows,
          clearedCols: boardNuked
              ? List.generate(9, (i) => i)
              : animCols,
          hadColorBonus: hadColorBonus,
          showCombo: consecutive >= 3 && lines > 0,
          placementAnimCells: placementCells,
          blastCells: blastCells,
          clearFxColors: clearFxColors,
          praise: praise,
          bombSpawned: bombSpawned,
          boardNuked: boardNuked,
          bombDefused: bombDefused,
          allClear: allClear,
          linesJustCleared: calloutLines,
        ),
      ),
    );

    // ignore: discarded_futures
    _repo.saveSession(newSession);
    if (scoringEnabled && newBest > session.bestScore) {
      // ignore: discarded_futures
      _persistLifetimeBest(session.mode, newBest);
    }
    // ignore: discarded_futures
    _maybeUnlockThemes(newSession);

    // Clear line-flash flags after Block-Blast-length FX.
    final settleMoves = movesMade;
    await Future<void>.delayed(const Duration(milliseconds: 720));
    final after = state;
    if (after is GamePlaying &&
        after.session.movesMade == settleMoves &&
        !after.session.isGameOver) {
      emit(_stampClock(GamePlaying(after.session)));
    }
  }

  int _countFilled(List<List<BlockColor?>> grid) {
    var n = 0;
    for (final row in grid) {
      for (final c in row) {
        if (c != null) n++;
      }
    }
    return n;
  }

  /// Combo bomb: convert one remaining filled cell into a full-wipe timer bomb.
  TimeBomb? _spawnComboBomb(List<List<BlockColor?>> grid, int nowMs) {
    final cells = <(int, int, BlockColor)>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        final color = grid[r][c];
        if (color != null) cells.add((r, c, color));
      }
    }
    if (cells.isEmpty) return null;
    cells.shuffle();
    final pick = cells.first;
    return TimeBomb(
      row: pick.$1,
      col: pick.$2,
      color: pick.$3,
      expiresAtMs: nowMs + AppConstants.bombDurationSec * 1000,
      kind: BombKind.combo,
    );
  }

  /// Conveyor bomb blast: clear a square around (row, col).
  ({List<List<BlockColor?>> grid, List<(int, int)> cells, int removed})
      _applyAreaBlast(
    List<List<BlockColor?>> grid,
    int row,
    int col,
    int radius,
  ) {
    final next = List.generate(
      9,
      (r) => List<BlockColor?>.from(grid[r]),
    );
    final blasted = <(int, int)>[];
    var removed = 0;
    for (var r = row - radius; r <= row + radius; r++) {
      for (var c = col - radius; c <= col + radius; c++) {
        if (r < 0 || c < 0 || r >= 9 || c >= 9) continue;
        if (next[r][c] == null) continue;
        next[r][c] = null;
        blasted.add((r, c));
        removed++;
      }
    }
    return (grid: next, cells: blasted, removed: removed);
  }

  Future<void> _onBombExpired(
    BombExpired event,
    Emitter<GameState> emit,
  ) async {
    if (_paused) return;
    final current = state;
    if (current is! GamePlaying) return;
    final bomb = current.session.timeBomb;
    if (bomb == null) return;
    if (!bomb.isExpired) return;
    final next = current.session.copyWith(clearBomb: true);
    await _repo.saveSession(next);
    emit(_stampClock(GamePlaying(next)));
  }

  /// Leftmost piece scrolled off → drop it, append the piece tray already generated.
  Future<void> _onConveyorRecycled(
    ConveyorRecycled event,
    Emitter<GameState> emit,
  ) async {
    if (_paused) return;
    final current = state;
    if (current is! GamePlaying) return;
    final session = current.session;
    if (session.isGameOver) return;
    final tray = List<Piece?>.from(session.currentPieces);
    if (tray.length < 2) return;
    tray.removeAt(0);
    var fresh = event.newPiece;
    if (session.mode == GameMode.zen) {
      fresh = fresh.copyWith(isBomb: false);
    }
    tray.add(fresh);
    while (tray.length < AppConstants.beltSize) {
      tray.add(_pieceGen.nextConveyorPiece());
    }
    final next = session.copyWith(
      currentPieces: tray.take(AppConstants.beltSize).toList(),
      nextPieces: const [],
    );
    emit(_stampClock(GamePlaying(next)));
  }

  Future<void> _onSanitizeBelt(
    SanitizeBelt event,
    Emitter<GameState> emit,
  ) async {
    final current = state;
    if (current is! GamePlaying) return;
    final session = current.session;
    final pieces = session.currentPieces.whereType<Piece>().toList();
    final tiny = pieces.where((p) => p.blockCount <= 1).length;
    if (tiny < 2) return;
    _pieceGen.setBoard(session.grid);
    _pieceGen.setBoardFillRatio(_countFilled(session.grid) / 81.0);
    var belt = List.generate(
      AppConstants.beltSize,
      (_) => _pieceGen.nextConveyorPiece(),
    );
    if (session.mode == GameMode.zen) {
      belt = belt.map((p) => p.copyWith(isBomb: false)).toList();
    }
    final next = session.copyWith(
      currentPieces: belt,
      nextPieces: const [],
    );
    emit(_stampClock(GamePlaying(next)));
    // ignore: discarded_futures
    _repo.saveSession(next);
  }

  Future<void> _maybeUnlockThemes(GameSession session) async {
    if (session.mode != GameMode.classic) return;
    final theme = await _loadTheme();
    final unlocked = List<AppThemeId>.from(theme.unlocked);
    var changed = false;
    if (session.score >= AppConstants.woodlandUnlockScore &&
        !unlocked.contains(AppThemeId.midnightZen)) {
      unlocked.add(AppThemeId.midnightZen);
      changed = true;
    }
    if (session.score >= AppConstants.desiUnlockScore &&
        !unlocked.contains(AppThemeId.desiRangoli)) {
      unlocked.add(AppThemeId.desiRangoli);
      changed = true;
    }
    if (session.score >= AppConstants.arcticUnlockScore &&
        !unlocked.contains(AppThemeId.arcticIce)) {
      unlocked.add(AppThemeId.arcticIce);
      changed = true;
    }
    if (changed) {
      await _onThemeMaybeUnlock(theme.copyWith(unlocked: unlocked));
    }
  }

  Future<void> _persistLifetimeBest(GameMode mode, int best) async {
    if (mode == GameMode.zen || best <= 0) return;
    final stats = await _repo.loadStats();
    if (mode == GameMode.classic && best > stats.classicBest) {
      await _repo.saveStats(stats.copyWith(classicBest: best));
    } else if (mode == GameMode.daily && best > stats.dailyBest) {
      await _repo.saveStats(stats.copyWith(dailyBest: best));
    }
  }

  Future<void> _updateStatsOnGameOver(GameSession session) async {
    final stats = await _repo.loadStats();
    var updated = stats.copyWith(
      totalLinesCleared: stats.totalLinesCleared + session.linesCleared,
      totalBlocksPlaced: stats.totalBlocksPlaced + session.blocksPlaced,
      totalGamesPlayed: stats.totalGamesPlayed + 1,
    );
    if (session.mode == GameMode.classic &&
        session.score > stats.classicBest) {
      updated = updated.copyWith(classicBest: session.score);
    }
    if (session.mode == GameMode.daily &&
        session.score > stats.dailyBest) {
      updated = updated.copyWith(dailyBest: session.score);
    }
    if (session.mode == GameMode.zen) {
      updated = updated.copyWith(zenGamesPlayed: stats.zenGamesPlayed + 1);
    }
    await _repo.saveStats(updated);

    // Classic & daily count for move-based survival ranking.
    if (session.mode == GameMode.zen || session.movesMade <= 0) return;
    final board = await _repo.loadRanking();
    final entry = RankingEntry(
      id: const Uuid().v4(),
      mode: session.mode,
      movesMade: session.movesMade,
      activeSurviveMs: session.activeSurviveMs,
      score: session.score,
      rankPoints: session.rankPoints,
      playedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.saveRanking(RankingEngine.insertRun(board, entry));
  }

  Future<void> _onPaused(
    GamePaused event,
    Emitter<GameState> emit,
  ) async {
    if (_paused) return;
    _paused = true;
    _pauseStartedMs = DateTime.now().millisecondsSinceEpoch;
    if (_surviveClock != null) {
      _pausedRemainMs = _remainMs();
      _stopSurviveClock();
    } else {
      _pausedRemainMs = 0;
    }
    final current = state;
    if (current is GamePlaying) {
      emit(
        current.copyWith(
          surviveRemainingMs: _pausedRemainMs > 0
              ? _pausedRemainMs
              : current.surviveRemainingMs,
        ),
      );
    }
  }

  Future<void> _onResumed(
    GameResumed event,
    Emitter<GameState> emit,
  ) async {
    if (!_paused) return;
    final pauseMs = DateTime.now().millisecondsSinceEpoch -
        (_pauseStartedMs ?? DateTime.now().millisecondsSinceEpoch);
    _paused = false;
    _pauseStartedMs = null;
    if (_pausedRemainMs > 0) {
      _armSurviveMs(_pausedRemainMs);
    }
    _pausedRemainMs = 0;

    final current = state;
    if (current is! GamePlaying) return;

    var session = current.session;
    final bomb = session.timeBomb;
    if (bomb != null && pauseMs > 0) {
      session = session.copyWith(
        timeBomb: TimeBomb(
          row: bomb.row,
          col: bomb.col,
          expiresAtMs: bomb.expiresAtMs + pauseMs,
          color: bomb.color,
          kind: bomb.kind,
        ),
      );
    }
    emit(_stampClock(current.copyWith(session: session)));
  }

  Future<void> _onReset(GameReset event, Emitter<GameState> emit) async {
    _paused = false;
    _pausedRemainMs = 0;
    _pauseStartedMs = null;
    _stopSurviveClock();
    final mode = _mode ?? GameMode.classic;
    emit(const GameLoading());
    _configureGenerator(mode);
    final stats = await _repo.loadStats();
    final best = switch (mode) {
      GameMode.classic => stats.classicBest,
      GameMode.daily => stats.dailyBest,
      GameMode.zen => 0,
    };
    final session = _createNewSession(mode, best);
    await _repo.clearSession(mode);
    await _repo.saveSession(session);
    _stopSurviveClock();
    emit(_stampClock(GamePlaying(session)));
  }

  Future<void> _onSurviveClockTicked(
    SurviveClockTicked event,
    Emitter<GameState> emit,
  ) async {
    if (_paused) return;
    final current = state;
    if (current is! GamePlaying) return;
    if (_surviveClock == null) return;
    if (current.session.isGameOver) {
      _stopSurviveClock();
      return;
    }
    final left = _remainMs();
    if (left <= 0) {
      _stopSurviveClock();
      _haptics.heavy();
      // ignore: discarded_futures
      _audio.playSfx(SfxType.gameOver);
      emit(
        GameTimeUpState(
          current.session,
          isNewBest: current.session.score > current.session.bestScore &&
              current.session.score > 0 &&
              current.session.mode != GameMode.zen,
        ),
      );
      return;
    }
    final sec = (left / 1000).ceil();
    if (sec != _lastSurviveSec) {
      if (sec <= AppConstants.surviveWarningSec &&
          sec >= 1 &&
          sec < _lastSurviveSec) {
        // ignore: discarded_futures
        _audio.playSfx(SfxType.tick);
      }
      _lastSurviveSec = sec;
    }
    emit(current.copyWith(surviveRemainingMs: left));
  }

  Future<void> _onSurviveExtraTimeGranted(
    SurviveExtraTimeGranted event,
    Emitter<GameState> emit,
  ) async {
    final session = switch (state) {
      GameTimeUpState(:final session) => session,
      GamePlaying(:final session) => session,
      _ => null,
    };
    if (session == null || session.isGameOver) return;
    _armSurvive(AppConstants.surviveAdBonusSec);
    emit(_stampClock(GamePlaying(session)));
  }

  Future<void> _onSurviveGiveUp(
    SurviveGiveUp event,
    Emitter<GameState> emit,
  ) async {
    final session = switch (state) {
      GameTimeUpState(:final session) => session,
      GamePlaying(:final session) => session,
      _ => null,
    };
    if (session == null) return;
    _stopSurviveClock();
    final ended = session.copyWith(isGameOver: true);
    await _repo.saveSession(ended);
    await _updateStatsOnGameOver(ended);
    if (ended.mode == GameMode.daily) {
      await _repo.saveDaily(
        DailyChallengeRecord(
          date: HiveGameRepository.todayKey(),
          completed: true,
          score: ended.score,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _paused = false;
    _stopSurviveClock();
    return super.close();
  }
}
