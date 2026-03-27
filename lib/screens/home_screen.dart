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
import 'package:tennismatch/gen_l10n/app_localizations.dart';

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

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class HomeScreen extends StatelessWidget {
  final User currentUser;
  final Map<String, dynamic> userData;

  const HomeScreen({
    super.key,
    required this.currentUser,
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

  String translateDayFull(String day, AppLocalizations loc) {
    switch (day) {
      case 'Mon': return loc.monFull;
      case 'Tue': return loc.tueFull;
      case 'Wed': return loc.wedFull;
      case 'Thu': return loc.thuFull;
      case 'Fri': return loc.friFull;
      case 'Sat': return loc.satFull;
      case 'Sun': return loc.sunFull;
      default: return day;
    }
  }

  List<String> normalizeDays(List rawDays) {
    final map = {
      'Mon': 'Mon', 'Tue': 'Tue', 'Wed': 'Wed',
      'Thu': 'Thu', 'Fri': 'Fri', 'Sat': 'Sat', 'Sun': 'Sun',
      'Lun': 'Mon', 'Mar': 'Tue', 'Mié': 'Wed',
      'Jue': 'Thu', 'Vie': 'Fri', 'Sáb': 'Sat', 'Dom': 'Sun',
    };

    return rawDays
        .map<String>((day) => map[day.toString()] ?? day.toString())
        .toSet()
        .toList();
  }

  Widget buildProfileCard(AppLocalizations loc) {
    final String name = currentUser.displayName ?? "Player";
    final String rawLevel = userData['tennisLevel'] ?? "";
    final String level = rawLevel.isEmpty
        ? loc.notSet
        : translateLevel(rawLevel, loc);
    final List availabilityRaw =
        normalizeDays(userData['availability'] ?? []);

    final List<String> sortedAvailability = List<String>.from(availabilityRaw)
      ..sort((a, b) => weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));

    final String availabilityText = sortedAvailability.isEmpty
        ? loc.noAvailability
        : sortedAvailability
            .map((day) => translateDay(day, loc))
            .join(', ');

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
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "${loc.level}: $level",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    "${loc.availability}: $availabilityText",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
    final loc = AppLocalizations.of(context)!;

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.failedToOpenFeedbackForm),
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
        normalizeDays(availabilityRaw);
    final loc = AppLocalizations.of(context)!;

    final dayMap = {
      'Mon': loc.monFull,
      'Tue': loc.tueFull,
      'Wed': loc.wedFull,
      'Thu': loc.thuFull,
      'Fri': loc.friFull,
      'Sat': loc.satFull,
      'Sun': loc.sunFull,
    };

    final levelMap = {
      'Beginner': loc.levelBeginner,
      'Intermediate': loc.levelIntermediate,
      'Advanced': loc.levelAdvanced,
    };

    final tennisLevels = [
      loc.levelBeginner,
      loc.levelIntermediate,
      loc.levelAdvanced,
    ];

    final availableDays = [
      loc.mon,
      loc.tue,
      loc.wed,
      loc.thu,
      loc.fri,
      loc.sat,
      loc.sun,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.appTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                buildProfileCard(loc),

                const SizedBox(height: 24),

                Text(loc.yourTennisLevel),

                const SizedBox(height: 8),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    DropdownButton<String>(
                      value: tennisLevel,
                      hint: Text(loc.selectLevel),
                      items: levelMap.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,        // ✅ stored in Firestore
                          child: Text(entry.value) // ✅ translated label
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value == null) return;
                        await updateTennisLevel(value);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                Text(loc.availability),

                const SizedBox(height: 4),

                Text(
                  loc.availabilityHint,
                  style: const TextStyle(color: Colors.black),
                ), // Your availability

                const SizedBox(height: 8),

                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: dayMap.entries.map((entry) {
                    final key = entry.key;     // 'Mon'
                    final label = entry.value; // 'Lun'

                    final isSelected = availability.contains(key); // ✅ FIX

                    return CheckboxListTile(
                      title: Text(label), // already translated
                      value: isSelected,
                      onChanged: (checked) async {
                        final updated = List<String>.from(availability);

                        if (checked == true) {
                          if (!updated.contains(key)) {
                            updated.add(key);
                          }
                        } else {
                          updated.remove(key);
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
                        title: loc.findPlayers,
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
                                title: loc.myMatches,
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
                          title: loc.matchHistory,
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
                        title: loc.myStats,
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
                                title: loc.incomingRequests,
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
                        title: loc.outgoingRequests,
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
                        title: loc.myProfile,
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
                        title: loc.sendFeedback,
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
      ),
    );
  }
}