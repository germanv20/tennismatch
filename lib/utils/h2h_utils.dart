// Shared rules for head-to-head records between two registered players.
//
// Three places compute a head-to-head (`widgets/head_to_head_card.dart`,
// the full card in `screens/match_details_screen.dart`, and
// `services/h2h_service.dart`); keeping the rules here stops them drifting
// apart again.

/// Whether a completed match belongs in a 1v1 head-to-head record.
///
/// Doubles matches are excluded. Since linked doubles (v1.4.25) a doubles
/// match lists every linked registered player in `players`, so two users who
/// were partners — or opponents — in a doubles match both appear in it. But
/// doubles store a winning *team* (`winnerTeam`), not a `winnerUid`, so
/// counting them added to "matches played" without adding a win, loss or tie
/// (e.g. "2 matches played" with a 1-0 record).
bool countsForHeadToHead(Map<String, dynamic> match) {
  final type = match['type'] as String? ?? 'regular';
  return type != 'doubles_guest';
}

/// The real UID of the winner of a 1v1 match, or `null` when it can't be
/// attributed (a tie is handled by the caller via `isTie`).
///
/// For claimed guest matches `winnerUid` is the placeholder `'guest'` when the
/// non-creator won, so the win is attributed to whichever player is not
/// `createdBy` — same handling as `match_history_screen.dart`.
String? headToHeadWinner(Map<String, dynamic> match, List<String> players) {
  final winner = match['winnerUid'] as String?;
  if (winner == null || winner.isEmpty) return null;
  if (winner == 'guest') {
    final createdBy = match['createdBy'] as String?;
    final other = players.firstWhere((u) => u != createdBy, orElse: () => '');
    return other.isEmpty ? null : other;
  }
  return winner;
}
