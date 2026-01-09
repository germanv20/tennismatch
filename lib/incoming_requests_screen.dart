import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class IncomingRequestsScreen extends StatelessWidget {
  const IncomingRequestsScreen({super.key});

  Future<void> updateRequestStatus(
    DocumentReference requestRef,
    String status,
  ) async {
    // 1️⃣ Update the request status
    await requestRef.update({
      'status': status,
    });

    // 2️⃣ If accepted → create match
    if (status == 'accepted') {
      final requestSnapshot = await requestRef.get();
      final data = requestSnapshot.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('matches').add({
        'player1Uid': data['fromUid'],
        'player2Uid': data['toUid'],
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Match Requests'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('match_requests')
            .where('toUid', isEqualTo: currentUser.uid)
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No incoming match requests'),
            );
          }

          if (snapshot.hasError) {
            return Text('ERROR: ${snapshot.error}');
          }

          if (!snapshot.hasData) {
            return const CircularProgressIndicator();
          }

          debugPrint('📥 Incoming docs count: ${snapshot.data!.docs.length}');
          debugPrint('👤 Current UID: ${FirebaseAuth.instance.currentUser!.uid}');

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final data = request.data() as Map<String, dynamic>;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['fromUid'])
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.all(12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage:
                            NetworkImage(userData['photoUrl'] ?? ''),
                      ),
                      title: Text(userData['name'] ?? 'Unknown'),
                      subtitle: const Text('Wants to play a match'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () async {
                            await updateRequestStatus(
                              request.reference,
                              'accepted',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () async {
                            await updateRequestStatus(
                              request.reference,
                              'rejected',
                            );
                          },
                        ),
                      ],
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
