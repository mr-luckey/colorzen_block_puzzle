import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GameOverBonusState extends Equatable {
  const GameOverBonusState({
    required this.displayScore,
    this.bonusClaimed = false,
  });

  final int displayScore;
  final bool bonusClaimed;

  @override
  List<Object?> get props => [displayScore, bonusClaimed];
}

/// Game-over +250 rewarded bonus — replaces StatefulBuilder setState.
class GameOverBonusCubit extends Cubit<GameOverBonusState> {
  GameOverBonusCubit(int initialScore)
      : super(GameOverBonusState(displayScore: initialScore));

  void claimBonus(int amount) {
    if (state.bonusClaimed) return;
    emit(
      GameOverBonusState(
        displayScore: state.displayScore + amount,
        bonusClaimed: true,
      ),
    );
  }
}
