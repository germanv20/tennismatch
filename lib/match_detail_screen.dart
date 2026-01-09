import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_chat_screen.dart';

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

            const Text(
              'More features coming soon 🎾',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
