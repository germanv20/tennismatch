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
          ? loc.waitingOpponentApproval //'Waiting for opponent approval...'
          : loc.opponentRequestedDeletion;//'Opponent requested match deletion'
      bgColor = Colors.orange.shade100;
    } else if (status == 'accepted') {
      text = isRequester
          ? loc.deletionAccepted//'Deletion request accepted'
          : loc.youAcceptedDeletion;//'You accepted the deletion request'
      bgColor = Colors.green.shade100;
    } else if (status == 'rejected') {
      text = isRequester
          ? loc.deletionRejected//'Deletion request rejected'
          : loc.youRejectedDeletion;//'You rejected the deletion request'
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

    final bool isWin = winnerUid == currentUserUid;

    final currentUid = currentUserUid;

    final dr = deletionRequest;

    final isRequester = dr != null && dr['requestedBy'] == currentUid;
    final status = dr != null ? dr['status'] : null;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isWin ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),

      child: Text(
        isWin ? loc.win : loc.loss,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );

    bool viewerWon = isWin;
    bool opponentWon = !isWin;

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
              opponentUid:  opponentUid, 
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

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Row(
                            children: [

                              Text(
                                playerName,
                                style: TextStyle(
                                  fontWeight: viewerWon ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),

                              if (viewerWon) const SizedBox(width: 4),
                              if (viewerWon) const Text("🏆"),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(), 
                              Row(
                                children: sets.map<Widget>((set) {

                                  final p1 = set['p1'];
                                  final p2 = set['p2'];

                                  final myScore = p1;
                                  final opponentScore = p2;

                                  final bool wonSet = myScore > opponentScore;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      myScore.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                        fontWeight: wonSet ? FontWeight.bold : FontWeight.normal,
                                        color: wonSet ? Colors.green.shade700 : Colors.grey,
                                      ),
                                    ),
                                  );

                                }).toList(),
                              ),
                            ],
                          ),

                        ]
                      ),

                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Row(
                            children: [
                              Text(
                                opponentName,
                                style: TextStyle(
                                  fontWeight: opponentWon ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (opponentWon) const SizedBox(width: 4),
                              if (opponentWon) const Text("🏆"),
                            ],
                          ),

                          Row(
                            children: sets.map<Widget>((set) {

                              final p1 = set['p1'];
                              final p2 = set['p2'];

                              final myScore = p1;
                              final opponentScore = p2;

                              final bool wonSet = opponentScore > myScore;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  opponentScore.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'monospace',
                                    fontWeight: wonSet ? FontWeight.bold : FontWeight.normal,
                                    color: wonSet ? Colors.green.shade700 : Colors.grey,
                                  ),
                                ),
                              );

                            }).toList(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      
                      if (buildDeletionStatus(context) != null)
                        buildDeletionStatus(context)!,
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: badge,
                ),

                if (hasDeleteRequest)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
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
      