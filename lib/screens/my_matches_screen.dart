import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/widgets/error_state.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'match_detail_screen.dart';
import '../widgets/empty_state.dart';

class MyMatchesScreen extends StatefulWidget {
  final User currentUser;

  const MyMatchesScreen({super.key, required this.currentUser});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {

    @override
    void initState() {
      super.initState();
      markMatchesAsSeen(widget.currentUser.uid);
    }

  Future<void> markMatchesAsSeen(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userId)
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final notified = List<String>.from(data['notifiedPlayers'] ?? []);

      if (!notified.contains(userId)) {
        notified.add(userId);

        await doc.reference.update({
          'notifiedPlayers': notified,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final matchesRef = FirebaseFirestore.instance.collection('matches');

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myMatchesTitle), // 'My Matches'
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: matchesRef
            .where('players', arrayContains: widget.currentUser.uid)
            .where('status', isEqualTo: 'active')
            .orderBy('lastMessageTime', descending: true)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              message: loc.failedToLoadMatches, // "Failed to load matches"
            );
          }

          if (!snapshot.hasData) {
            return EmptyState(
              icon: Icons.calendar_today,
              title: loc.noMatchesFound, // "No matches found"
              subtitle: loc.refreshOrTryLater, // "Try refreshing or check again later"
            );
          }

          final allMatches = snapshot.data!.docs;


          if (allMatches.isEmpty) {
            return EmptyState(
              icon: Icons.sports_tennis,
              title: loc.noActiveMatches, // "No active matches"
              subtitle: loc.startByFindingPlayer, // "Start by finding a player to play with 🎾"
            );
          }

          return ListView.builder(
            itemCount: allMatches.length,
            itemBuilder: (context, index) {
              final match = allMatches[index];
              final data = match.data() as Map<String, dynamic>;

              final players = List<String>.from(data['players'] ?? []);
              final opponentUid =
                  players.firstWhere((uid) => uid != widget.currentUser.uid,
                  orElse: () => '',
              );


              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(opponentUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.hasError) {
                    return ListTile(
                      title: Text(loc.failedToLoadOpponent), // 'Failed to load opponent'
                    );
                  }
                  if (!userSnapshot.hasData) {
                    return ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text(loc.loading), // 'Loading...'
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
                      title: Text(userData['name'] ?? loc.unknown), // 'Unknown'
                      subtitle: Text(loc.matchActive), // 'Match active'
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('matches')
                                .doc(match.id)
                                .collection('messages')
                                .where('senderUid', isNotEqualTo: widget.currentUser.uid)
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
                                if (readBy[widget.currentUser.uid] != true) {
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
