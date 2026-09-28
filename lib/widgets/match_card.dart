import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/match_details_screen.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/scoring_mode_utils.dart';

class MatchCard extends StatelessWidget {

  final String playerName;
  final String opponentName;
  final String opponentUid;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final String winnerUid;
  final String currentUserUid;
  final String matchId;
  final List players;
  final bool hasDeleteRequest;
  final Map<String, dynamic>? deletionRequest;
  final bool isTie;
  final String? notes;
  final String? scoringMode;

  const MatchCard({
    super.key,
    required this.matchId,
    required this.players,
    required this.playerName,
    required this.opponentName,
    required this.opponentUid,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
    required this.winnerUid,
    required this.currentUserUid,
    required this.hasDeleteRequest,
    required this.deletionRequest,
    this.isTie = false,
    this.notes,
    this.scoringMode,
  });

  Widget? buildDeletionStatus(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dr = deletionRequest;
    if (dr == null) return null;

    final status = dr['status'];
    final isRequester = dr['requestedBy'] == currentUserUid;

    String text = '';
    Color bgColor = Colors.grey;

    if (status == 'pending') {
      text = isRequester
          ? loc.waitingOpponentApproval
          : loc.opponentRequestedDeletion;
      bgColor = Colors.orange.shade100;
    } else if (status == 'accepted') {
      text = isRequester
          ? loc.deletionAccepted
          : loc.youAcceptedDeletion;
      bgColor = Colors.green.shade100;
    } else if (status == 'rejected') {
      text = isRequester
          ? loc.deletionRejected
          : loc.youRejectedDeletion;
      bgColor = Colors.red.shade100;
    } else {
      return null;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  /// A small "Not rated yet" pill shown while the signed-in viewer hasn't
  /// yet submitted a `matches/{matchId}/ratings/{currentUserUid}` doc for
  /// this (regular, completed) match — the History-screen counterpart to
  /// the one-shot rate-opponent push notification, so the reminder doesn't
  /// disappear if that notification is missed or dismissed. Live
  /// `StreamBuilder` (not a one-off fetch) so the pill disappears on its
  /// own the moment a rating is submitted from the detail screen and the
  /// user navigates back here, with no manual refresh. Every match this
  /// card renders is already a completed regular match (see
  /// match_history_screen.dart's `_buildRegularMatchCard`, the only call
  /// site), so no extra type/status gating is needed here.
  Widget _buildNotRatedBadge(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .doc(matchId)
          .collection('ratings')
          .doc(currentUserUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.exists) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_border, size: 14, color: Colors.amber.shade800),
              const SizedBox(width: 4),
              Text(
                loc.notRatedYetBadge,
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    final loc = AppLocalizations.of(context)!;

    final bool isWin = !isTie && winnerUid == currentUserUid;
    final bool isLoss = !isTie && winnerUid != currentUserUid;

    // Badge: grey TIE, green WIN, or red LOSS
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isTie
            ? Colors.grey[600]
            : isWin ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isTie ? loc.tieMatchLabel
            : isWin ? loc.win : loc.loss,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );

    // No trophy shown for ties
    final bool viewerWon = isWin;
    final bool opponentWon = isLoss && winnerUid != currentUserUid
        ? false
        : !isTie && !isWin;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(
              matchId: matchId,
              players: players,
              playerName: playerName,
              opponentName: opponentName,
              opponentUid: opponentUid,
              sets: sets,
              location: location,
              duration: duration,
              matchDate: matchDate,
              notes: notes,
              scoringMode: scoringMode,
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          children: [

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 35, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Player 1 row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            playerName,
                            style: TextStyle(
                              fontWeight: viewerWon
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (viewerWon) ...[
                            const SizedBox(width: 4),
                            const Text('🏆'),
                          ],
                        ],
                      ),
                      Row(
                        children: sets.map<Widget>((set) {
                          final p1 = set['p1'];
                          final p2 = set['p2'];
                          final bool wonSet = p1 > p2;
                          // Fixed-width cell (not just horizontal padding)
                          // so a 1-digit score in one player's row and a
                          // 2-digit score in the same set for the other
                          // player's row still occupy the same column
                          // width — otherwise the two rows' number groups
                          // (each right-anchored via spaceBetween) drift
                          // out of vertical alignment whenever their total
                          // digit counts differ.
                          return SizedBox(
                            width: 26,
                            child: Text(
                              p1.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                fontWeight: wonSet
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: wonSet
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Player 2 row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            opponentName,
                            style: TextStyle(
                              fontWeight: opponentWon
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (opponentWon) ...[
                            const SizedBox(width: 4),
                            const Text('🏆'),
                          ],
                        ],
                      ),
                      Row(
                        children: sets.map<Widget>((set) {
                          final p1 = set['p1'];
                          final p2 = set['p2'];
                          final bool wonSet = p2 > p1;
                          // Same fixed-width cell as player 1's row above,
                          // and the same font (was 'monospace' here vs. the
                          // default font + tabularFigures above — a font
                          // mismatch between the two rows compounded the
                          // digit-width misalignment).
                          return SizedBox(
                            width: 26,
                            child: Text(
                              p2.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                                fontWeight: wonSet
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: wonSet
                                    ? Colors.green.shade700
                                    : Colors.grey,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    '$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scoringModeDisplayLabel(scoringMode, loc),
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  _buildNotRatedBadge(context),

                  if (buildDeletionStatus(context) != null)
                    buildDeletionStatus(context)!,
                ],
              ),
            ),

            // WIN/LOSS/TIE badge
            Positioned(
              top: 8,
              right: 8,
              child: badge,
            ),

            // Delete notification badge
            if (hasDeleteRequest)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notification_important,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),

            // Tap hint chevron — signals the card is tappable
            Positioned(
              bottom: 8,
              right: 8,
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: Colors.grey[400],
              ),
            ),

          ],
        ),
      ),
    );
  }
}