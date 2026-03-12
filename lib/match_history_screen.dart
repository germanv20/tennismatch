import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/match_card.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {

  String currentUserName = "";

  @override
  void initState() {
    super.initState();
    loadCurrentUserName();
  }

  Future<void> loadCurrentUserName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    setState(() {
      currentUserName = doc['name'];
    });
  }

  @override
  Widget build(BuildContext context) {

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Match History"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: currentUid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(50)
          .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final matches = snapshot.data!.docs;

          if (matches.isEmpty) {
            return const Center(
              child: Text("No matches played yet"),
            );
          }

          return ListView.builder(
            itemCount: matches.length,
            itemBuilder: (context, index) {

              final match =
                  matches[index].data() as Map<String, dynamic>;

              final players = match['players'] ?? [];
              final playerNames = match['playerNames'] ?? {};

              final opponentUid =
                  players.firstWhere((uid) => uid != currentUid);

              final opponentName =
                  playerNames[opponentUid] ?? "Opponent";

              final summary = match['summary'] as Map<String, dynamic>? ?? {};

              final p1Sets = summary['p1Sets'] ?? 0;
              final p2Sets = summary['p2Sets'] ?? 0;

              // Safe match date handling
              Timestamp? matchDateTs = summary['matchDate'];

              if (matchDateTs == null) {
                matchDateTs = match['result']?['matchDate'];
              }

              final DateTime matchDate =
                  matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

              // Real sets for UI display
              final sets = match['result']?['sets'] ?? [];

              final location = match['result']?['location'] ?? '';
              final duration = match['result']?['durationMinutes'] ?? 0;


             return MatchCard(
                playerName: currentUserName,
                opponentName: opponentName,
                sets: sets,
                location: location,
                duration: duration,
                matchDate: matchDate,
                winnerUid: match['winnerUid'],
                currentUserUid: currentUid,
              );

            },
          );
        },
      ),
    );
  }
}
