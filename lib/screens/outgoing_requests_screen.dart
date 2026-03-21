import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';

class OutgoingRequestsScreen extends StatelessWidget {
  final User currentUser;

  const OutgoingRequestsScreen({
    super.key,
    required this.currentUser,
  });

  Future<void> cancelRequest(String requestId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance
          .collection('match_requests')
          .doc(requestId)
          .update({
        'status': 'cancelled',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request cancelled'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel request'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsRef =
        FirebaseFirestore.instance.collection('match_requests');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outgoing Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: requestsRef
            .where('fromUid', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const ErrorState(
              message: "Failed to load outgoing requests",
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EmptyState(
              icon: Icons.outbox,
              title: "No outgoing requests",
              subtitle: "Requests you send will appear here",
            );
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;

              final toUid = data['toUid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(toUid)
                    .get(),
                builder: (context, userSnapshot) {

                  if (userSnapshot.hasError) {
                    return const ListTile(
                      title: Text('Failed to load user'),
                    );
                  }

                  if (!userSnapshot.hasData) {
                    return const ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text('Loading...'),
                    );
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>? ?? {};

                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (userData['photoUrl'] != null &&
                                userData['photoUrl'].toString().isNotEmpty)
                            ? NetworkImage(userData['photoUrl'])
                            : null,
                        child: userData['photoUrl'] == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(userData['name'] ?? 'Unknown'),
                      subtitle: const Text('Waiting for response'),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.cancel,
                          color: Colors.red,
                        ),
                        onPressed: () => cancelRequest(request.id, context),
                      ),
                    ),
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