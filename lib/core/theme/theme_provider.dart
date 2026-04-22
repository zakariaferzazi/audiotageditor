import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'package:mp3tageditor/core/services/shared_prefs_service.dart';

const _themeModePrefsKey = 'theme_mode_v1';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future.microtask(_loadTheme);
    return ThemeMode.light;
  }

  Future<void> _loadTheme() async {
    final prefs = ref.read(sharedPrefsServiceProvider);
    final raw = prefs.getString(_themeModePrefsKey);

    if (raw == 'dark') {
      state = ThemeMode.dark;
      return;
    }
    if (raw == 'light') {
      state = ThemeMode.light;
      return;
    }

    state = ThemeMode.light;
    await prefs.setString(_themeModePrefsKey, 'light');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPrefsServiceProvider);
    await prefs.setString(
      _themeModePrefsKey,
      mode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
