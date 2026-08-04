import 'package:cloud_firestore/cloud_firestore.dart';
import 'city_utils.dart';

/// Minimum number of Elo-rated regular matches a player needs before they
/// appear on the city ranking — keeps an early lucky win (still on the
/// provisional K-factor) from landing someone at #1 with almost no
/// evidence behind it. Below this, a player's Elo badge is already hidden
/// on their profile (see my_profile_screen.dart / player_profile_view_
/// screen.dart), so the ranking uses the same threshold for consistency.
const int eloRankingMinMatches = 5;

/// Filters [allUsers] down to players in the same city as [city] (compared
/// via [normalizeCityForComparison], same accent/case-insensitive match
/// used by the available-players city filter) who have played at least
/// [eloRankingMinMatches] Elo-rated regular matches, then sorts the result
/// by eloRating descending (highest first).
///
/// Pure client-side filter/sort over an already-fetched user list, mirroring
/// how available_players_screen.dart handles city grouping — there's no
/// stored normalized-city field to query against in Firestore directly, so
/// filtering happens in Dart rather than via a `where('city', ...)` query.
List<QueryDocumentSnapshot> buildCityRanking(
  List<QueryDocumentSnapshot> allUsers,
  String city,
) {
  final normalizedCity = normalizeCityForComparison(city);
  if (normalizedCity.isEmpty) return [];

  final qualified = allUsers.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
    final docCity =
        normalizeCityForComparison(data['city'] as String? ?? '');
    final eloMatchesPlayed = (data['eloMatchesPlayed'] as int?) ?? 0;
    return docCity == normalizedCity &&
        eloMatchesPlayed >= eloRankingMinMatches;
  }).toList();

  qualified.sort((a, b) {
    final aElo =
        ((a.data() as Map<String, dynamic>)['eloRating'] as int?) ?? 1200;
    final bElo =
        ((b.data() as Map<String, dynamic>)['eloRating'] as int?) ?? 1200;
    return bElo.compareTo(aElo);
  });

  return qualified;
}
