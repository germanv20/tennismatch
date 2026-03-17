import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'player_profile_screen.dart';

class AvailablePlayersScreen extends StatelessWidget {
  const AvailablePlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in")),
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

          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data =
              userSnapshot.data!.data() as Map<String, dynamic>;

          final tennisLevel = data['tennisLevel'];
          final List availability = data['availability'] ?? [];

          if (tennisLevel == null) {
            return const Center(
              child: Text("Select your tennis level first."),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('tennisLevel', isEqualTo: tennisLevel)
                .snapshots(),
            builder: (context, snapshot) {

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
                return const Center(
                  child: Text("No players available."),
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
                          backgroundImage: NetworkImage(
                              data['photoUrl'] ?? ''),
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