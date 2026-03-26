import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'player_profile_view_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
      body: StreamBuilder<DocumentSnapshot>(
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

          final tennisLevel = data['tennisLevel'];
          final List availability = data['availability'] ?? [];

          if (tennisLevel == null) {
            return EmptyState(
              icon: Icons.info,
              title: loc.setYourLevel,
              subtitle: loc.setLevelToFindPlayers,
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('tennisLevel', isEqualTo: tennisLevel)
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

                final List otherAvailability =
                    data['availability'] ?? [];

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
                            : sortedAvailability.join(', ');

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
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            );
                          },
                          child: Card(
                            color: isAlreadyRequested ? Colors.grey[200] : null,
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
                              title: Text(data['name'] ?? loc.unknown),
                              subtitle: Text(
                                '${loc.availableLabel}: $availabilityText',
                              ),
                              trailing: isAlreadyRequested
                                  ? Text(
                                      loc.requested, // "Requested"
                                      style: TextStyle(color: Colors.grey),
                                    )
                                  : const Icon(Icons.sports_tennis),
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
    );
  }
}