import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Outcome of a one-tap "Play again" attempt.
enum RematchResult {
  /// A new pending match request was created.
  sent,

  /// I already have a pending request out to this player.
  alreadyPending,

  /// This player already sent ME a pending request — respond to that
  /// instead of creating a redundant one (same rule Available Players uses).
  incomingPending,

  /// A confirmed, not-yet-played match with this player already exists.
  alreadyScheduled,
}

class RematchService {
  /// Creates a normal `match_requests` doc (identical shape to the one
  /// `available_players_screen.dart`'s `requestMatch()` writes, so the
  /// existing `onMatchRequestReceived` push notification and the whole
  /// accept/reject flow work unchanged) — after the same guards Available
  /// Players applies: no duplicate outgoing request, no request when the
  /// other player already asked me, and none while an unplayed confirmed
  /// match with them exists.
  static Future<RematchResult> requestRematch(String opponentUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final db = FirebaseFirestore.instance;

    final outgoing = await db
        .collection('match_requests')
        .where('fromUid', isEqualTo: me)
        .where('toUid', isEqualTo: opponentUid)
        .where('status', isEqualTo: 'pending')
        .get();
    if (outgoing.docs.isNotEmpty) return RematchResult.alreadyPending;

    final incoming = await db
        .collection('match_requests')
        .where('fromUid', isEqualTo: opponentUid)
        .where('toUid', isEqualTo: me)
        .where('status', isEqualTo: 'pending')
        .get();
    if (incoming.docs.isNotEmpty) return RematchResult.incomingPending;

    final confirmed = await db
        .collection('matches')
        .where('players', arrayContains: me)
        .where('status', isEqualTo: 'confirmed')
        .get();
    final hasUnplayed = confirmed.docs.any((doc) {
      final players = List<String>.from(doc.data()['players'] ?? const []);
      return players.contains(opponentUid);
    });
    if (hasUnplayed) return RematchResult.alreadyScheduled;

    await db.collection('match_requests').add({
      'fromUid': me,
      'toUid': opponentUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return RematchResult.sent;
  }
}
