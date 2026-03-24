import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const weekOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class PlayerProfileViewScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  // ✅ NEW
  final bool showActions;
  final DocumentReference? requestRef;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onReject;
  final Future<void> Function()? onRequestMatch;
  final Future<void> Function()? onCancel;

  const PlayerProfileViewScreen({
    super.key,
    required this.userData,
    this.showActions = false,
    this.requestRef,
    this.onAccept,
    this.onReject,
    this.onRequestMatch,
    this.onCancel, 
  });
  

   @override
    State<PlayerProfileViewScreen> createState() =>
        _PlayerProfileViewScreenState();
}

  class _PlayerProfileViewScreenState extends State<PlayerProfileViewScreen> {
    bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final userData = widget.userData;
    final String name = userData['name'] ?? 'Unknown';
    final String level = userData['tennisLevel'] ?? 'Not set';
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final viewedUid = userData['uid'];
    final List availabilityRaw = userData['availability'] ?? [];

    final List<String> sortedAvailability = List<String>.from(availabilityRaw)
      ..sort((a, b) => weekOrder.indexOf(a).compareTo(weekOrder.indexOf(b)));

    final String availabilityText = sortedAvailability.isEmpty
        ? "No availability set"
        : sortedAvailability.join(', ');

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
            if (widget.onRequestMatch != null)
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('match_requests')
                    .where('fromUid', isEqualTo: currentUid)
                    .where('toUid', isEqualTo: viewedUid)
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, snapshot) {

                  final hasRequest =
                      snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                  return ElevatedButton(
                    onPressed: (isLoading || hasRequest)
                        ? null
                        : () async {
                            setState(() => isLoading = true);

                            if (widget.onRequestMatch != null) {
                              await widget.onRequestMatch!();
                            }

                            if (mounted) setState(() => isLoading = false);
                          },
                    child: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(hasRequest ? "Requested" : "Request Match"),
                  );
                },
              ),
            
            if (widget.onCancel != null) ...[
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        setState(() => isLoading = true);

                        if (widget.onCancel != null) {
                          await widget.onCancel!();
                        }

                        if (mounted) Navigator.pop(context);
                      },
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel),
                label: Text(isLoading ? "Processing..." : "Cancel Request"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
              ),
            ],

            if (widget.showActions) ...[
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);

                            if (widget.onAccept != null) {
                              await widget.onAccept!();
                            }

                            if (mounted) Navigator.pop(context);
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(isLoading ? "Processing..." : "Accept"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),

                  const SizedBox(width: 16),

                  ElevatedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            setState(() => isLoading = true);

                            if (widget.onReject != null) {
                              await widget.onReject!();
                            }

                            if (mounted) Navigator.pop(context);
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.close),
                    label: Text(isLoading ? "Processing..." : "Reject"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}