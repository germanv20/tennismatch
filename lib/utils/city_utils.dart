/// Formats a city name for display: capitalizes only the first letter,
/// leaving the rest of the text untouched (accents preserved, e.g.
/// "popayán" -> "Popayán").
///
/// This is a display-time safety net: it's a no-op on values already
/// saved correctly (post-fix), and it fixes the visual appearance of
/// legacy city values that were saved lowercase/accent-stripped by the
/// old profile-save logic, without needing every user to re-save their
/// profile.
String formatCityDisplay(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

/// Normalizes a city name for equality comparisons by stripping accents
/// and lowercasing, so that "Popayán" and "Popayan" (or "popayán") are
/// treated as the same city. Comparison-only — never used for display or
/// storage, since it destroys casing/accents (use [formatCityDisplay] for
/// that). Shared by the available-players city filter/grouping and the
/// city-scoped ranking, so the accent table only lives in one place.
String normalizeCityForComparison(String input) {
  const accents = 'áàäâãåéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÅÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
  const normal  = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
  final buffer = StringBuffer();
  for (final ch in input.split('')) {
    final idx = accents.indexOf(ch);
    buffer.write(idx >= 0 ? normal[idx] : ch);
  }
  return buffer.toString().toLowerCase().trim();
}
