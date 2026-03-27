import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

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

    if (!mounted) return;

    setState(() {
      loadingH2H = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    final loc = AppLocalizations.of(context)!;

    int playerSetsWon = 0;
    int opponentSetsWon = 0;

    for (var set in widget.sets) {
      if (set['p1'] > set['p2']) {
        playerSetsWon++;
      } else {
        opponentSetsWon++;
      }
    }

    final bool playerWon = playerSetsWon > opponentSetsWon;

    final winnerName = playerWon ? widget.playerName : widget.opponentName;
    final loserName = playerWon ? widget.opponentName : widget.playerName;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle), // "Match Details"
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  loc.result, // "Result"
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    children: [
                      TextSpan(
                        text: loc.matchResultSentence(winnerName, loserName),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [

                        // Header row (SET1 SET2 SET3...)
                        Row(
                          children: [
                            const SizedBox(width: 120),
                            ...widget.sets.asMap().entries.map((entry) {
                              final index = entry.key;

                              return Expanded(
                                child: Center(
                                  child: Text(
                                    loc.setLabel(index + 1),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Player 1 row
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(widget.playerName),
                            ),
                            ...widget.sets.map((set) {

                              final p1 = set['p1'];
                              final p2 = set['p2'];
                              final isWinner = p1 > p2;

                              return Expanded(
                                child: Center(
                                  child: Text(
                                    p1.toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                      color: isWinner ? Colors.black : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Player 2 row
                        Row(
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(widget.opponentName),
                            ),
                            ...widget.sets.map((set) {

                              final p1 = set['p1'];
                              final p2 = set['p2'];
                              final isWinner = p2 > p1;

                              return Expanded(
                                child: Center(
                                  child: Text(
                                    p2.toString(),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                      color: isWinner ? Colors.black : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),

                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  '${loc.locationLabel}: ${widget.location}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${loc.durationLabel}: ${widget.duration} ${loc.minutesShort}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${loc.dateLabel}: ${widget.matchDate.day}/${widget.matchDate.month}/${widget.matchDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 30),

                Text(
                  loc.headToHead, // "Head-to-Head"
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                loadingH2H
                  ? const Center(child: CircularProgressIndicator())
                    : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.headToHead), // Matches
                                  Text(h2hMatches.toString()),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.wins), // "Wins"
                                  Text(h2hWins.toString()),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.losses), // "Losses"
                                  Text(h2hLosses.toString()),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.totalSetsWon), // "Sets Won"
                                  Text(h2hSetsWon.toString()),
                                ],
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(loc.totalSetsLost), // "Sets Lost"
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
        ),
      ),
    );
  }
}