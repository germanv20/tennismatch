import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'match_chat_screen.dart';
import 'add_match_result_screen.dart';
import 'package:tennismatch/services/h2h_service.dart';


class MatchDetailScreen extends StatelessWidget {
  final DocumentSnapshot matchDoc;
  final Map<String, dynamic> opponentData;

  const MatchDetailScreen({
    super.key,
    required this.matchDoc,
    required this.opponentData,
  });

  String translateStatus(String status, AppLocalizations loc) {
    switch (status) {
      case 'pending':
        return loc.statusPending;
      case 'confirmed':
        return loc.statusConfirmed;
      case 'completed':
        return loc.statusCompleted;
      case 'cancelled':
        return loc.statusCancelled;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final data = matchDoc.data() as Map<String, dynamic>? ?? {};

    // Use 'uid' field if present, otherwise derive from match players array
    // This handles both old documents (without uid field) and new ones
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final players = List<String>.from(data['players'] ?? []);
    final derivedOpponentUid = players.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );

    final String otherPlayerUid =
        (opponentData['uid'] as String?)?.isNotEmpty == true
            ? opponentData['uid'] as String
            : derivedOpponentUid;

    final String otherPlayerName = opponentData['name'] as String? ?? loc.unknown;
    final String otherPlayerPhotoUrl = opponentData['photoUrl'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.unmatchTitle),
                  content: Text(loc.unmatchConfirmation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(loc.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(loc.unmatch),
                    ),
                  ],
                ),
              );

              if (!context.mounted) return;

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(matchDoc.id)
                    .update({'status': 'cancelled'});

                await H2HService.recalculateHeadToHead(
                  userA: currentUid,
                  userB: otherPlayerUid,
                );

                if (!context.mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, 'cancelled');
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Opponent header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: otherPlayerPhotoUrl.isNotEmpty
                          ? NetworkImage(otherPlayerPhotoUrl)
                          : null,
                      child: otherPlayerPhotoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      otherPlayerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  '${loc.statusLabel}: ${translateStatus(data['status'] as String? ?? '', loc)}',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 8),

                if (data['createdAt'] != null)
                  Text(
                    '${loc.createdAtLabel}: ${(data['createdAt'] as Timestamp).toDate()}',
                    style: const TextStyle(color: Colors.grey),
                  ),

                const SizedBox(height: 30),
                const Divider(),

                // ── Open Chat button with unread badge ──
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('matches')
                      .doc(matchDoc.id)
                      .collection('messages')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = 0;

                    if (snapshot.hasData) {
                      unreadCount = snapshot.data!.docs.where((doc) {
                        final msg = doc.data() as Map<String, dynamic>;
                        if (msg['senderUid'] == currentUid) return false;
                        final readBy = Map<String, dynamic>.from(
                          msg['readBy'] ?? {},
                        );
                        return readBy[currentUid] != true;
                      }).length;
                    }

                    final hasUnread = unreadCount > 0;

                    return Stack(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: Text(loc.openChat),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchChatScreen(
                                  matchId: matchDoc.id,
                                  otherPlayerUid: otherPlayerUid,
                                  otherPlayerName: otherPlayerName,
                                  otherPlayerPhotoUrl: otherPlayerPhotoUrl,
                                ),
                              ),
                            );
                          },
                        ),
                        if (hasUnread)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
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
                          ),
                      ],
                    );
                  },
                ),

                // ── Add Match Result button ──
                if (data['status'] != 'completed' &&
                    data['status'] != 'cancelled') ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: Text(loc.addMatchResult),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMatchResultScreen(
                            matchId: matchDoc.id,
                            matchData: data,
                          ),
                        ),
                      );
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                ],

                // ── Completed match result ──
                if (data['status'] == 'completed' &&
                    data['result'] != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.matchResult,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    (data['result']['sets'] as List).length,
                    (index) {
                      final set = data['result']['sets'][index];
                      return Text(
                        '${loc.setLabel(index + 1)}: ${set['p1']} - ${set['p2']}',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text('${loc.locationLabel}: ${data['result']['location']}'),
                  Text('${loc.durationLabel}: ${data['result']['durationMinutes']} min'),
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}