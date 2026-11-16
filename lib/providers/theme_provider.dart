import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  defaultTheme,   // 1. الثيم الافتراضي (Classic) 🏛️
  modernTheme,    // 2. ثيم مودرن (Dark Glass) ✨
  prototypeTheme, // 3. ثيم 3 - النموذج الكامل (Full Prototype UI) 💎
  obsidianTheme,  // 4. ثيم 4 - أوبسيديان جولد الفاخر (Obsidian & Gold) 👑
}

extension AppThemeModeX on AppThemeMode {
  bool get isModern =>
      this == AppThemeMode.modernTheme ||
      this == AppThemeMode.prototypeTheme ||
      this == AppThemeMode.obsidianTheme;

  bool get isTheme3 => this == AppThemeMode.prototypeTheme;
  bool get isTheme4 => this == AppThemeMode.obsidianTheme;
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
      if (savedStr == 'obsidianTheme' || savedStr == 'theme4') {
        state = AppThemeMode.obsidianTheme;
      } else if (savedStr == 'prototypeTheme' || savedStr == 'theme3') {
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

  bool get isModern =>
      state == AppThemeMode.modernTheme ||
      state == AppThemeMode.prototypeTheme ||
      state == AppThemeMode.obsidianTheme;

  bool get isTheme3 => state == AppThemeMode.prototypeTheme;
  bool get isTheme4 => state == AppThemeMode.obsidianTheme;
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});
