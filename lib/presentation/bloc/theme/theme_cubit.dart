import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class ThemeCubit extends Cubit<ThemeStateData> {
  ThemeCubit(this._repo) : super(const ThemeStateData());

  final GameRepository _repo;

  Future<void> load() async {
    final loaded = await _repo.loadThemeState();
    // Persist migration (Enchanted Night default / Woodland locked).
    await _repo.saveThemeState(loaded);
    emit(loaded);
  }

  Future<void> selectTheme(AppThemeId id) async {
    if (!state.isUnlocked(id)) return;
    final next = state.copyWith(selected: id);
    emit(next);
    await _repo.saveThemeState(next);
  }

  Future<void> unlockTheme(AppThemeId id) async {
    if (state.isUnlocked(id)) return;
    final unlocked = [...state.unlocked, id];
    final next = state.copyWith(unlocked: unlocked);
    emit(next);
    await _repo.saveThemeState(next);
  }

  Future<void> applyUnlocks(ThemeStateData data) async {
    emit(data);
    await _repo.saveThemeState(data);
  }
}
