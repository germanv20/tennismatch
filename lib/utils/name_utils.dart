/// Formats a person's name for display: capitalizes the first letter of
/// each word (split on whitespace) and lowercases the rest, e.g.
/// "JUAN PEREZ" -> "Juan Perez", "maria lopez" -> "Maria Lopez".
///
/// This is a display-time safety net, the same approach already used for
/// city names (see `formatCityDisplay` in city_utils.dart): names are
/// stored exactly as the user typed them at signup (no save-time
/// normalization), so some accounts have all-caps names, some all-lowercase,
/// some mixed — this fixes how they're *shown* without needing every user
/// to re-save their profile, and is a no-op on a name that's already
/// properly cased. Accents are preserved since only case is touched.
/// Deliberately simple (a plain per-word capitalize, same as the city
/// helper) — no attempt at name-specific capitalization rules (e.g. "de la
/// Cruz", "O'Brien", "McDonald"), which would need a much larger exception
/// list for comparatively little real-world benefit here.
String formatNameDisplay(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) => word.isEmpty
          ? word
          : word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
