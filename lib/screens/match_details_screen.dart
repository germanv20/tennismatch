import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDetailsScreen extends StatefulWidget {

  final String playerName;
  final String opponentName;
  final String opponentUid;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;

  const MatchDetailsScreen({
    super.key,
    required this.playerName,
    required this.opponentName,
    required this.opponentUid,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {

  int h2hMatches = 0;
  int h2hWins = 0;
  int h2hLosses = 0;
  int h2hSetsWon = 0;
  int h2hSetsLost = 0;

  bool loadingH2H = true;

  @override
  void initState() {
    super.initState();
    loadHeadToHead();
  }

  Future<void> loadHeadToHead() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('headToHead')
        .doc(widget.opponentUid)
        .get();

    if (doc.exists) {

      final data = doc.data()!;

      h2hMatches = data['matches'] ?? 0;
      h2hWins = data['wins'] ?? 0;
      h2hLosses = data['losses'] ?? 0;
      h2hSetsWon = data['setsWon'] ?? 0;
      h2hSetsLost = data['setsLost'] ?? 0;
    }

    setState(() {
      loadingH2H = false;
    });
  }

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
              "${widget.playerName} vs ${widget.opponentName}",
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

            ...widget.sets.asMap().entries.map((entry) {

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

            Text("Location: ${widget.location}"),
            Text("Duration: ${widget.duration} min"),
            Text(
              "Date: ${widget.matchDate.day}/${widget.matchDate.month}/${widget.matchDate.year}",
            ),

            const SizedBox(height: 30),

            const Text(
              "Head-to-Head",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            loadingH2H
                ? const CircularProgressIndicator()
                : Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Matches"),
                              Text(h2hMatches.toString()),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Wins"),
                              Text(h2hWins.toString()),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Losses"),
                              Text(h2hLosses.toString()),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Sets Won"),
                              Text(h2hSetsWon.toString()),
                            ],
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Sets Lost"),
                              Text(h2hSetsLost.toString()),
                            ],
                          ),

                        ],
                      ),
                    ),
                  ),

          ],
        ),
      ),
    );
  }
}