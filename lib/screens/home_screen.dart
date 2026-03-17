import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'available_players_screen.dart';
import 'match_history_screen.dart';
import 'my_matches_screen.dart';
import 'incoming_requests_screen.dart';
import 'player_profile_screen.dart';
import 'player_statistics_screen.dart';

const tennisLevels = [
  'Beginner',
  'Intermediate',
  'Advanced',
];

const List<String> availableDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

class HomeScreen extends StatelessWidget {
  final User currentUser;
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.userData,
  });

  Future<void> updateTennisLevel(String level) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .update({
    'tennisLevel': level,
  });
}

  Future<void> updateAvailability(List<String> days) async {
  await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .update({
    'availability': days,
  });
}

  @override
  Widget build(BuildContext context) {
    final String? tennisLevel = userData['tennisLevel'];
    final List<dynamic> availabilityRaw = userData['availability'] ?? [];
    final List<String> availability =
        availabilityRaw.map((e) => e.toString()).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tennis Match"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              Text(
                'Welcome ${currentUser.displayName}',
                style: const TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 24),

              const Text('Your tennis level'),

              const SizedBox(height: 8),

              DropdownButton<String>(
                value: tennisLevel,
                hint: const Text('Choose level'),
                items: tennisLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  await updateTennisLevel(value);
                },
              ),

              const SizedBox(height: 32),

              const Text('Your availability'),

              const SizedBox(height: 8),

              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: availableDays.map((day) {
                  final isSelected = availability.contains(day);

                  return CheckboxListTile(
                    title: Text(day),
                    value: isSelected,
                    onChanged: (checked) async {
                      final updated = List<String>.from(availability);

                      if (checked == true) {
                        updated.add(day);
                      } else {
                        updated.remove(day);
                      }

                      await updateAvailability(updated);
                    },
                  );
                }).toList(),
              ),

              ElevatedButton(
                child: const Text("Find Players"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AvailablePlayersScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("My Matches"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyMatchesScreen(
                        currentUser: currentUser,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("Match History"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MatchHistoryScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("Incoming Requests"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IncomingRequestsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("My Stats"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerStatisticsScreen(
                        userId: currentUser.uid,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              ElevatedButton(
                child: const Text("My Profile"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerProfileScreen(
                        userData: userData,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}