import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerStatisticsScreen extends StatefulWidget {
  const PlayerStatisticsScreen({super.key});

  @override
  State<PlayerStatisticsScreen> createState() => _PlayerStatisticsScreenState();
}

class _PlayerStatisticsScreenState extends State<PlayerStatisticsScreen> {

  int matchesPlayed = 0;
  int wins = 0;
  int losses = 0;
  double winRate = 0;
  int averageDuration = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats() async {

    final uid = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: uid)
        .where('status', isEqualTo: 'completed')
        .get();

    int totalDuration = 0;

    for (var doc in snapshot.docs) {

      final match = doc.data();

      matchesPlayed++;

      if (match['winnerUid'] == uid) {
        wins++;
      } else {
        losses++;
      }

      final result = match['result'] ?? {};
      final duration = (result['durationMinutes'] ?? 0) as num;

      totalDuration += duration.toInt();

    }

    if (matchesPlayed > 0) {
      winRate = (wins / matchesPlayed) * 100;
      averageDuration = (totalDuration / matchesPlayed).round();
    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Player Statistics")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            StatTile("Matches Played", matchesPlayed.toString()),
            StatTile("Wins", wins.toString()),
            StatTile("Losses", losses.toString()),
            StatTile("Win Rate", "${winRate.toStringAsFixed(1)}%"),
            StatTile("Average Match Duration", "$averageDuration min"),

          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {

  final String label;
  final String value;

  const StatTile(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}