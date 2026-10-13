import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/monthly_recap_utils.dart';
import 'achievements_service.dart';

/// Loads the signed-in user's completed matches and builds a
/// [MonthlyRecap]. Computed on-device, nothing stored in Firestore (see
/// CLAUDE.md). Also remembers which month's Home card was dismissed.
class MonthlyRecapService {
  MonthlyRecapService._();

  /// Home card is shown only during the first N days of a month.
  static const int homeCardDays = 7;

  static Future<MonthlyRecap> load(int year, int month) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final all = <RecapMatch>[];
    if (uid != null) {
      final snap = await FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: uid)
          .where('status', isEqualTo: 'completed')
          .get();
      for (final doc in snap.docs) {
        all.add(_toRecapMatch(doc.data(), uid));
      }
    }
    return buildMonthlyRecap(all: all, year: year, month: month);
  }

  /// Number of badges currently unlocked (for the recap's streak page).
  static Future<int> unlockedBadgeCount() async {
    try {
      final data = await AchievementsService.load();
      return data.unlockedIds.length;
    } catch (_) {
      return 0;
    }
  }

  static RecapMatch _toRecapMatch(Map<String, dynamic> m, String uid) {
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

    bool userIsP1;
    if (type == 'doubles_guest') {
      userIsP1 = true;
    } else if (type == 'guest') {
      userIsP1 = (m['createdBy'] as String? ?? '') == uid;
    } else {
      userIsP1 = (m['player1Uid'] as String?) == uid;
    }

    String? oppUid;
    String? oppName;
    if (type == 'regular') {
      final players = (m['players'] as List?)?.cast<String>() ?? const [];
      for (final p in players) {
        if (p != uid) oppUid = p;
      }
      oppName = (userIsP1 ? summary['p2Name'] : summary['p1Name']) as String?;
    }

    bool bagel = false, tbWon = false;
    int diff = 0;
    final parts = <String>[];
    for (final s in (result['sets'] as List? ?? const [])) {
      final sm = s as Map<String, dynamic>? ?? {};
      final p1 = (sm['p1'] ?? 0) as int;
      final p2 = (sm['p2'] ?? 0) as int;
      final mine = userIsP1 ? p1 : p2;
      final theirs = userIsP1 ? p2 : p1;
      diff += mine - theirs;
      parts.add('$mine-$theirs');
      if (mine > theirs) {
        if (mine == 6 && theirs == 0) bagel = true;
        if (sm['tb1'] != null && sm['tb2'] != null) tbWon = true;
      }
    }

    return RecapMatch(
      date: ts?.toDate(),
      outcome: outcome,
      durationMinutes: ((result['durationMinutes'] ?? 0) as num).toInt(),
      opponentUid: oppUid,
      opponentName: oppName,
      location: result['location'] as String?,
      wonBagel: bagel,
      wonTiebreak: tbWon,
      gameDiff: diff,
      scoreText: parts.join(', '),
    );
  }

  static String monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  static String _dismissKey(String uid) => 'recap_dismissed_$uid';

  static Future<bool> isDismissed(int year, int month) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_dismissKey(uid)) == monthKey(year, month);
  }

  static Future<void> dismiss(int year, int month) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissKey(uid), monthKey(year, month));
  }
}
