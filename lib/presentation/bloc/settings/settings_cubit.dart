import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:colorzen_block_puzzle/data/repositories/game_repository.dart';
import 'package:colorzen_block_puzzle/domain/models/models.dart';

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(
    this._repo, {
    Future<void> Function(AppSettings)? onChanged,
  })  : _onChanged = onChanged,
        super(const AppSettings());

  final GameRepository _repo;
  Future<void> Function(AppSettings)? _onChanged;

  void bindOnChanged(Future<void> Function(AppSettings) cb) {
    _onChanged = cb;
  }

  Future<void> load() async {
    emit(await _repo.loadSettings());
  }

  Future<void> _persist(AppSettings next) async {
    emit(next);
    await _repo.saveSettings(next);
    await _onChanged?.call(next);
  }

  Future<void> toggleSfx() =>
      _persist(state.copyWith(sfxEnabled: !state.sfxEnabled));

  Future<void> toggleMusic() =>
      _persist(state.copyWith(musicEnabled: !state.musicEnabled));

  Future<void> setVolume(double v) =>
      _persist(state.copyWith(musicVolume: v.clamp(0.0, 1.0)));

  Future<void> toggleHaptic() =>
      _persist(state.copyWith(hapticEnabled: !state.hapticEnabled));

  Future<void> toggleNotifications() => _persist(
        state.copyWith(notificationsEnabled: !state.notificationsEnabled),
      );

  Future<void> setAdsRemoved(bool value) =>
      _persist(state.copyWith(adsRemoved: value));
}
