import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class PlayerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  const PlayerProfileScreen({
    super.key,
    required this.userData,
  });

  Future<void> requestMatch(BuildContext context) async {
    final fromUid = currentUid;
    final toUid = userData['uid'];

    debugPrint('📨 Sending match request from $fromUid to $toUid');

    // Prevent requesting yourself
    if (fromUid == toUid) return;

    final query = await FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (!context.mounted) return; // ✅ FIX #1

    if (query.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match request already sent')),
      );
      return;
    }

    await FirebaseFirestore.instance.collection('match_requests').add({
      'fromUid': fromUid,
      'toUid': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return; // ✅ FIX #1

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match request sent 🎾')),
    );
  }


  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Unknown';
    final String email = userData['email'] ?? '';
    final String tennisLevel = userData['tennisLevel'] ?? '';
    final List<dynamic> availability = userData['availability'] ?? [];
    final String? photoUrl = userData['photoUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
            ),
            const SizedBox(height: 16),

            Text(
              name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(email),
            const SizedBox(height: 16),

            Text(
              'Tennis level: $tennisLevel',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            const Text(
              'Availability',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: () => requestMatch(context),
              icon: const Icon(Icons.sports_tennis),
              label: const Text('Request Match'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),

            Wrap(
              spacing: 8,
              children: availability.map<Widget>((day) {
                return Chip(label: Text(day.toString()));
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
