import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
String currentUserName = "";

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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Match History"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('players', arrayContains: FirebaseAuth.instance.currentUser!.uid)
            .where('status', isEqualTo: 'completed')
            .orderBy('completedAt', descending: true)
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
              final match = matches[index].data() as Map<String, dynamic>;

              final currentUid = FirebaseAuth.instance.currentUser!.uid;

              final List players = match['players'] ?? [];
              final result = match['result'] ?? {};
              final List<dynamic> sets = result['sets'] ?? [];
              final location = result['location'] ?? '';
              final duration = result['durationMinutes'] ?? 0;
              final Timestamp matchDateTs = result['matchDate'];
              final DateTime matchDate = matchDateTs.toDate();

              String score = sets
                  .map((set) => "${set['p1']}-${set['p2']}")
                  .join(" ");

              final opponentUid =
                  players.firstWhere((uid) => uid != currentUid);

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(opponentUid)
                    .get(),
              builder: (context, userSnapshot) {

                if (!userSnapshot.hasData) {
                  return const ListTile(
                    title: Text("Loading..."),
                  );
                }

                final userData =
                    userSnapshot.data!.data() as Map<String, dynamic>;

                final opponentName = userData['name'];

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

                return Card(
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
                                  currentUserName,
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
                          "$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • ${duration} min",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );

              },
              );

            },
          );
        },
      ),
    );
  }
}