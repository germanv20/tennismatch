import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/name_utils.dart';

/// Compact head-to-head record between the signed-in user and
/// [opponentUid], shown where the decision to play someone happens
/// (Player Profile, scheduled/pending match detail) instead of only deep
/// inside a completed match's detail screen.
///
/// Computed live from completed matches (same approach as
/// `match_details_screen.dart`'s full card) rather than from the stored
/// `users/{uid}/headToHead/{opponentId}` aggregate, which has no ties and
/// can be stale. Renders nothing while loading, on error, or when the two
/// players have never completed a match together — a "0 matches" card would
/// just be noise.
class HeadToHeadCard extends StatefulWidget {
  final String opponentUid;

  /// Opponent's display name, shown on the right side of the scoreboard
  /// (first name only, title-cased). Falls back to nothing if empty.
  final String opponentName;

  const HeadToHeadCard({
    super.key,
    required this.opponentUid,
    this.opponentName = '',
  });

  @override
  State<HeadToHeadCard> createState() => _HeadToHeadCardState();
}

class _H2HRecord {
  final int matches;
  final int wins;
  final int losses;
  final int ties;
  const _H2HRecord(this.matches, this.wins, this.losses, this.ties);
}

class _HeadToHeadCardState extends State<HeadToHeadCard> {
  late Future<_H2HRecord> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(HeadToHeadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opponentUid != widget.opponentUid) {
      _future = _load();
    }
  }

  Future<_H2HRecord> _load() async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final opponent = widget.opponentUid;

    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: me)
        .where('status', isEqualTo: 'completed')
        .get();

    int matches = 0, wins = 0, losses = 0, ties = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final players = List<String>.from(data['players'] ?? const []);
      if (!players.contains(opponent)) continue;

      matches++;
      if (data['isTie'] == true) {
        ties++;
        continue;
      }

      String? winner = data['winnerUid'] as String?;
      if (winner == 'guest') {
        // Claimed guest match won by the non-creator: 'guest' is a
        // placeholder, so attribute the win via createdBy (same handling
        // as h2h_service.dart / match_history_screen.dart).
        final createdBy = data['createdBy'] as String?;
        winner = players.firstWhere((u) => u != createdBy, orElse: () => '');
      }

      if (winner == me) {
        wins++;
      } else if (winner == opponent) {
        losses++;
      }
    }

    return _H2HRecord(matches, wins, losses, ties);
  }

  /// One side of the scoreboard: player name above a large win count.
  /// The leader's number is green; the other (or both, when level) stays
  /// neutral grey.
  Widget _side(String name, int wins, bool leading) {
    return Expanded(
      child: Column(
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '$wins',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: leading ? Colors.green.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opponentUid.isEmpty ||
        widget.opponentUid == FirebaseAuth.instance.currentUser?.uid) {
      return const SizedBox.shrink();
    }

    final loc = AppLocalizations.of(context)!;
    final formattedName = formatNameDisplay(widget.opponentName);
    final opponentFirstName =
        formattedName.isEmpty ? '' : formattedName.split(' ').first;

    return FutureBuilder<_H2HRecord>(
      future: _future,
      builder: (context, snapshot) {
        final record = snapshot.data;
        if (record == null || record.matches == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.compare_arrows, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          loc.headToHead,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // ATP-style scoreboard: my wins | "Wins" | their wins.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _side(loc.you, record.wins, record.wins > record.losses),
                        SizedBox(
                          width: 92,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: Column(
                              children: [
                                Text(
                                  loc.wins,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${record.matches} ${loc.matchesPlayed}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                                if (record.ties > 0)
                                  Text(
                                    '${record.ties} ${loc.ties}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        _side(
                          opponentFirstName.isEmpty
                              ? loc.unknown
                              : opponentFirstName,
                          record.losses,
                          record.losses > record.wins,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
