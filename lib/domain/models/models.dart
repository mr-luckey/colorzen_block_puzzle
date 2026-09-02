import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

enum BlockColor {
  color0,
  color1,
  color2,
  color3,
  color4,
  color5,
}

enum GameMode { classic, daily, zen }

enum AppThemeId { midnightZen, desiRangoli, arcticIce, enchantedNight }

class Piece extends Equatable {
  const Piece({
    required this.shape,
    required this.color,
    required this.shapeIndex,
    this.isBomb = false,
    this.id = 0,
  });

  final List<List<bool>> shape;
  final BlockColor color;
  final int shapeIndex;
  final bool isBomb;
  /// Unique stream id so conveyor keys stay stable/random.
  final int id;

  int get rows => shape.length;
  int get cols => shape.isEmpty ? 0 : shape[0].length;

  int get blockCount {
    var count = 0;
    for (final row in shape) {
      for (final cell in row) {
        if (cell) count++;
      }
    }
    return count;
  }

  List<(int, int)> get occupiedCells {
    final cells = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (shape[r][c]) cells.add((r, c));
      }
    }
    return cells;
  }

  Piece copyWith({
    List<List<bool>>? shape,
    BlockColor? color,
    int? shapeIndex,
    bool? isBomb,
    int? id,
  }) {
    return Piece(
      shape: shape ?? this.shape,
      color: color ?? this.color,
      shapeIndex: shapeIndex ?? this.shapeIndex,
      isBomb: isBomb ?? this.isBomb,
      id: id ?? this.id,
    );
  }

  Map<String, dynamic> toMap() => {
        'shape': shape.map((r) => r.map((c) => c).toList()).toList(),
        'color': color.index,
        'shapeIndex': shapeIndex,
        'isBomb': isBomb,
        'id': id,
      };

  factory Piece.fromMap(Map<dynamic, dynamic> map) {
    final shapeRaw = map['shape'] as List;
    return Piece(
      shape: shapeRaw
          .map((r) => (r as List).map((c) => c as bool).toList())
          .toList(),
      color: BlockColor.values[map['color'] as int],
      shapeIndex: map['shapeIndex'] as int? ?? 0,
      isBomb: map['isBomb'] as bool? ?? false,
      id: map['id'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [shape, color, shapeIndex, isBomb, id];
}

class GameSession extends Equatable {
  const GameSession({
    required this.mode,
    required this.grid,
    required this.currentPieces,
    required this.nextPieces,
    required this.score,
    required this.bestScore,
    required this.linesCleared,
    required this.blocksPlaced,
    required this.comboCount,
    required this.isGameOver,
    this.consecutiveClearMoves = 0,
    this.movesMade = 0,
    this.activeSurviveMs = 0,
    this.lastMoveEpochMs,
    this.timeBomb,
    this.playfieldBgIndex = 0,
  });

  final GameMode mode;
  final List<List<BlockColor?>> grid;
  final List<Piece?> currentPieces;
  final List<Piece> nextPieces;
  final int score;
  final int bestScore;
  final int linesCleared;
  final int blocksPlaced;
  final int comboCount;
  final bool isGameOver;

  /// Moves in a row that cleared ≥1 line (for combo ≥3).
  final int consecutiveClearMoves;

  /// Successful piece placements this run.
  final int movesMade;

  /// Survive time that only advances between moves (idle AFK ignored).
  final int activeSurviveMs;

  /// Epoch ms of last successful place (runtime; reset on cold load).
  final int? lastMoveEpochMs;

  /// Active combo time-bomb (null = none).
  final TimeBomb? timeBomb;

  /// Unused leftover from old Hive saves (always 0).
  final int playfieldBgIndex;

  static List<List<BlockColor?>> emptyGrid() => List.generate(
        9,
        (_) => List<BlockColor?>.filled(9, null),
      );

  int get activeSurviveSeconds => activeSurviveMs ~/ 1000;

  /// Ranking points: moves dominate; active survive time is secondary.
  int get rankPoints => movesMade * 100 + activeSurviveSeconds;

  GameSession copyWith({
    GameMode? mode,
    List<List<BlockColor?>>? grid,
    List<Piece?>? currentPieces,
    List<Piece>? nextPieces,
    int? score,
    int? bestScore,
    int? linesCleared,
    int? blocksPlaced,
    int? comboCount,
    bool? isGameOver,
    int? consecutiveClearMoves,
    int? movesMade,
    int? activeSurviveMs,
    int? lastMoveEpochMs,
    TimeBomb? timeBomb,
    int? playfieldBgIndex,
    bool clearLastMove = false,
    bool clearBomb = false,
  }) {
    return GameSession(
      mode: mode ?? this.mode,
      grid: grid ?? this.grid,
      currentPieces: currentPieces ?? this.currentPieces,
      nextPieces: nextPieces ?? this.nextPieces,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      linesCleared: linesCleared ?? this.linesCleared,
      blocksPlaced: blocksPlaced ?? this.blocksPlaced,
      comboCount: comboCount ?? this.comboCount,
      isGameOver: isGameOver ?? this.isGameOver,
      consecutiveClearMoves:
          consecutiveClearMoves ?? this.consecutiveClearMoves,
      movesMade: movesMade ?? this.movesMade,
      activeSurviveMs: activeSurviveMs ?? this.activeSurviveMs,
      lastMoveEpochMs: clearLastMove
          ? null
          : (lastMoveEpochMs ?? this.lastMoveEpochMs),
      timeBomb: clearBomb ? null : (timeBomb ?? this.timeBomb),
      playfieldBgIndex: playfieldBgIndex ?? this.playfieldBgIndex,
    );
  }

  Map<String, dynamic> toMap() => {
        'mode': mode.index,
        'grid': grid
            .map((r) => r.map((c) => c?.index).toList())
            .toList(),
        'currentPieces':
            currentPieces.map((p) => p?.toMap()).toList(),
        'nextPieces': nextPieces.map((p) => p.toMap()).toList(),
        'score': score,
        'bestScore': bestScore,
        'linesCleared': linesCleared,
        'blocksPlaced': blocksPlaced,
        'comboCount': comboCount,
        'isGameOver': isGameOver,
        'consecutiveClearMoves': consecutiveClearMoves,
        'movesMade': movesMade,
        'activeSurviveMs': activeSurviveMs,
        'timeBomb': timeBomb?.toMap(),
        'playfieldBgIndex': playfieldBgIndex,
      };

  factory GameSession.fromMap(Map<dynamic, dynamic> map) {
    final gridRaw = map['grid'] as List;
    final currentRaw = map['currentPieces'] as List;
    final nextRaw = map['nextPieces'] as List;
    final bombRaw = map['timeBomb'];
    return GameSession(
      mode: GameMode.values[map['mode'] as int],
      grid: gridRaw
          .map(
            (r) => (r as List)
                .map(
                  (c) => c == null
                      ? null
                      : BlockColor.values[c as int],
                )
                .toList(),
          )
          .toList(),
      currentPieces: currentRaw
          .map(
            (p) => p == null
                ? null
                : Piece.fromMap(Map<dynamic, dynamic>.from(p as Map)),
          )
          .toList(),
      nextPieces: nextRaw
          .map(
            (p) => Piece.fromMap(Map<dynamic, dynamic>.from(p as Map)),
          )
          .toList(),
      score: _asInt(map['score']),
      bestScore: _asInt(map['bestScore']),
      linesCleared: _asInt(map['linesCleared']),
      blocksPlaced: _asInt(map['blocksPlaced']),
      comboCount: _asInt(map['comboCount']),
      isGameOver: map['isGameOver'] as bool? ?? false,
      consecutiveClearMoves: _asInt(map['consecutiveClearMoves']),
      movesMade: _asInt(map['movesMade']),
      activeSurviveMs: _asInt(map['activeSurviveMs']),
      lastMoveEpochMs: null,
      timeBomb: bombRaw is Map
          ? TimeBomb.fromMap(Map<dynamic, dynamic>.from(bombRaw))
          : null,
      playfieldBgIndex: _asInt(map['playfieldBgIndex']),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        grid,
        currentPieces,
        nextPieces,
        score,
        bestScore,
        linesCleared,
        blocksPlaced,
        comboCount,
        isGameOver,
        consecutiveClearMoves,
        movesMade,
        activeSurviveMs,
        lastMoveEpochMs,
        timeBomb,
        playfieldBgIndex,
      ];
}

/// Where the timed bomb came from — decides defuse reward.
enum BombKind {
  /// Spawned after clearing 2+ lines at once → full board wipe on defuse.
  combo,
  /// From the horizontal conveyor → local area blast on defuse.
  conveyor,
}

/// A board cell converted into a timed bomb.
class TimeBomb extends Equatable {
  const TimeBomb({
    required this.row,
    required this.col,
    required this.expiresAtMs,
    required this.color,
    this.kind = BombKind.conveyor,
  });

  final int row;
  final int col;
  final int expiresAtMs;
  final BlockColor color;
  final BombKind kind;

  bool get isFullWipe => kind == BombKind.combo;

  int remainingMs([int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return (expiresAtMs - now).clamp(0, 1 << 30);
  }

  bool get isExpired => remainingMs() <= 0;

  Map<String, dynamic> toMap() => {
        'row': row,
        'col': col,
        'expiresAtMs': expiresAtMs,
        'color': color.index,
        'kind': kind.index,
      };

  factory TimeBomb.fromMap(Map<dynamic, dynamic> map) {
    final kindIdx = map['kind'] as int?;
    return TimeBomb(
      row: map['row'] as int,
      col: map['col'] as int,
      expiresAtMs: map['expiresAtMs'] as int,
      color: BlockColor.values[map['color'] as int? ?? 0],
      kind: (kindIdx != null &&
              kindIdx >= 0 &&
              kindIdx < BombKind.values.length)
          ? BombKind.values[kindIdx]
          : BombKind.conveyor,
    );
  }

  @override
  List<Object?> get props => [row, col, expiresAtMs, color, kind];
}

class AppSettings extends Equatable {
  const AppSettings({
    this.sfxEnabled = true,
    this.musicEnabled = true,
    this.musicVolume = 0.72,
    this.hapticEnabled = true,
    this.notificationsEnabled = false,
    this.adsRemoved = false,
  });

  final bool sfxEnabled;
  final bool musicEnabled;
  final double musicVolume;
  final bool hapticEnabled;
  final bool notificationsEnabled;
  final bool adsRemoved;

  AppSettings copyWith({
    bool? sfxEnabled,
    bool? musicEnabled,
    double? musicVolume,
    bool? hapticEnabled,
    bool? notificationsEnabled,
    bool? adsRemoved,
  }) {
    return AppSettings(
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      musicVolume: musicVolume ?? this.musicVolume,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      adsRemoved: adsRemoved ?? this.adsRemoved,
    );
  }

  Map<String, dynamic> toMap() => {
        'sfxEnabled': sfxEnabled,
        'musicEnabled': musicEnabled,
        'musicVolume': musicVolume,
        'hapticEnabled': hapticEnabled,
        'notificationsEnabled': notificationsEnabled,
        'adsRemoved': adsRemoved,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic> map) => AppSettings(
        sfxEnabled: map['sfxEnabled'] as bool? ?? true,
        musicEnabled: map['musicEnabled'] as bool? ?? true,
        musicVolume: (map['musicVolume'] as num?)?.toDouble() ?? 0.72,
        hapticEnabled: map['hapticEnabled'] as bool? ?? true,
        notificationsEnabled:
            map['notificationsEnabled'] as bool? ?? false,
        adsRemoved: map['adsRemoved'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        sfxEnabled,
        musicEnabled,
        musicVolume,
        hapticEnabled,
        notificationsEnabled,
        adsRemoved,
      ];
}

class ThemeStateData extends Equatable {
  const ThemeStateData({
    this.selected = AppThemeId.enchantedNight,
    this.unlocked = const [AppThemeId.enchantedNight],
  });

  final AppThemeId selected;
  final List<AppThemeId> unlocked;

  bool isUnlocked(AppThemeId id) => unlocked.contains(id);

  ThemeStateData copyWith({
    AppThemeId? selected,
    List<AppThemeId>? unlocked,
  }) {
    return ThemeStateData(
      selected: selected ?? this.selected,
      unlocked: unlocked ?? this.unlocked,
    );
  }

  Map<String, dynamic> toMap() => {
        'selected': selected.index,
        'unlocked': unlocked.map((e) => e.index).toList(),
      };

  factory ThemeStateData.fromMap(Map<dynamic, dynamic> map) {
    final unlockedRaw = map['unlocked'] as List? ??
        [AppThemeId.enchantedNight.index];
    final themes = AppThemeId.values;
    AppThemeId parseId(int i) =>
        (i >= 0 && i < themes.length) ? themes[i] : AppThemeId.enchantedNight;

    var selected = parseId(map['selected'] as int? ??
        AppThemeId.enchantedNight.index);
    var unlocked = unlockedRaw.map((i) => parseId(i as int)).toList();

    // First-time migration to Enchanted Night default: lock free Woodland.
    final hadEnchanted =
        unlocked.contains(AppThemeId.enchantedNight);
    if (!hadEnchanted) {
      unlocked = [
        ...unlocked.where((e) => e != AppThemeId.midnightZen),
        AppThemeId.enchantedNight,
      ];
      if (selected == AppThemeId.midnightZen) {
        selected = AppThemeId.enchantedNight;
      }
    }
    if (!unlocked.contains(AppThemeId.enchantedNight)) {
      unlocked = [...unlocked, AppThemeId.enchantedNight];
    }
    if (!unlocked.contains(selected)) {
      selected = AppThemeId.enchantedNight;
    }

    return ThemeStateData(selected: selected, unlocked: unlocked);
  }

  @override
  List<Object?> get props => [selected, unlocked];
}

class LifetimeStats extends Equatable {
  const LifetimeStats({
    this.totalLinesCleared = 0,
    this.totalBlocksPlaced = 0,
    this.totalGamesPlayed = 0,
    this.classicBest = 0,
    this.dailyBest = 0,
    this.zenGamesPlayed = 0,
  });

  final int totalLinesCleared;
  final int totalBlocksPlaced;
  final int totalGamesPlayed;
  final int classicBest;
  final int dailyBest;
  final int zenGamesPlayed;

  LifetimeStats copyWith({
    int? totalLinesCleared,
    int? totalBlocksPlaced,
    int? totalGamesPlayed,
    int? classicBest,
    int? dailyBest,
    int? zenGamesPlayed,
  }) {
    return LifetimeStats(
      totalLinesCleared: totalLinesCleared ?? this.totalLinesCleared,
      totalBlocksPlaced: totalBlocksPlaced ?? this.totalBlocksPlaced,
      totalGamesPlayed: totalGamesPlayed ?? this.totalGamesPlayed,
      classicBest: classicBest ?? this.classicBest,
      dailyBest: dailyBest ?? this.dailyBest,
      zenGamesPlayed: zenGamesPlayed ?? this.zenGamesPlayed,
    );
  }

  Map<String, dynamic> toMap() => {
        'totalLinesCleared': totalLinesCleared,
        'totalBlocksPlaced': totalBlocksPlaced,
        'totalGamesPlayed': totalGamesPlayed,
        'classicBest': classicBest,
        'dailyBest': dailyBest,
        'zenGamesPlayed': zenGamesPlayed,
      };

  factory LifetimeStats.fromMap(Map<dynamic, dynamic> map) =>
      LifetimeStats(
        totalLinesCleared: map['totalLinesCleared'] as int? ?? 0,
        totalBlocksPlaced: map['totalBlocksPlaced'] as int? ?? 0,
        totalGamesPlayed: map['totalGamesPlayed'] as int? ?? 0,
        classicBest: map['classicBest'] as int? ?? 0,
        dailyBest: map['dailyBest'] as int? ?? 0,
        zenGamesPlayed: map['zenGamesPlayed'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [
        totalLinesCleared,
        totalBlocksPlaced,
        totalGamesPlayed,
        classicBest,
        dailyBest,
        zenGamesPlayed,
      ];
}

/// How strong a move praise should feel.
enum MovePraise { none, nice, great, awesome, legendary, allClear }

enum RankTier { rookie, climber, survivor, champion, legend }

class RankingEntry extends Equatable {
  const RankingEntry({
    required this.id,
    required this.mode,
    required this.movesMade,
    required this.activeSurviveMs,
    required this.score,
    required this.rankPoints,
    required this.playedAtMs,
  });

  final String id;
  final GameMode mode;
  final int movesMade;
  final int activeSurviveMs;
  final int score;
  final int rankPoints;
  final int playedAtMs;

  int get activeSurviveSeconds => activeSurviveMs ~/ 1000;

  Map<String, dynamic> toMap() => {
        'id': id,
        'mode': mode.index,
        'movesMade': movesMade,
        'activeSurviveMs': activeSurviveMs,
        'score': score,
        'rankPoints': rankPoints,
        'playedAtMs': playedAtMs,
      };

  factory RankingEntry.fromMap(Map<dynamic, dynamic> map) => RankingEntry(
        id: map['id'] as String? ?? '',
        mode: GameMode.values[(map['mode'] as int?) ?? 0],
        movesMade: map['movesMade'] as int? ?? 0,
        activeSurviveMs: map['activeSurviveMs'] as int? ?? 0,
        score: map['score'] as int? ?? 0,
        rankPoints: map['rankPoints'] as int? ?? 0,
        playedAtMs: map['playedAtMs'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [
        id,
        mode,
        movesMade,
        activeSurviveMs,
        score,
        rankPoints,
        playedAtMs,
      ];
}

class RankingBoard extends Equatable {
  const RankingBoard({this.entries = const []});

  final List<RankingEntry> entries;

  RankingBoard copyWith({List<RankingEntry>? entries}) =>
      RankingBoard(entries: entries ?? this.entries);

  Map<String, dynamic> toMap() => {
        'entries': entries.map((e) => e.toMap()).toList(),
      };

  factory RankingBoard.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['entries'] as List? ?? const [];
    return RankingBoard(
      entries: raw
          .map((e) => RankingEntry.fromMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [entries];
}

class DailyChallengeRecord extends Equatable {
  const DailyChallengeRecord({
    required this.date,
    required this.completed,
    this.score = 0,
  });

  final String date;
  final bool completed;
  final int score;

  Map<String, dynamic> toMap() => {
        'date': date,
        'completed': completed,
        'score': score,
      };

  factory DailyChallengeRecord.fromMap(Map<dynamic, dynamic> map) =>
      DailyChallengeRecord(
        date: map['date'] as String,
        completed: map['completed'] as bool? ?? false,
        score: map['score'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [date, completed, score];
}

class LineClearResult {
  const LineClearResult({
    required this.grid,
    required this.clearedRows,
    required this.clearedCols,
    required this.colorBonusFlags,
  });

  final List<List<BlockColor?>> grid;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final List<bool> colorBonusFlags;

  int get linesCleared => clearedRows.length + clearedCols.length;
}

class PlacementResult {
  const PlacementResult({
    required this.valid,
    this.row = 0,
    this.col = 0,
  });

  final bool valid;
  final int row;
  final int col;
}

@immutable
class ColorPalette {
  const ColorPalette({
    required this.background,
    required this.gridBackground,
    required this.gridLine,
    required this.cellEmpty,
    required this.surface,
    required this.accentPrimary,
    required this.accentSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.blocks,
    this.comboGold = const Color(0xFFFFD700),
    this.invalidRed = const Color(0xFFFF4444),
  });

  final Color background;
  final Color gridBackground;
  final Color gridLine;
  final Color cellEmpty;
  final Color surface;
  final Color accentPrimary;
  final Color accentSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final List<Color> blocks;
  final Color comboGold;
  final Color invalidRed;

  Color blockColor(BlockColor color) => blocks[color.index];
}
