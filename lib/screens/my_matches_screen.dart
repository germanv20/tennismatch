import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/widgets/error_state.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'match_detail_screen.dart';
import '../widgets/empty_state.dart';
import '../main.dart';

class MyMatchesScreen extends StatefulWidget {
  final User currentUser;

  const MyMatchesScreen({super.key, required this.currentUser});

  @override
  State<MyMatchesScreen> createState() => _MyMatchesScreenState();
}

class _MyMatchesScreenState extends State<MyMatchesScreen> {

  bool showCompletedSnackbar = false;

    @override
    void initState() {
      super.initState();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        markMatchesAsSeen(widget.currentUser.uid);
      });
    }

  Future<void> markMatchesAsSeen(String userId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userId)
        .where('status', whereIn: ['pending', 'confirmed'])
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {
        'notifiedPlayers': FieldValue.arrayUnion([userId]),
      });
    }

    await batch.commit();
  }
  

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final matchesRef = FirebaseFirestore.instance.collection('matches');

    if (showCompletedSnackbar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.matchCompleted)),
        );
      });

      showCompletedSnackbar = false;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myMatchesTitle), // 'My Matches'
      ),
      body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
          stream: matchesRef
              .where('players', arrayContains: widget.currentUser.uid)
              .where('status', whereIn: ['pending', 'confirmed'])
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
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: SizedBox(
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ),
                        ),
                      );
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Card(
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
                          title: Text(
                            userData['name'] ?? loc.unknown,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ), // 'Unknown'
                          subtitle: Text(loc.matchActive), // 'Match active'
                          trailing: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('matches')
                                .doc(match.id)
                                .collection('messages')
                                .snapshots(),
                            builder: (context, msgSnapshot) {

                              int unreadCount = 0;

                              if (msgSnapshot.hasData) {
                                final currentUid = widget.currentUser.uid;

                                unreadCount = msgSnapshot.data!.docs.where((doc) {
                                  final msg = doc.data() as Map<String, dynamic>;

                                  if (msg['senderUid'] == currentUid) return false;

                                  final readBy = Map<String, dynamic>.from(msg['readBy'] ?? {});
                                  return readBy[currentUid] != true;
                                }).length;
                              }

                              final hasUnread = unreadCount > 0;

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasUnread)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),

                                  const Icon(Icons.sports_tennis),
                                ],
                              );
                            },
                          ),
                          onTap: () async {
                            final message = AppLocalizations.of(context)!.matchCancelled;
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchDetailScreen(
                                  matchDoc: match,
                                  opponentData: userData,
                                ),
                              ),
                            );

                            if (result == true) {
                              setState(() {
                                showCompletedSnackbar = true;
                              });
                            }

                            debugPrint("👉 Match detail result: $result");

                            if (result == 'cancelled') {
                              debugPrint("🔥 Showing cancel snackbar");

                              rootScaffoldMessengerKey.currentState?.clearSnackBars();
                              rootScaffoldMessengerKey.currentState?.showSnackBar(
                                SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text(message),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
