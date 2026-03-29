import 'package:flutter/material.dart';
import '../screens/match_details_screen.dart';

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
  final bool currentUserIsP1;
  final String player1Uid;
  final String player2Uid;

  const MatchCard({
  super.key,
  required this.playerName,
  required this.opponentName,
  required this.opponentUid,
  required this.sets,
  required this.location,
  required this.duration,
  required this.matchDate,
  required this.winnerUid,
  required this.currentUserUid,
  required this.currentUserIsP1,
  required this.player1Uid,
  required this.player2Uid,
});

  @override
  Widget build(BuildContext context) {

    final bool isWin = winnerUid == currentUserUid;
    final bool viewerIsP1 = currentUserUid == player1Uid;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isWin ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isWin ? "WIN" : "LOSS",
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
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(
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

                                  final myScore = viewerIsP1 ? p1 : p2;
                                  final opponentScore = viewerIsP1 ? p2 : p1;

                                  final bool wonSet = myScore > opponentScore;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      myScore.toString(),
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

                              final myScore = viewerIsP1 ? p1 : p2;
                              final opponentScore = viewerIsP1 ? p2 : p1;

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

                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: badge,
                ),
              ],
            ),
        ),
    );
   }
}
      