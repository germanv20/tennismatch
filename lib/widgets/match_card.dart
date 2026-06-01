import 'package:flutter/material.dart';
import '../screens/match_details_screen.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

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
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              p1.toString(),
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              p2.toString(),
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'monospace',
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

          ],
        ),
      ),
    );
  }
}