import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'match_detail_screen.dart';

class MyMatchesScreen extends StatelessWidget {
  final User currentUser;

  const MyMatchesScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final matchesRef = FirebaseFirestore.instance.collection('matches');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Matches'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: matchesRef
            .where('status', isEqualTo: 'active')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No matches found.'));
          }

          final allMatches = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['player1Uid'] == currentUser.uid ||
                data['player2Uid'] == currentUser.uid;
          }).toList();

          if (allMatches.isEmpty) {
            return const Center(child: Text('You have no matches yet.'));
          }

          return ListView.builder(
            itemCount: allMatches.length,
            itemBuilder: (context, index) {
              final match = allMatches[index];
              final data = match.data() as Map<String, dynamic>;

              final opponentUid =
                  data['player1Uid'] == currentUser.uid
                      ? data['player2Uid']
                      : data['player1Uid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(opponentUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      title: Text('Loading opponent...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            NetworkImage(userData['photoUrl'] ?? ''),
                      ),
                      title: Text(userData['name'] ?? 'Unknown'),
                      subtitle: const Text('Match active'),
                      trailing: const Icon(Icons.sports_tennis),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchDetailScreen(
                              matchDoc: match,
                              opponentData: userData,
                            ),
                          ),
                        );
                      },
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
