import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  defaultTheme, // الثيم الافتراضي
  modernTheme,  // ثيم مودرن
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
      if (savedStr == 'modernTheme') {
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

  bool get isModern => state == AppThemeMode.modernTheme;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
