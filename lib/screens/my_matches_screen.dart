import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/widgets/error_state.dart';
import 'match_detail_screen.dart';
import '../widgets/empty_state.dart';

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

          if (snapshot.hasError) {
            return const ErrorState(
              message: "Failed to load matches",
            );
          }

          if (!snapshot.hasData) {
            return const EmptyState(
              icon: Icons.calendar_today,
              title: "No matches found",
              subtitle: "Try refreshing or check again later",
            );
          }

          final allMatches = snapshot.data!.docs;


          if (allMatches.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_tennis,
              title: "No active matches",
              subtitle: "Start by finding a player to play with 🎾",
            );
          }

          return ListView.builder(
            itemCount: allMatches.length,
            itemBuilder: (context, index) {
              final match = allMatches[index];
              final data = match.data() as Map<String, dynamic>;

              final players = List<String>.from(data['players'] ?? []);
              final opponentUid =
                  players.firstWhere((uid) => uid != currentUser.uid,
                  orElse: () => '',
              );


              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(opponentUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return const ListTile(
                      title: Text('Failed to load opponent'),
                    );
                  }
                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Loading...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (userData['photoUrl'] != null &&
                                userData['photoUrl'].toString().isNotEmpty)
                            ? NetworkImage(userData['photoUrl'])
                            : null,
                        child: userData['photoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
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

                              if (messageSnapshot.hasError){
                                return const SizedBox();
                              }

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
