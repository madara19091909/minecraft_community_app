import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((_) => SettingsRepository());

// ---------------- Server-side settings (privacy + notification prefs) ----------------
class SettingsController extends StateNotifier<AsyncValue<UserSettings>> {
  SettingsController(this._repo) : super(const AsyncValue.loading()) {
    load();
  }

  final SettingsRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final s = await _repo.fetch();
      if (mounted) state = AsyncValue.data(s);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(AppFailure.from(e), st);
    }
  }

  /// Optimistic update; reverts and rethrows if saving fails.
  Future<void> update(UserSettings Function(UserSettings) change) async {
    final before = state.valueOrNull ?? const UserSettings();
    final after = change(before);
    state = AsyncValue.data(after);
    try {
      await _repo.save(after);
    } catch (_) {
      if (mounted) state = AsyncValue.data(before);
      rethrow;
    }
  }
}

final userSettingsProvider =
    StateNotifierProvider.autoDispose<SettingsController, AsyncValue<UserSettings>>((ref) {
  ref.watch(authControllerProvider.select((a) => a.profile?.id));
  return SettingsController(ref.watch(settingsRepositoryProvider));
});

final blockedUsersProvider = FutureProvider.autoDispose<List<BlockedUser>>(
  (ref) => ref.watch(settingsRepositoryProvider).fetchBlocked(),
);

// ---------------- Appearance (local, device-only) ----------------
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider must be overridden in main()'),
);

const accentOptions = <({String name, Color color})>[
  (name: 'Grass', color: AppColors.grass),
  (name: 'Diamond', color: AppColors.diamond),
  (name: 'Gold', color: AppColors.gold),
  (name: 'Redstone', color: AppColors.redstone),
  (name: 'Amethyst', color: Color(0xFFB57BFF)),
  (name: 'Copper', color: Color(0xFFFF8A4C)),
];

class AppearanceState {
  const AppearanceState({required this.mode, required this.accentIndex});
  final ThemeMode mode;
  final int accentIndex;
  Color get accent => accentOptions[accentIndex].color;
}

class AppearanceController extends StateNotifier<AppearanceState> {
  AppearanceController(this._prefs)
      : super(AppearanceState(
          mode: _readMode(_prefs.getString(_modeKey)),
          accentIndex: _readAccent(_prefs.getInt(_accentKey)),
        ));

  final SharedPreferences _prefs;
  static const _modeKey = 'appearance.mode';
  static const _accentKey = 'appearance.accent';

  static ThemeMode _readMode(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark, // dark-first default
      };

  static int _readAccent(int? i) => (i != null && i >= 0 && i < accentOptions.length) ? i : 0;

  void setMode(ThemeMode mode) {
    state = AppearanceState(mode: mode, accentIndex: state.accentIndex);
    _prefs.setString(_modeKey, mode.name);
  }

  void setAccent(int index) {
    state = AppearanceState(mode: state.mode, accentIndex: index);
    _prefs.setInt(_accentKey, index);
  }
}

final appearanceProvider = StateNotifierProvider<AppearanceController, AppearanceState>(
  (ref) => AppearanceController(ref.watch(sharedPreferencesProvider)),
);
