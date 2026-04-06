import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/day_utils.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

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

  String formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();

              final data = doc.data() as Map<String, dynamic>;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(userData: data),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;

          final String name = userData['name'] ?? loc.unknown;
          final String email = userData['email'] ?? '';
          final String rawLevel = userData['tennisLevel'] ?? '';
          final String tennisLevel =
              rawLevel.isEmpty ? loc.notSet : translateLevel(rawLevel, loc);

          final List<String> availability =
              sortDays(userData['availability'] ?? []);

          final String? photoUrl = userData['photoUrl'];
          final Timestamp? birthTimestamp = userData['birthDate'];
          final int? age = userData['age'];
          final String city = userData['city'] ?? loc.notSet;
          final String country = userData['country'] ?? loc.notSet;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    const SizedBox(height: 24),

                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(email),
                    const SizedBox(height: 24),

                    if (age != null)
                      Text('${loc.age}: $age'),

                    const SizedBox(height: 12),

                    Text('${loc.city}: $city'),
                    const SizedBox(height: 12),

                    Text('${loc.country}: $country'),
                    const SizedBox(height: 12),

                    if (birthTimestamp != null)
                      Text(
                        '${loc.birthDate}: ${formatDate(birthTimestamp.toDate())}',
                      ),

                    const SizedBox(height: 24),

                    Text('${loc.level}: $tennisLevel'),
                    const SizedBox(height: 24),

                    availability.isEmpty
                        ? Text(loc.noAvailability,
                            style: const TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            children: availability.map<Widget>((day) {
                              return Chip(
                                label:
                                    Text(translateDay(day.toString(), loc)),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}