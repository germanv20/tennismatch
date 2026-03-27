import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'player_profile_view_screen.dart';
import '../widgets/empty_state.dart';

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
        'players': [
          data['fromUid'],
          data['toUid'],
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',

        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderUid': null,

        // 🔥 NEW FIELD
        'notifiedPlayers': [data['toUid']], // receiver already "knows"
      });

    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.incomingRequests), // 'Incoming Match Requests'
      ),
      body: SafeArea(
          child: StreamBuilder<QuerySnapshot>(
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

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${loc.errorPrefix}: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return EmptyState(
                icon: Icons.mail_outline,
                title: loc.noIncomingRequests, // "No incoming requests"
                subtitle: loc.incomingRequestsSubtitle, // "Match requests you receive will appear here"
              );
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
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: SizedBox(
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ),
                        ),
                      );
                    }

                    final userData =
                        userSnapshot.data!.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Card(
                        margin: const EdgeInsets.all(12),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerProfileViewScreen(
                                  userData: userData,
                                  showActions: true,
                                  requestRef: request.reference,

                                  onAccept: () async {
                                    await updateRequestStatus(
                                      request.reference,
                                      'accepted',
                                    );

                                  },

                                  onReject: () async {
                                    await updateRequestStatus(
                                      request.reference,
                                      'rejected',
                                    );

                                  },
                                ),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundImage: (userData['photoUrl'] != null &&
                                    userData['photoUrl'].toString().isNotEmpty)
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                            child: userData['photoUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            userData['name'] ?? loc.unknown,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ), // Unknown
                          subtitle: Text(loc.wantsToPlayMatch), // 'Wants to play a match'

                          trailing: const Icon(Icons.arrow_forward_ios),
        
                        ),
                      ),
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
