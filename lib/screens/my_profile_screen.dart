import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';


class MyProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  String get currentUid => FirebaseAuth.instance.currentUser!.uid;

  const MyProfileScreen({
    super.key,
    required this.userData,
  });

  Future<void> requestMatch(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
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
        SnackBar(content: Text(loc.requestAlreadySent)), // 'Match request already sent'
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
      SnackBar(content: Text(loc.requestSent)), // 'Match request sent 🎾'
    );
  }

  String translateLevel(String level, AppLocalizations loc) {
    switch (level) {
      case 'Beginner':
        return loc.levelBeginner;
      case 'Intermediate':
        return loc.levelIntermediate;
      case 'Advanced':
        return loc.levelAdvanced;
      default:
        return level;
    }
  }

  String translateDay(String day, AppLocalizations loc) {
    switch (day) {
      case 'Mon':
        return loc.mon;
      case 'Tue':
        return loc.tue;
      case 'Wed':
        return loc.wed;
      case 'Thu':
        return loc.thu;
      case 'Fri':
        return loc.fri;
      case 'Sat':
        return loc.sat;
      case 'Sun':
        return loc.sun;
      default:
        return day;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final String name = userData['name'] ?? loc.unknown; // 'Unknown'
    final String email = userData['email'] ?? '';
    final String rawLevel = userData['tennisLevel'] ?? '';
    final String tennisLevel =
        rawLevel.isEmpty ? loc.notSet : translateLevel(rawLevel, loc);
    final List<dynamic> availability = userData['availability'] ?? [];
    final String? photoUrl = userData['photoUrl'];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myProfile),
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
              '${loc.level}: $tennisLevel', // Tennis level
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            Text(
              loc.availability, // 'Availability'
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            const SizedBox(height: 24),

            /*ElevatedButton.icon(
              onPressed: () => requestMatch(context),
              icon: const Icon(Icons.sports_tennis),
              label: const Text('Request Match'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),*/

            Wrap(
              spacing: 8,
              children: availability.map<Widget>((day) {
                return Chip(
                  label: Text(translateDay(day.toString(), loc)), // ✅ FIX
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
