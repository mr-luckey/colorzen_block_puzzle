import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';

class DailyChallengeState extends Equatable {
  const DailyChallengeState({
    required this.completed,
    required this.remaining,
    this.score = 0,
  });

  final bool completed;
  final Duration remaining;
  final int score;

  String get countdown {
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  List<Object?> get props => [completed, remaining, score];
}

class DailyChallengeCubit extends Cubit<DailyChallengeState> {
  DailyChallengeCubit(this._repo)
      : super(
          DailyChallengeState(
            completed: false,
            remaining: _untilMidnight(),
          ),
        );

  final GameRepository _repo;
  Timer? _timer;

  static Duration _untilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  Future<void> start() async {
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final remaining = _untilMidnight();
      if (remaining.inSeconds <= 0) {
        await refresh();
      } else {
        emit(
          DailyChallengeState(
            completed: state.completed,
            remaining: remaining,
            score: state.score,
          ),
        );
      }
    });
  }

  Future<void> refresh() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final record = await _repo.loadDaily(today);
    emit(
      DailyChallengeState(
        completed: record?.completed ?? false,
        remaining: _untilMidnight(),
        score: record?.score ?? 0,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
