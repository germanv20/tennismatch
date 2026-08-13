import 'package:cloud_firestore/cloud_firestore.dart';
import 'city_utils.dart';

/// How far back the city activity feed looks.
const int cityActivityWindowDays = 7;

/// One row in the city activity feed — a reduced summary (who played, who
/// won, when), deliberately not the full match record (score breakdown,
/// location, notes) even though the underlying match documents do carry
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

  const CityActivityMatch({
    required this.id,
    required this.type,
    required this.completedAt,
    required this.player1Label,
    required this.player2Label,
    required this.isTie,
    required this.player1Won,
  });
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

    feed.add(CityActivityMatch(
      id: doc.id,
      type: 'regular',
      completedAt: completedAt,
      player1Label: (summary['p1Name'] as String?) ?? '',
      player2Label: (summary['p2Name'] as String?) ?? '',
      isTie: isTie,
      player1Won: !isTie && winnerUid != null && winnerUid == player1Uid,
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

    if (type == 'doubles_guest') {
      final team1 = data['team1'] as Map<String, dynamic>? ?? {};
      final team2 = data['team2'] as Map<String, dynamic>? ?? {};
      final winnerTeam = data['winnerTeam'] as int?;

      feed.add(CityActivityMatch(
        id: doc.id,
        type: 'doubles_guest',
        completedAt: completedAt,
        player1Label:
            '${team1['player1'] ?? ''} / ${team1['player2'] ?? ''}',
        player2Label:
            '${team2['player1'] ?? ''} / ${team2['player2'] ?? ''}',
        isTie: isTie,
        player1Won: !isTie && winnerTeam == 1,
      ));
    } else {
      final summary = data['summary'] as Map<String, dynamic>?;
      final winnerUid = data['winnerUid'] as String?;

      feed.add(CityActivityMatch(
        id: doc.id,
        type: 'guest',
        completedAt: completedAt,
        player1Label: (summary?['p1Name'] as String?) ?? '',
        player2Label: (summary?['p2Name'] as String?) ?? '',
        isTie: isTie,
        player1Won: !isTie && winnerUid == createdBy,
      ));
    }
  }

  feed.sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return feed;
}
