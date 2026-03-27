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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                const SizedBox(height: 24),

                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  '${loc.level}: $tennisLevel', // Tennis level
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),

                availability.isEmpty
                    ? Text(
                        loc.noAvailability,
                        style: const TextStyle(color: Colors.grey),
                      )
                    : Wrap(
                        spacing: 8,
                        children: availability.map<Widget>((day) {
                          return Chip(
                            label: Text(translateDay(day.toString(), loc)),
                          );
                        }).toList(),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
