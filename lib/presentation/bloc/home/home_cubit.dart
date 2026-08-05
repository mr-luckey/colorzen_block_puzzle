import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeUiState extends Equatable {
  const HomeUiState({
    this.page = 0,
    this.dailyLoading = false,
    this.refreshTick = 0,
  });

  final int page;
  final bool dailyLoading;
  /// Bumped when returning from a game so FutureBuilders reload.
  final int refreshTick;

  HomeUiState copyWith({
    int? page,
    bool? dailyLoading,
    int? refreshTick,
  }) {
    return HomeUiState(
      page: page ?? this.page,
      dailyLoading: dailyLoading ?? this.dailyLoading,
      refreshTick: refreshTick ?? this.refreshTick,
    );
  }

  @override
  List<Object?> get props => [page, dailyLoading, refreshTick];
}

/// Home carousel + daily-ad loading — no setState.
class HomeCubit extends Cubit<HomeUiState> {
  HomeCubit() : super(const HomeUiState());

  void setPage(int page) {
    if (page == state.page) return;
    emit(state.copyWith(page: page));
  }

  void setDailyLoading(bool loading) {
    if (loading == state.dailyLoading) return;
    emit(state.copyWith(dailyLoading: loading));
  }

  /// Soft refresh after returning from a game (BGM / daily card).
  void refresh() =>
      emit(state.copyWith(refreshTick: state.refreshTick + 1));
}
