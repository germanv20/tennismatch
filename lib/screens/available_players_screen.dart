import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_profile_screen.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

class AvailablePlayersScreen extends StatelessWidget {
  const AvailablePlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Available Players")),
        body: EmptyState(
          icon: Icons.person_off,
          title: "Not logged in",
          subtitle: "Please log in to find players",
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Available Players"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {

          if (userSnapshot.hasError){
            return const ErrorState(
              message: "Failed to load your profile",
            );
          }

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawData = userSnapshot.data!.data();

          if (rawData == null) {
            return const ErrorState(
              message: "Invalid user data",
            );
          }

          final data = rawData as Map<String, dynamic>;

          final tennisLevel = data['tennisLevel'];
          final List availability = data['availability'] ?? [];

          if (tennisLevel == null) {
            return const EmptyState(
              icon: Icons.info,
              title: "Set your tennis level",
              subtitle: "Go back and select your level to find players",
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('tennisLevel', isEqualTo: tennisLevel)
                .snapshots(),
            builder: (context, snapshot) {

              if (snapshot.hasError){
                return const ErrorState(
                  message: "Failed to load players",
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
                return const EmptyState(
                  icon: Icons.people,
                  title: "No players available",
                  subtitle: "Try changing your availability or check later",
                );
              }

              return ListView(
                children: matches.map((doc) {

                  final data =
                      doc.data() as Map<String, dynamic>;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              PlayerProfileScreen(
                            userData: data,
                          ),
                        ),
                      );
                    },
                    child: Card(
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
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text(
                          'Available: ${(data['availability'] as List).join(', ')}',
                        ),
                        trailing:
                            const Icon(Icons.sports_tennis),
                      ),
                    ),
                  );

                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}