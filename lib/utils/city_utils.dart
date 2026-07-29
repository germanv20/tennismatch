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
