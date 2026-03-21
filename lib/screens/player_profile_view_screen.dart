import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class PlayerProfileViewScreen extends StatelessWidget {
  final Map<String, dynamic> userData;

  // ✅ NEW
  final bool showActions;
  final DocumentReference? requestRef;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onRequestMatch;

  const PlayerProfileViewScreen({
    super.key,
    required this.userData,
    this.showActions = false,
    this.requestRef,
    this.onAccept,
    this.onReject,
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

            // 🔹 Request Match (Available Players)
            if (onRequestMatch != null)
              ElevatedButton(
                onPressed: onRequestMatch,
                child: const Text("Request Match"),
              ),

            if (showActions) ...[
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check),
                    label: const Text("Accept"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),

                  const SizedBox(width: 16),

                  ElevatedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close),
                    label: const Text("Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}