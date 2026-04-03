import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'player_profile_view_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String translateDay(String day, AppLocalizations loc) {
  switch (day) {
    case 'Mon': return loc.mon;
    case 'Tue': return loc.tue;
    case 'Wed': return loc.wed;
    case 'Thu': return loc.thu;
    case 'Fri': return loc.fri;
    case 'Sat': return loc.sat;
    case 'Sun': return loc.sun;
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

class AvailablePlayersScreen extends StatelessWidget {
  const AvailablePlayersScreen({super.key});

  Future<void> requestMatch(BuildContext context, String toUid) async {
    final loc = AppLocalizations.of(context)!;
    final fromUid = FirebaseAuth.instance.currentUser!.uid;

    if (fromUid == toUid) return;

    final query = await FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: fromUid)
        .where('toUid', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (!context.mounted) return;

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

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.requestSent)), // 'Match request sent 🎾'
    );
  }

  Stream<QuerySnapshot> getMyPendingRequests(String uid) {
    return FirebaseFirestore.instance
        .collection('match_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.availablePlayers)),
        body: EmptyState(
          icon: Icons.person_off,
          title: loc.notLoggedIn,
          subtitle: loc.loginToFindPlayers,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.availablePlayers), // "Available Players"
      ),
      body: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {

            if (userSnapshot.hasError){
              return ErrorState(
                message: loc.failedToLoadProfile,
              );
            }

            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawData = userSnapshot.data!.data();

            if (rawData == null) {
              return ErrorState(
                message: loc.invalidUserData, // "Invalid user data"
              );
            }

            final data = rawData as Map<String, dynamic>;

            final List<String> availability =
                normalizeDays(data['availability'] ?? []);

            if (availability.isEmpty) {
              return EmptyState(
                icon: Icons.event_busy,
                title: loc.noAvailability,
                subtitle: loc.setAvailabilityToFindPlayers,
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {

                if (snapshot.hasError){
                  return ErrorState(
                    message: loc.failedToLoadPlayers,
                    );
                }

                if (!snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final matches = docs.where((doc) {

                  final data =
                      doc.data() as Map<String, dynamic>;

                  if (data['uid'] == user.uid) return false;

                  final List<String> otherAvailability =
                      normalizeDays(data['availability'] ?? []);

                  return otherAvailability.any(
                    (day) => availability.contains(day),
                  );

                }).toList();

                if (matches.isEmpty) {
                  return EmptyState(
                    icon: Icons.people,
                    title: loc.noPlayersAvailable, // "No players available"
                    subtitle: loc.tryChangingAvailability, // "Try changing your availability or check later"
                  );
                }

                  return StreamBuilder<QuerySnapshot>(
                    stream: getMyPendingRequests(user.uid),
                    builder: (context, requestSnapshot) {

                      if (!requestSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final pendingRequests = requestSnapshot.data!.docs;

                      // 🔥 Create a Set of requested user IDs
                      final requestedUserIds = pendingRequests
                          .map((doc) => doc['toUid'] as String)
                          .toSet();

                      return ListView(
                        children: matches.map((doc) {

                          final data = doc.data() as Map<String, dynamic>;

                          final List availabilityRaw = data['availability'] ?? [];

                          final List<String> sortedAvailability = List<String>.from(availabilityRaw)
                            ..sort((a, b) => weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));

                          final String availabilityText = sortedAvailability.isEmpty
                              ? loc.noAvailability // "No availability"
                              : sortedAvailability
                                .map((day) => translateDay(day, loc))
                                .join(', ');

                          final isAlreadyRequested = requestedUserIds.contains(data['uid']);

                          return GestureDetector(
                            onTap: isAlreadyRequested
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PlayerProfileViewScreen(
                                          userData: data,
                                          onRequestMatch: () async {
                                            await requestMatch(context, data['uid']);

                                            if (!context.mounted) return;
                                            
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Card(
                                color: isAlreadyRequested ? Colors.grey[300] : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: (data['photoUrl'] != null &&
                                            data['photoUrl'].toString().isNotEmpty)
                                        ? NetworkImage(data['photoUrl'])
                                        : null,
                                    child: data['photoUrl'] == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(
                                    data['name'] ?? loc.unknown,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${loc.availableLabel}: $availabilityText',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  trailing: isAlreadyRequested
                                      ? Text(
                                          loc.requested,
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : const Icon(Icons.sports_tennis),
                                ),
                              ),
                            ),
                          );

                        }).toList(),
                      );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}