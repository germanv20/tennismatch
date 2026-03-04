import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    final data = matchDoc.data() as Map<String, dynamic>;
    final String otherPlayerUid = opponentData['uid'];
    final String otherPlayerName = opponentData['name'] ?? 'Player';
    final String otherPlayerPhotoUrl = opponentData['photoUrl'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.block, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unmatch?'),
                  content: const Text(
                      'Are you sure you want to unmatch? This will remove the chat.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Unmatch'),
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

                Navigator.pop(context); // Exit chat screen
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opponent header
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage:
                      NetworkImage(opponentData['photoUrl'] ?? ''),
                ),
                const SizedBox(width: 16),
                Text(
                  opponentData['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Status: ${data['status']}',
              style: const TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 8),

            if (data['createdAt'] != null)
              Text(
                'Created at: ${(data['createdAt'] as Timestamp).toDate()}',
                style: const TextStyle(color: Colors.grey),
              ),

            const SizedBox(height: 30),

            const Divider(),

            ElevatedButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text('Open Chat'),
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
                label: const Text('Add Match Result'),
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
              const Text(
                'Match Result',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              ...List.generate(
                (data['result']['sets'] as List).length,
                (index) {
                  final set = data['result']['sets'][index];
                  return Text(
                    'Set ${index + 1}: ${set['p1']} - ${set['p2']}',
                  );
                },
              ),

              const SizedBox(height: 10),
              Text('Location: ${data['result']['location']}'),
              Text('Duration: ${data['result']['durationMinutes']} min'),
            ],

          ],
        ),
      ),
    );
  }
}
