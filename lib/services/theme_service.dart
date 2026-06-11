import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TennisTheme — defines colors for each Grand Slam-inspired theme
// ─────────────────────────────────────────────────────────────────────────────

class TennisTheme {
  final String code;
  final String label;      // Fallback English label
  final String labelKey;   // ARB key for localized name
  final String flag;
  final Color primary;     // AppBar
  final Color primaryDark;
  final Color background;
  final Color surface;
  final Color onPrimary;
  final Color playerCardColor;  // Profile card on Home screen
  final Color selectionColor;   // Selected chips (level, availability)

  const TennisTheme({
    required this.code,
    required this.label,
    required this.labelKey,
    required this.flag,
    required this.primary,
    required this.primaryDark,
    required this.background,
    required this.surface,
    required this.onPrimary,
    required this.playerCardColor,
    required this.selectionColor,
  });

  /// Button color per theme:
  /// FR  → dark green #1A5C38
  /// ENG → purple #4B2E83
  /// All others → primary color
  Color get buttonColor {
    if (code == 'fr') return const Color(0xFF1A5C38);
    if (code == 'eng') return const Color(0xFF4B2E83);
    return primary;
  }

  ThemeData toThemeData() {
    return ThemeData(
      useMaterial3: false,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 2,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: onPrimary,
        unselectedLabelColor: onPrimary.withValues(alpha: 0.7),
        indicatorColor: onPrimary,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: onPrimary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: buttonColor,
          side: BorderSide(color: buttonColor),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: buttonColor),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: buttonColor,
        foregroundColor: onPrimary,
      ),
      colorScheme: ColorScheme.light(
        primary: selectionColor,
        secondary: selectionColor,
        surface: surface,
        onPrimary: onPrimary,
        onSecondary: onPrimary,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? selectionColor : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? selectionColor.withValues(alpha: 0.5)
                : null),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? selectionColor : null),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme definitions
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Theme definitions — alphabetical by English name
// ─────────────────────────────────────────────────────────────────────────────

const TennisTheme themeFR = TennisTheme(
  code: 'fr',
  label: 'Clay',
  labelKey: 'themeClay',
  flag: '',
  primary: Color(0xFFC85A1A),
  primaryDark: Color(0xFF9E4410),
  background: Color(0xFFFFF5EF),
  surface: Colors.white,
  onPrimary: Colors.white,
  playerCardColor: Color(0xFFC85A1A),
  selectionColor: Color(0xFF1A5C38),
);

const TennisTheme themeDefault = TennisTheme(
  code: 'default',
  label: 'Default',
  labelKey: 'themeDefault',
  flag: '🎾',
  primary: Color(0xFF2E7D32),
  primaryDark: Color(0xFF1B5E20),
  background: Color(0xFFF5F5F5),
  surface: Colors.white,
  onPrimary: Colors.white,
  playerCardColor: Color(0xFF2E7D32),
  selectionColor: Color(0xFF2E7D32),
);

const TennisTheme themeENG = TennisTheme(
  code: 'eng',
  label: 'Grass',
  labelKey: 'themeGrass',
  flag: '',
  //primary: Color(0xFF2E7D32),
  primary: Color(0xFF1B5E20),
  primaryDark: Color(0xFF1B5E20),
  background: Color(0xFFF5F0FF),
  surface: Colors.white,
  onPrimary: Colors.white,
  // playerCardColor: Color(0xFF2E7D32),
  playerCardColor: Color(0xFF1B5E20),
  selectionColor: Color(0xFF4B2E83),
);

const TennisTheme themeAUS = TennisTheme(
  code: 'aus',
  label: 'Hard court 1',
  labelKey: 'themeHardCourt1',
  flag: '',
  primary: Color(0xFF009BDE),
  primaryDark: Color(0xFF0077B3),
  background: Color(0xFFE8F6FF),
  surface: Colors.white,
  onPrimary: Colors.white,
  playerCardColor: Color(0xFF009BDE),
  selectionColor: Color(0xFF009BDE),
);

const TennisTheme themeUS = TennisTheme(
  code: 'us',
  label: 'Hard court 2',
  labelKey: 'themeHardCourt2',
  flag: '',
  primary: Color(0xFF00308F),
  primaryDark: Color(0xFF001F5E),
  background: Color(0xFFFFF8E1),
  surface: Colors.white,
  onPrimary: Colors.white,
  playerCardColor: Color(0xFF00308F),
  selectionColor: Color(0xFF00308F),
);

// Alphabetical by English name: Clay, Default, Grass, Hard court 1, Hard court 2
const List<TennisTheme> allThemes = [
  themeFR,
  themeDefault,
  themeENG,
  themeAUS,
  themeUS,
];

TennisTheme themeByCode(String code) {
  return allThemes.firstWhere(
    (t) => t.code == code,
    orElse: () => themeDefault,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ThemeNotifier — ChangeNotifier that persists the selected theme
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'selected_theme';

  TennisTheme _current = themeDefault;

  TennisTheme get current => _current;

  /// Load saved theme on startup
  Future<void> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'default';
    _current = themeByCode(code);
    notifyListeners();
  }

  /// Change theme and persist
  Future<void> setTheme(TennisTheme theme) async {
    _current = theme;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, theme.code);
  }
}