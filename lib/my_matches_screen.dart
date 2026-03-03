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
            .where('players', arrayContains: currentUser.uid)
            .where('status', isEqualTo: 'active')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No matches found.'));
          }

          final allMatches = snapshot.data!.docs;
          print("Current UID: ${currentUser.uid}");
          print("Docs returned: ${snapshot.data!.docs.length}");


          if (allMatches.isEmpty) {
            return const Center(child: Text('You have no matches yet.'));
          }

          return ListView.builder(
            itemCount: allMatches.length,
            itemBuilder: (context, index) {
              final match = allMatches[index];
              final data = match.data() as Map<String, dynamic>;

              final players = List<String>.from(data['players']);
              final opponentUid =
                  players.firstWhere((uid) => uid != currentUser.uid);


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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('matches')
                                .doc(match.id)
                                .collection('messages')
                                .where('senderUid', isNotEqualTo: currentUser.uid)
                                .snapshots(),
                            builder: (context, messageSnapshot) {
                              if (!messageSnapshot.hasData) {
                                return const SizedBox();
                              }

                              int unreadCount = 0;

                              for (var doc in messageSnapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final readBy = Map<String, dynamic>.from(data['readBy'] ?? {});
                                if (readBy[currentUser.uid] != true) {
                                  unreadCount++;
                                }
                              }

                              if (unreadCount == 0) {
                                return const SizedBox();
                              }

                              return Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const Icon(Icons.sports_tennis),
                        ],
                      ),
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
