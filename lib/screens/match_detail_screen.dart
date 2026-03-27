import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'match_chat_screen.dart';
import 'add_match_result_screen.dart';




class MatchDetailScreen extends StatelessWidget {
  final DocumentSnapshot matchDoc;
  final Map<String, dynamic> opponentData;

  const MatchDetailScreen({
    super.key,
    required this.matchDoc,
    required this.opponentData,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final data = matchDoc.data() as Map<String, dynamic>? ?? {};
    final String otherPlayerUid = opponentData['uid'];
    final String otherPlayerName = opponentData['name'] ?? loc.unknown; // 'Player'
    final String otherPlayerPhotoUrl = opponentData['photoUrl'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle), // 'Match Details'
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.unmatchTitle), // 'Unmatch?'
                  content: Text(
                      loc.unmatchConfirmation), // 'Are you sure you want to unmatch? This will remove the chat.'
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(loc.cancel), // 'Cancel'
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(loc.unmatch), // 'Unmatch'
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(matchDoc.id)
                    .update({
                  'status': 'cancelled',
                });

                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } // Exit chat screen
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
                      backgroundImage: (opponentData['photoUrl'] != null &&
                              opponentData['photoUrl'].toString().isNotEmpty)
                          ? NetworkImage(opponentData['photoUrl'])
                          : null,
                      child: opponentData['photoUrl'] == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      opponentData['name'] ?? loc.unknown, // 'Unknown'
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  '${loc.statusLabel}: ${data['status']}', // Status
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

                ElevatedButton.icon(
                  icon: const Icon(Icons.chat),
                  label: Text(loc.openChat), // 'Open Chat'
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

                const SizedBox(height: 10),

                if (data['status'] == 'active') ...[
                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: Text(loc.addMatchResult), // 'Add Match Result'
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMatchResultScreen(
                            matchId: matchDoc.id,
                            matchData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ],

                if (data['status'] == 'completed' && data['result'] != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.matchResult, //'Match Result'
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ...List.generate(
                    (data['result']['sets'] as List).length,
                    (index) {
                      final set = data['result']['sets'][index];
                      return Text(
                        '${loc.setLabel(index + 1)}: ${set['p1']} - ${set['p2']}', // Set
                      );
                    },
                  ),

                  const SizedBox(height: 10),
                  Text('${loc.locationLabel}: ${data['result']['location']}'), // Location
                  Text('${loc.durationLabel}: ${data['result']['durationMinutes']} min'), // Duration
                ],

              ],
            ),
          ),
        ),
      ),
    );
  }
}
