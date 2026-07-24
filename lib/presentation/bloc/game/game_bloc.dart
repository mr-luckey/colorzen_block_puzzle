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

class BombExpired extends GameEvent {
  const BombExpired();
}

class ConveyorRecycled extends GameEvent {
  const ConveyorRecycled({required this.newPiece});
  final Piece newPiece;
  @override
  List<Object?> get props => [newPiece];
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
    this.praise = MovePraise.none,
    this.bombSpawned = false,
    this.boardNuked = false,
    this.bombDefused = false,
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
  final MovePraise praise;
  final bool bombSpawned;
  final bool boardNuked;
  final bool bombDefused;

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
        praise,
        bombSpawned,
        boardNuked,
        bombDefused,
      ];
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
    on<BombExpired>(_onBombExpired);
    on<ConveyorRecycled>(_onConveyorRecycled);
  }

  final GameRepository _repo;
  final PieceGenerator _pieceGen;
  final LineClearEngine _clearEngine;
  final HapticService _haptics;
  final AudioService _audio;
  final Future<void> Function(ThemeStateData) _onThemeMaybeUnlock;
  final Future<ThemeStateData> Function() _loadTheme;

  GameMode? _mode;

  Future<void> _onStarted(
    GameStarted event,
    Emitter<GameState> emit,
  ) async {
    emit(const GameLoading());
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

    GameSession? saved;
    if (!event.forceNew) {
      saved = await _repo.loadSession(event.mode);
      if (saved != null && saved.isGameOver) saved = null;
    }

    final stats = await _repo.loadStats();
    final best = switch (event.mode) {
      GameMode.classic => stats.classicBest,
      GameMode.daily => stats.dailyBest,
      GameMode.zen => 0,
    };

    final session = _normalizeBelt(
      saved?.copyWith(bestScore: best) ?? _createNewSession(event.mode, best),
    );
    await _repo.saveSession(session);
    emit(GamePlaying(session));
  }

  void _configureGenerator(GameMode mode) {
    if (mode == GameMode.daily) {
      _pieceGen.setSeed(PieceGenerator.seedFromDate(DateTime.now()));
    } else {
      _pieceGen.useSystemRandom();
    }
  }

  GameSession _createNewSession(GameMode mode, int best) {
    var belt = _pieceGen.generateSet(count: AppConstants.beltSize);
    // Zen: calm endless play — no bombs on the conveyor.
    if (mode == GameMode.zen) {
      belt = belt.map((p) => p.copyWith(isBomb: false)).toList();
    }
    var grid = GameSession.emptyGrid();
    // Daily: seeded opening pattern so every player gets the same board start.
    if (mode == GameMode.daily) {
      grid = _dailyOpeningPattern();
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
    final existing = session.currentPieces.whereType<Piece>().toList();
    final fromNext = session.nextPieces;
    final pool = [...existing, ...fromNext];
    while (pool.length < AppConstants.beltSize) {
      pool.add(_pieceGen.nextConveyorPiece());
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

    var consecutive = session.consecutiveClearMoves;
    if (lines > 0) {
      consecutive += 1;
      _haptics.medium();
      await _audio.playSfx(SfxType.clear);
      if (consecutive >= 3) {
        await _audio.playSfx(SfxType.combo);
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
    final praise = RankingEngine.praiseFor(
      linesCleared: lines,
      consecutiveClearMoves: consecutive,
      hadColorBonus: hadColorBonus,
      scoreGained: gained,
    );

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
      await _audio.playSfx(SfxType.combo);
      await _audio.playSfx(SfxType.clear);

      if (defuseTarget.isFullWipe) {
        // Combo bomb → wipe entire board.
        final filled = _countFilled(workingGrid);
        workingGrid = GameSession.emptyGrid();
        final nukeBonus = scoringEnabled
            ? AppConstants.bombBoardClearBonus +
                filled * AppConstants.bombPerBlockBonus
            : 0;
        gained += nukeBonus;
        boardNuked = true;
      } else {
        // Conveyor bomb → blast a local square around the bomb cell.
        final blast = _applyAreaBlast(
          workingGrid,
          defuseTarget.row,
          defuseTarget.col,
          AppConstants.bombAreaRadius,
        );
        workingGrid = blast.grid;
        blastCells = blast.cells;
        var areaBonus = scoringEnabled
            ? AppConstants.bombAreaClearBonus +
                blast.removed * AppConstants.bombPerBlockBonus
            : 0;

        // Cascading line clears created by the blast hole.
        final cascade = _clearEngine.detectAndClear(workingGrid);
        if (cascade.linesCleared > 0) {
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
        await _audio.playSfx(SfxType.pickup);
      }
    }

    // Drop bomb marker if its cell vanished.
    if (bomb != null && workingGrid[bomb.row][bomb.col] == null) {
      bomb = null;
    }

    // 2+ lines in one move → spawn a combo (full-wipe) bomb on a filled cell.
    if (!bombDefused &&
        bomb == null &&
        lines >= 2 &&
        session.mode != GameMode.zen) {
      final armed = _spawnComboBomb(workingGrid, nowMs);
      if (armed != null) {
        bomb = armed;
        bombSpawned = true;
        _haptics.medium();
        await _audio.playSfx(SfxType.pickup);
      }
    }

    final newTray = List<Piece?>.from(session.currentPieces);
    // Remove used piece and append a fresh one — infinite conveyor.
    if (trayIndex >= 0 && trayIndex < newTray.length) {
      newTray.removeAt(trayIndex);
    }
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
      emit(GamePlaying(reset));
      return;
    }

    if (gameOver) {
      newSession = newSession.copyWith(isGameOver: true);
      await _repo.saveSession(newSession);
      await _updateStatsOnGameOver(newSession);
      _haptics.heavy();
      await _audio.playSfx(SfxType.gameOver);

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
        GamePlaying(
          newSession,
          lastScoreGained: gained,
          clearedRows: animRows,
          clearedCols: animCols,
          hadColorBonus: hadColorBonus,
          showCombo: consecutive >= 3 && lines > 0,
          placementAnimCells: placementCells,
          blastCells: blastCells,
          praise: boardNuked ? MovePraise.legendary : praise,
          bombSpawned: bombSpawned,
          boardNuked: boardNuked,
          bombDefused: bombDefused,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      emit(
        GameOverState(
          newSession,
          isNewBest: newSession.score > session.bestScore &&
              newSession.score > 0,
        ),
      );
      return;
    }

    await _repo.saveSession(newSession);
    await _maybeUnlockThemes(newSession);

    emit(
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
        praise: boardNuked
            ? MovePraise.legendary
            : (blastCells.isNotEmpty ? MovePraise.great : praise),
        bombSpawned: bombSpawned,
        boardNuked: boardNuked,
        bombDefused: bombDefused,
      ),
    );

    // Clear line-flash flags so empty cell backgrounds stay forever.
    final settleMoves = movesMade;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final after = state;
    if (after is GamePlaying &&
        after.session.movesMade == settleMoves &&
        !after.session.isGameOver) {
      emit(GamePlaying(after.session));
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
    final current = state;
    if (current is! GamePlaying) return;
    final bomb = current.session.timeBomb;
    if (bomb == null) return;
    if (!bomb.isExpired) return;
    final next = current.session.copyWith(clearBomb: true);
    await _repo.saveSession(next);
    emit(GamePlaying(next));
  }

  /// Leftmost piece scrolled off → drop it, append the piece tray already generated.
  Future<void> _onConveyorRecycled(
    ConveyorRecycled event,
    Emitter<GameState> emit,
  ) async {
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
    emit(GamePlaying(next));
    // Don't block the conveyor on disk I/O (was causing scroll flicker).
    // ignore: unawaited_futures
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

  Future<void> _onReset(GameReset event, Emitter<GameState> emit) async {
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
    emit(GamePlaying(session));
  }
}
