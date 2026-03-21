import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'available_players_screen.dart';
import 'match_history_screen.dart';
import 'my_matches_screen.dart';
import 'incoming_requests_screen.dart';
import 'outgoing_requests_screen.dart';
import 'player_statistics_screen.dart';
import 'my_profile_screen.dart';
import '../widgets/home_card.dart';
import 'package:url_launcher/url_launcher.dart';


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

class NotificationBadge extends StatelessWidget {
  final Widget child;
  final int count;

  const NotificationBadge({
    super.key,
    required this.child,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Text(
                count > 9 ? '9+' : count.toString(),
                textAlign: TextAlign.center,
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
  }
}

class HomeScreen extends StatelessWidget {
  final User currentUser;
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.currentUser,
    required this.userData,
  });

  Widget buildProfileCard() {
    final String name = currentUser.displayName ?? "Player";
    final String level = userData['tennisLevel'] ?? "Not set";
    final List availabilityRaw = userData['availability'] ?? [];

    final String availabilityText = availabilityRaw.isEmpty
        ? "No availability set"
        : availabilityRaw.join(', ');

    return Card(
      color: const Color(0xFF2E7D32),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      //elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.deepPurple.shade100,
              backgroundImage: (userData['photoUrl'] != null &&
                      userData['photoUrl'].toString().isNotEmpty)
                  ? NetworkImage(userData['photoUrl'])
                  : null,
              child: userData['photoUrl'] == null
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "🎾 $level",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    "📅 $availabilityText",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> openFeedbackForm(BuildContext context) async {
    final url = Uri.parse("https://docs.google.com/forms/d/e/1FAIpQLScGcT2eC2znik4ndofkiExqAN1k7LL_A3eOOQfjeCkl-5RO-A/viewform");

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not open feedback form"),
        ),
      );
    }
  }

  Stream<int> getIncomingRequestsCount(String userId) {
    return FirebaseFirestore.instance
        .collection('match_requests')
        .where('toUid', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getNewMatchesCount(String userId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int count = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final notified = List<String>.from(data['notifiedPlayers'] ?? []);

            if (!notified.contains(userId)) {
              count++;
            }
          }

          return count;
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

              buildProfileCard(),

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

              const SizedBox(height: 24),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [

                  AspectRatio(
                    aspectRatio: 1,
                    child: HomeCard(
                      title: "Find Players",
                      icon: Icons.sports_tennis,
                      onTap: () {
                        Navigator.push(
                          context,
                            MaterialPageRoute(
                              builder: (_) => const AvailablePlayersScreen(),
                            ),
                        );
                      },
                    ),
                  ),

                  StreamBuilder<int>(
                    stream: getNewMatchesCount(currentUser.uid),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;

                        return AspectRatio(
                          aspectRatio: 1, 
                          child: NotificationBadge(
                            count: count,
                            child: HomeCard(
                              title: "My Matches",
                              icon: Icons.calendar_today,
                              onTap: () {
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
                          )
                       );
                    },
                  ),


                  AspectRatio(
                    aspectRatio: 1,
                      child: HomeCard(
                        title: "Match History",
                        icon: Icons.history,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MatchHistoryScreen(),
                            ),
                          );
                        },
                      ),
                  ),

                  AspectRatio(
                    aspectRatio: 1,
                    child: HomeCard(
                      title: "My Stats",
                      icon: Icons.bar_chart,
                      onTap: () {
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
                  ),


                  StreamBuilder<int>(
                    stream: getIncomingRequestsCount(currentUser.uid),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;

                      return AspectRatio(
                          aspectRatio: 1, 
                          child: NotificationBadge(
                            count: count,
                            child: HomeCard(
                              title: "Incoming Requests",
                              icon: Icons.mail,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const IncomingRequestsScreen(),
                                  ),
                                );
                              },
                            ),
                          )
                      );
                    },
                  ),

                  AspectRatio(
                    aspectRatio: 1,
                    child: HomeCard(
                      title: "Outgoing Requests",
                      icon: Icons.outbox,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OutgoingRequestsScreen(
                              currentUser: currentUser,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  AspectRatio(
                    aspectRatio: 1,
                    child: HomeCard(
                      title: "My Profile",
                      icon: Icons.person,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyProfileScreen(
                              userData: userData,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  AspectRatio(
                    aspectRatio: 1,
                    child: HomeCard(
                      title: "Send Feedback",
                      icon: Icons.feedback,
                      onTap: () => openFeedbackForm(context),
                    ),
                  )

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}