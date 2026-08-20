import 'package:cloud_firestore/cloud_firestore.dart';
import 'city_utils.dart';

/// How far back the city activity feed looks.
const int cityActivityWindowDays = 7;

/// One row in the city activity feed — a reduced summary (who played, who
/// won, the set score, when) — deliberately not the full match record
/// (location, notes) even though the underlying match documents do carry
/// that detail. Built from three very differently-shaped Firestore match
/// documents (regular / guest / doubles_guest), normalized here so the UI
/// only ever deals with one shape.
class CityActivityMatch {
  final String id;
  final String type; // 'regular' | 'guest' | 'doubles_guest'
  final DateTime completedAt;
  final String player1Label;
  final String player2Label;
  final bool isTie;
  final bool player1Won; // meaningless when isTie is true
  final String scoreText; // e.g. "6-4, 6-3" — empty if unavailable
  final String? scoringMode; // raw ScoringMode.name, e.g. 'tiebreakOnly'

  const CityActivityMatch({
    required this.id,
    required this.type,
    required this.completedAt,
    required this.player1Label,
    required this.player2Label,
    required this.isTie,
    required this.player1Won,
    required this.scoreText,
    required this.scoringMode,
  });
}

/// Formats a match's per-set score as a compact "6-4, 6-3" string, the same
/// convention already used for the WhatsApp share message in
/// log_doubles_match_screen.dart's `_formatScore()` (tiebreak points aren't
/// broken out separately there either, so this stays consistent with it).
///
/// [swap] flips each set's p1/p2 numbers (but not their order within the
/// string) — used when the feed displays player2 first (they won), so the
/// score still reads "winner's number - loser's number" instead of always
/// showing whichever player happened to be player1 at logging time first.
String formatSetScore(dynamic rawSets, {bool swap = false}) {
  if (rawSets is! List) return '';
  return rawSets.whereType<Map>().map((set) {
    final p1 = set['p1'] ?? 0;
    final p2 = set['p2'] ?? 0;
    return swap ? '$p2-$p1' : '$p1-$p2';
  }).join(', ');
}

/// Builds the city activity feed from three already-fetched inputs:
/// - [regularMatches]: completed regular (registered vs. registered) matches
/// - [guestDoublesMatches]: completed guest + doubles_guest matches
/// - [allUsers]: the full users collection, used only to map uid -> city
///   (matches don't store city directly, same reasoning as ranking_utils.dart)
///
/// Filters to matches involving at least one player in [viewerCity]
/// (compared via [normalizeCityForComparison]), sorted newest first.
List<CityActivityMatch> buildCityActivityFeed({
  required List<QueryDocumentSnapshot> regularMatches,
  required List<QueryDocumentSnapshot> guestDoublesMatches,
  required List<QueryDocumentSnapshot> allUsers,
  required String viewerCity,
}) {
  final normalizedViewerCity = normalizeCityForComparison(viewerCity);
  if (normalizedViewerCity.isEmpty) return [];

  final cityByUid = <String, String>{};
  for (final userDoc in allUsers) {
    final data = userDoc.data() as Map<String, dynamic>;
    final city = data['city'] as String?;
    if (city != null && city.trim().isNotEmpty) {
      cityByUid[userDoc.id] = normalizeCityForComparison(city);
    }
  }

  final feed = <CityActivityMatch>[];

  for (final doc in regularMatches) {
    final data = doc.data() as Map<String, dynamic>;
    final players = List<String>.from(data['players'] ?? const []);
    final inCity =
        players.any((uid) => cityByUid[uid] == normalizedViewerCity);
    if (!inCity) continue;

    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    final summary = data['summary'] as Map<String, dynamic>?;
    if (completedAt == null || summary == null) continue;

    final isTie = data['isTie'] == true;
    final winnerUid = data['winnerUid'] as String?;
    final player1Uid = data['player1Uid'] as String?;
    final result = data['result'] as Map<String, dynamic>?;
    final player1Won = !isTie && winnerUid != null && winnerUid == player1Uid;

    feed.add(CityActivityMatch(
      id: doc.id,
      type: 'regular',
      completedAt: completedAt,
      player1Label: (summary['p1Name'] as String?) ?? '',
      player2Label: (summary['p2Name'] as String?) ?? '',
      isTie: isTie,
      player1Won: player1Won,
      scoreText: formatSetScore(result?['sets'], swap: !isTie && !player1Won),
      scoringMode: result?['scoringMode'] as String?,
    ));
  }

  for (final doc in guestDoublesMatches) {
    final data = doc.data() as Map<String, dynamic>;
    final createdBy = data['createdBy'] as String?;
    if (createdBy == null || cityByUid[createdBy] != normalizedViewerCity) {
      continue;
    }

    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
    if (completedAt == null) continue;

    final type = data['type'] as String? ?? 'guest';
    final isTie = data['isTie'] == true;
    final result = data['result'] as Map<String, dynamic>?;

    if (type == 'doubles_guest') {
      final team1 = data['team1'] as Map<String, dynamic>? ?? {};
      final team2 = data['team2'] as Map<String, dynamic>? ?? {};
      final winnerTeam = data['winnerTeam'] as int?;
      final player1Won = !isTie && winnerTeam == 1;

      feed.add(CityActivityMatch(
        id: doc.id,
        type: 'doubles_guest',
        completedAt: completedAt,
        player1Label:
            '${team1['player1'] ?? ''} / ${team1['player2'] ?? ''}',
        player2Label:
            '${team2['player1'] ?? ''} / ${team2['player2'] ?? ''}',
        isTie: isTie,
        player1Won: player1Won,
        scoreText:
            formatSetScore(result?['sets'], swap: !isTie && !player1Won),
        scoringMode: result?['scoringMode'] as String?,
      ));
    } else {
      final summary = data['summary'] as Map<String, dynamic>?;
      final winnerUid = data['winnerUid'] as String?;
      final player1Won = !isTie && winnerUid == createdBy;

      feed.add(CityActivityMatch(
        id: doc.id,
        type: 'guest',
        completedAt: completedAt,
        player1Label: (summary?['p1Name'] as String?) ?? '',
        player2Label: (summary?['p2Name'] as String?) ?? '',
        isTie: isTie,
        player1Won: player1Won,
        scoreText:
            formatSetScore(result?['sets'], swap: !isTie && !player1Won),
        scoringMode: result?['scoringMode'] as String?,
      ));
    }
  }

  feed.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return feed;
}
