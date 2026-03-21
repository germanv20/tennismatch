import 'package:flutter/material.dart';

class PlayerProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback? onRequestMatch;

  const PlayerProfileViewScreen({
    super.key,
    required this.userData,
    this.onRequestMatch,
  });

  @override
  Widget build(BuildContext context) {
    final String name = userData['name'] ?? 'Unknown';
    final String level = userData['tennisLevel'] ?? 'Not set';
    final List availabilityRaw = userData['availability'] ?? [];

    final String availabilityText = availabilityRaw.isEmpty
        ? "No availability set"
        : availabilityRaw.join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Player Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            CircleAvatar(
              radius: 50,
              backgroundImage: (userData['photoUrl'] != null &&
                      userData['photoUrl'].toString().isNotEmpty)
                  ? NetworkImage(userData['photoUrl'])
                  : null,
              child: userData['photoUrl'] == null
                  ? const Icon(Icons.person, size: 50)
                  : null,
            ),

            const SizedBox(height: 16),

            Text(
              name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text("🎾 Level: $level"),

            const SizedBox(height: 8),

            Text("📅 Availability: $availabilityText"),

            const SizedBox(height: 24),

            if (onRequestMatch != null)
              ElevatedButton(
                onPressed: onRequestMatch,
                child: const Text("Request Match"),
              ),
          ],
        ),
      ),
    );
  }
}