/// Helpers for doubles matches that can link registered players.
///
/// A `doubles_guest` match is stored from the CREATOR's point of view
/// (creator = team1.player1; `winnerTeam`/`result.sets` p1 = team 1). Other
/// registered players can be *linked* into one of the three other slots, in
/// which case their uid is in `players` and in `linkedPlayers`:
///
///   linkedPlayers: { team1Player2?: uid, team2Player1?: uid, team2Player2?: uid }
///
/// A linked player on team 2 must read the match flipped (their team first,
/// their sets/win), which is what [doublesForViewer] does.

const String slotTeam1Player2 = 'team1Player2';
const String slotTeam2Player1 = 'team2Player1';
const String slotTeam2Player2 = 'team2Player2';

/// Which team (1 or 2) [uid] played on. The creator, and anyone not found
/// in `linkedPlayers` (e.g. legacy matches), count as team 1.
int doublesViewerTeam(Map<String, dynamic> match, String uid) {
  if (match['createdBy'] == uid) return 1;
  final linked = match['linkedPlayers'];
  if (linked is Map) {
    for (final e in linked.entries) {
      if (e.value == uid) {
        return e.key.toString().startsWith('team2') ? 2 : 1;
      }
    }
  }
  return 1;
}

/// Whether [uid] won (false for ties and losses).
bool doublesViewerWon(Map<String, dynamic> match, String uid) {
  if (match['isTie'] == true) return false;
  final winnerTeam = match['winnerTeam'] as int? ?? 0;
  return winnerTeam == doublesViewerTeam(match, uid);
}

/// The match as seen by [uid]: if they're on team 2, team1/team2, winnerTeam
/// and every set's p1/p2 (and tb1/tb2) are swapped so "team 1" is always the
/// viewer's own team. Returns [match] untouched for team-1 viewers.
Map<String, dynamic> doublesForViewer(Map<String, dynamic> match, String uid) {
  if (doublesViewerTeam(match, uid) == 1) return match;

  final out = Map<String, dynamic>.from(match);
  out['team1'] = match['team2'];
  out['team2'] = match['team1'];
  final wt = match['winnerTeam'];
  if (wt is int) out['winnerTeam'] = wt == 1 ? 2 : 1;

  final result = match['result'];
  if (result is Map) {
    final r = Map<String, dynamic>.from(result);
    final sets = result['sets'];
    if (sets is List) {
      r['sets'] = [
        for (final s in sets)
          if (s is Map)
            {
              ...s.map((k, v) => MapEntry(k.toString(), v)),
              'p1': s['p2'],
              'p2': s['p1'],
              if (s.containsKey('tb1') || s.containsKey('tb2')) 'tb1': s['tb2'],
              if (s.containsKey('tb1') || s.containsKey('tb2')) 'tb2': s['tb1'],
            }
          else
            s,
      ];
    }
    out['result'] = r;
  }
  return out;
}
