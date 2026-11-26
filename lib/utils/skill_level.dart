import 'package:tennismatch/gen_l10n/app_localizations.dart';

/// Skill level systems (Batch C). Colombia uses the local amateur categories
/// (6ta = beginner up to 2da = highest amateur); every other country uses
/// NTRP. The system follows the profile's country at the time the level is
/// chosen and is stored next to the value (`levelSystem` / `levelValue`), so
/// a level is always read together with its own system.
///
/// The legacy `tennisLevel` string (Beginner/Intermediate/Advanced) is still
/// written, derived from the new level, so older app versions and the
/// "profile complete" check in main.dart keep working.
class SkillLevel {
  SkillLevel._();

  static const String co = 'co';
  static const String ntrp = 'ntrp';

  /// Colombian categories, weakest to strongest. The stored value is the
  /// category number (6 = 6ta ... 2 = 2da).
  static const List<num> coValues = [6, 5, 4, 3, 2];

  /// NTRP options, weakest to strongest. 1.5 means "1.5 or below" and 5.5
  /// means "5.5 or above".
  static const List<num> ntrpValues = [1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5];

  /// Which system a country uses (ISO code, e.g. 'CO').
  static String systemForCountryCode(String? countryCode) =>
      (countryCode ?? '').toUpperCase() == 'CO' ? co : ntrp;

  static List<num> valuesFor(String system) =>
      system == co ? coValues : ntrpValues;

  /// Position from weakest (0) to strongest — used to compare/range-filter
  /// within one system. -1 when the value isn't part of the system.
  static int rankOf(String system, num value) {
    final list = valuesFor(system);
    for (var i = 0; i < list.length; i++) {
      if (list[i] == value) return i;
    }
    return -1;
  }

  /// Reads a stored level safely from a user doc (null if not set / invalid).
  static ({String system, num value})? fromUserData(Map<String, dynamic> d) {
    final system = d['levelSystem'];
    final value = d['levelValue'];
    if (system is! String || value is! num) return null;
    if (rankOf(system, value) < 0) return null;
    return (system: system, value: value);
  }

  /// Short display label for a user doc's new-style level, or null when the
  /// user hasn't chosen one yet (callers then fall back to the legacy label).
  static String? displayFromUserData(
      AppLocalizations loc, Map<String, dynamic> d) {
    final lvl = fromUserData(d);
    if (lvl == null) return null;
    return shortLabel(loc, lvl.system, lvl.value);
  }

  /// Legacy 3-level value derived from a new level.
  static String legacyFor(String system, num value) {
    if (system == co) {
      if (value >= 5) return 'Beginner';
      if (value == 4) return 'Intermediate';
      return 'Advanced';
    }
    if (value <= 2.5) return 'Beginner';
    if (value <= 4.0) return 'Intermediate';
    return 'Advanced';
  }

  /// Pre-selected suggestion for an existing user, from the old level.
  static num? suggestionFromLegacy(String system, String? legacy) {
    switch (legacy) {
      case 'Beginner':
        return system == co ? 6 : 2.0;
      case 'Intermediate':
        return system == co ? 4 : 3.5;
      case 'Advanced':
        return system == co ? 3 : 4.5;
    }
    return null;
  }

  static String _ntrpNumber(num v) => v.toStringAsFixed(1);

  /// Long label used in pickers ("1.5 or below", "5.5 or above").
  static String label(AppLocalizations loc, String system, num value) {
    if (system == co) {
      switch (value.toInt()) {
        case 6: return loc.levelCo6;
        case 5: return loc.levelCo5;
        case 4: return loc.levelCo4;
        case 3: return loc.levelCo3;
        default: return loc.levelCo2;
      }
    }
    if (value == 1.5) return 'NTRP ${loc.levelNtrpLow}';
    if (value == 5.5) return 'NTRP ${loc.levelNtrpHigh}';
    return 'NTRP ${_ntrpNumber(value)}';
  }

  /// Short label for cards/profiles ("6th category", "NTRP 3.5", "NTRP 5.5+").
  static String shortLabel(AppLocalizations loc, String system, num value) {
    if (system == co) return label(loc, system, value);
    if (value == 5.5) return 'NTRP 5.5+';
    return 'NTRP ${_ntrpNumber(value)}';
  }

  static String description(AppLocalizations loc, String system, num value) {
    if (system == co) {
      switch (value.toInt()) {
        case 6: return loc.levelCo6Desc;
        case 5: return loc.levelCo5Desc;
        case 4: return loc.levelCo4Desc;
        case 3: return loc.levelCo3Desc;
        default: return loc.levelCo2Desc;
      }
    }
    switch (_ntrpNumber(value)) {
      case '1.5': return loc.levelNtrpDesc15;
      case '2.0': return loc.levelNtrpDesc20;
      case '2.5': return loc.levelNtrpDesc25;
      case '3.0': return loc.levelNtrpDesc30;
      case '3.5': return loc.levelNtrpDesc35;
      case '4.0': return loc.levelNtrpDesc40;
      case '4.5': return loc.levelNtrpDesc45;
      case '5.0': return loc.levelNtrpDesc50;
      default: return loc.levelNtrpDesc55;
    }
  }

  /// Fields to write to `users/{uid}` for a chosen level.
  static Map<String, dynamic> toFirestore(String system, num value) => {
        'levelSystem': system,
        'levelValue': value,
        'tennisLevel': legacyFor(system, value),
      };
}
