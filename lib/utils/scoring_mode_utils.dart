import 'package:tennismatch/gen_l10n/app_localizations.dart';

/// Maps a match's stored `result.scoringMode` string (the raw
/// `ScoringMode.name` value written at save time, e.g. `'proSet'`,
/// `'tiebreakOnly'`) to the same localized label already used for the
/// scoring-mode picker chips (`loc.officialScoring`/`proSetScoring`/
/// `openScoring`/`tiebreakOnlyScoring`) — reused here for *display*, on
/// match cards and detail screens, so a player can tell at a glance
/// whether a match was played with full sets, a pro-set, free scoring, or
/// standalone tiebreaks. Defaults to "Official" for null/unrecognized
/// values, matching how every other `scoringMode` read site in this
/// codebase treats an absent value (matches predating this field, or the
/// original default before a mode was ever picked).
String scoringModeDisplayLabel(String? scoringMode, AppLocalizations loc) {
  switch (scoringMode) {
    case 'proSet':
      return loc.proSetScoring;
    case 'open':
      return loc.openScoring;
    case 'tiebreakOnly':
      return loc.tiebreakOnlyScoring;
    case 'official':
    default:
      return loc.officialScoring;
  }
}
