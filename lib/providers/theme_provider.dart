import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  defaultTheme,   // الثيم الافتراضي (Classic)
  modernTheme,    // ثيم مودرن (Dark Glass)
  prototypeTheme, // ثيم 3 - النموذج الكامل (Full Prototype UI)
}

extension AppThemeModeX on AppThemeMode {
  bool get isModern => this == AppThemeMode.modernTheme || this == AppThemeMode.prototypeTheme;
  bool get isTheme3 => this == AppThemeMode.prototypeTheme;
}


class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const String _prefKey = 'selected_app_theme_mode';

  ThemeNotifier() : super(AppThemeMode.defaultTheme) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString(_prefKey);
      if (savedStr == 'prototypeTheme' || savedStr == 'theme3') {
        state = AppThemeMode.prototypeTheme;
      } else if (savedStr == 'modernTheme') {
        state = AppThemeMode.modernTheme;
      } else {
        state = AppThemeMode.defaultTheme;
      }
    } catch (_) {}
  }

  Future<void> setTheme(AppThemeMode theme) async {
    state = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, theme.name);
    } catch (_) {}
  }

  bool get isModern => state == AppThemeMode.modernTheme || state == AppThemeMode.prototypeTheme;
  bool get isTheme3 => state == AppThemeMode.prototypeTheme;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
