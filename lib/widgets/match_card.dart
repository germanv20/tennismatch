import 'package:flutter/material.dart';
import '../screens/match_details_screen.dart';

class MatchCard extends StatelessWidget {

  final String playerName;
  final String opponentName;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;

  const MatchCard({
    super.key,
    required this.playerName,
    required this.opponentName,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
  });

  @override
  Widget build(BuildContext context) {

    int p1Sets = 0;
    int p2Sets = 0;

    for (var set in sets) {
      if (set['p1'] > set['p2']) {
        p1Sets++;
      } else {
        p2Sets++;
      }
    }

    bool p1Won = p1Sets > p2Sets;
    bool p2Won = p2Sets > p1Sets;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailsScreen(
              playerName: playerName,
              opponentName: opponentName,
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
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                              fontWeight: p1Won ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (p1Won) const SizedBox(width: 4),
                          if (p1Won) const Text("🏆"),
                        ],
                      ),

                      Text(
                        sets.map((s) => s['p1'].toString()).join("  "),
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
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
                              fontWeight: p2Won ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (p2Won) const SizedBox(width: 4),
                          if (p2Won) const Text("🏆"),
                        ],
                      ),

                      Text(
                        sets.map((s) => s['p2'].toString()).join("  "),
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: 'monospace',
                        ),
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
          ),
      );
    }
  }
  