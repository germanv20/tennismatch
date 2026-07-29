import 'package:cloud_firestore/cloud_firestore.dart';

class H2HService {
  static Future<void> recalculateHeadToHead({
    required String userA,
    required String userB,
  }) async {

    final matchesSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userA)
        .where('status', isEqualTo: 'completed')
        .get();

    int matches = 0;
    int winsA = 0;
    int winsB = 0;
    int setsWonA = 0;
    int setsWonB = 0;

    for (var doc in matchesSnapshot.docs) {
      final data = doc.data();

      final players = List<String>.from(data['players'] ?? []);

      if (!(players.contains(userA) && players.contains(userB))) continue;

      matches++;

      final winnerUid = data['winnerUid'];
      final type = data['type'] as String? ?? 'regular';

      if (type == 'guest' && winnerUid == 'guest') {
        // Guest match where the non-creator won: 'guest' is a placeholder
        // stored at creation time (the opponent had no UID yet), so it
        // never equals either real UID directly. Attribute the win to
        // whichever of userA/userB is NOT the creator.
        final createdBy = data['createdBy'] as String?;
        if (createdBy == userA) {
          winsB++;
        } else if (createdBy == userB) {
          winsA++;
        }
      } else if (winnerUid == userA) {
        winsA++;
      } else if (winnerUid == userB) {
        winsB++;
      }

      final result = data['result'] ?? {};
      final sets = result['sets'] as List? ?? [];

      final bool userAIsP1 = players[0] == userA;

      for (var set in sets) {
        final p1 = set['p1'];
        final p2 = set['p2'];

        final aScore = userAIsP1 ? p1 : p2;
        final bScore = userAIsP1 ? p2 : p1;

        if (aScore > bScore) {
          setsWonA++;
        } else {
          setsWonB++;
        }
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    final userARef = FirebaseFirestore.instance
        .collection('users')
        .doc(userA)
        .collection('headToHead')
        .doc(userB);

    batch.set(userARef, {
      'matches': matches,
      'wins': winsA,
      'losses': winsB,
      'setsWon': setsWonA,
      'setsLost': setsWonB,
    });

    await batch.commit();
  }
}