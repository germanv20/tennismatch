import 'package:flutter/material.dart';

class MatchDetailsScreen extends StatelessWidget {

  final String playerName;
  final String opponentName;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;

  const MatchDetailsScreen({
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Match Details"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "$playerName vs $opponentName",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Sets",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...sets.asMap().entries.map((entry) {

              final index = entry.key;
              final set = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "Set ${index + 1}: ${set['p1']} - ${set['p2']}",
                  style: const TextStyle(fontSize: 16),
                ),
              );

            }),

            const SizedBox(height: 20),

            Text("Location: $location"),
            Text("Duration: $duration min"),
            Text(
              "Date: ${matchDate.day}/${matchDate.month}/${matchDate.year}",
            ),

          ],
        ),
      ),
    );
  }
}
