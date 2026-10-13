import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/achievements_utils.dart';

/// Loads the signed-in user's completed matches and turns them into
/// [AchievementsData] (all computed on the device — nothing is stored in
/// Firestore; see CLAUDE.md). Also tracks which badges the user has already
/// been congratulated for, in SharedPreferences (per uid).
class AchievementsService {
  AchievementsService._();

  /// Cap on extra per-match reads (rating docs / opponent profiles).
  static const int _maxExtraReads = 25;

  static Future<AchievementsData> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return buildAchievements(
        matches: const [],
        now: DateTime.now(),
        ratingsGiven: 0,
        reputationRatingCount: 0,
        reputationAverage: 0,
        beatHigherRatedOpponent: false,
      );
    }
    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    final results = await Future.wait([
      db
          .collection('matches')
          .where('players', arrayContains: uid)
          .where('status', isEqualTo: 'completed')
          .get(),
      db.collection('users').doc(uid).get(),
    ]);
    final matchSnap = results[0] as QuerySnapshot<Map<String, dynamic>>;
    final meDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final me = meDoc.data() ?? {};

    final matches = <AchievementMatch>[];
    // For extra reads: (matchId, opponentUid, date) of regular matches.
    final regularRefs = <({String id, String opp, DateTime? date, int outcome})>[];

    for (final doc in matchSnap.docs) {
      final m = doc.data();
      final type = m['type'] as String? ?? 'regular';
      final isTie = m['isTie'] == true;
      int outcome = 0;
      if (!isTie) {
        bool won;
        if (type == 'doubles_guest') {
          won = (m['winnerTeam'] as int? ?? 0) == 1;
        } else if (type == 'guest') {
          final createdBy = m['createdBy'] as String? ?? '';
          final creatorWon = m['winnerUid'] == createdBy;
          won = createdBy == uid ? creatorWon : !creatorWon;
        } else {
          won = m['winnerUid'] == uid;
        }
        outcome = won ? 1 : -1;
      }

      final result = m['result'] as Map<String, dynamic>? ?? {};
      final summary = m['summary'] as Map<String, dynamic>? ?? {};
      final ts = summary['matchDate'] as Timestamp? ??
          result['matchDate'] as Timestamp? ??
          m['completedAt'] as Timestamp?;
      final date = ts?.toDate();

      final isRegular = type == 'regular';
      String? opp;
      if (isRegular) {
        final players = (m['players'] as List?)?.cast<String>() ?? const [];
        for (final p in players) {
          if (p != uid) opp = p;
        }
      }

      // Set-level feats. Guest matches may have the user as the guest
      // (claimant), so "my side" is p1 for creators / doubles, else p2.
      bool userIsP1;
      if (type == 'doubles_guest') {
        userIsP1 = true;
      } else if (type == 'guest') {
        userIsP1 = (m['createdBy'] as String? ?? '') == uid;
      } else {
        userIsP1 = (m['player1Uid'] as String?) == uid;
      }
      bool bagel = false;
      bool tbWon = false;
      for (final s in (result['sets'] as List? ?? const [])) {
        final sm = s as Map<String, dynamic>? ?? {};
        final p1 = (sm['p1'] ?? 0) as int;
        final p2 = (sm['p2'] ?? 0) as int;
        final mine = userIsP1 ? p1 : p2;
        final theirs = userIsP1 ? p2 : p1;
        if (mine > theirs) {
          if (mine == 6 && theirs == 0) bagel = true;
          if (sm['tb1'] != null && sm['tb2'] != null) tbWon = true;
        }
      }

      matches.add(AchievementMatch(
        date: date,
        outcome: outcome,
        opponentUid: opp,
        isRegular: isRegular && opp != null,
        wonBagel: bagel,
        wonTiebreak: tbWon,
      ));
      if (isRegular && opp != null) {
        regularRefs
            .add((id: doc.id, opp: opp, date: date, outcome: outcome));
      }
    }

    // Newest regular matches first for the capped extra reads.
    regularRefs.sort((a, b) => (b.date ?? DateTime(1970))
        .compareTo(a.date ?? DateTime(1970)));

    // Has the user ever rated an opponent? (ratings/{myUid} per match)
    int ratingsGiven = 0;
    final toCheck = regularRefs.take(_maxExtraReads).toList();
    final ratingDocs = await Future.wait([
      for (final r in toCheck)
        db
            .collection('matches')
            .doc(r.id)
            .collection('ratings')
            .doc(uid)
            .get(),
    ]);
    ratingsGiven = ratingDocs.where((d) => d.exists).length;

    // Giant killer: a win over a regular opponent whose current ranking
    // score is >= giantKillerEloGap above mine (both rated).
    bool giant = false;
    final myElo = (me['eloRating'] as num?)?.toDouble() ?? 1200;
    if (((me['eloMatchesPlayed'] as num?) ?? 0) > 0) {
      final wonAgainst = <String>{
        for (final r in regularRefs)
          if (r.outcome == 1) r.opp,
      }.take(_maxExtraReads).toList();
      final oppDocs = await Future.wait([
        for (final o in wonAgainst) db.collection('users').doc(o).get(),
      ]);
      for (final d in oppDocs) {
        final data = d.data();
        if (data == null) continue;
        if (((data['eloMatchesPlayed'] as num?) ?? 0) <= 0) continue;
        final elo = (data['eloRating'] as num?)?.toDouble() ?? 1200;
        if (elo - myElo >= giantKillerEloGap) {
          giant = true;
          break;
        }
      }
    }

    final repCount = (me['reputationRatingCount'] as num?)?.toInt() ?? 0;
    final repSum = (me['reputationRatingSum'] as num?)?.toDouble() ?? 0;

    return buildAchievements(
      matches: matches,
      now: DateTime.now(),
      ratingsGiven: ratingsGiven,
      reputationRatingCount: repCount,
      reputationAverage: repCount > 0 ? repSum / repCount : 0,
      beatHigherRatedOpponent: giant,
    );
  }

  static String _seenKey(String uid) => 'seen_achievements_$uid';

  /// Badge ids unlocked now but not yet celebrated. On the very first call
  /// for a user (no stored list) the current unlocks are recorded silently
  /// as the baseline, so existing users aren't flooded with celebrations
  /// for things they did before this feature existed.
  static Future<List<String>> takeUnseen(AchievementsData data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const [];
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_seenKey(uid));
    final unlocked = data.unlockedIds;
    if (stored == null) {
      await prefs.setStringList(_seenKey(uid), unlocked.toList());
      return const [];
    }
    return unlocked.where((id) => !stored.contains(id)).toList();
  }

  static Future<void> markSeen(Iterable<String> ids) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_seenKey(uid)) ?? <String>[];
    final merged = {...stored, ...ids}.toList();
    await prefs.setStringList(_seenKey(uid), merged);
  }
}
