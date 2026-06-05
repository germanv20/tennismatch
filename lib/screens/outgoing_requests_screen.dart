import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import 'player_profile_view_screen.dart';

class OutgoingRequestsScreen extends StatelessWidget {
  final User currentUser;

  const OutgoingRequestsScreen({
    super.key,
    required this.currentUser,
  });

  Future<void> cancelRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('match_requests')
          .doc(requestId)
          .update({'status': 'cancelled'});
    } catch (e) {
      debugPrint('❌ Error cancelling request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final requestsRef =
        FirebaseFirestore.instance.collection('match_requests');

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.outgoingRequests),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          // Include pending AND expired so we can show the expiry badge
          // before the user dismisses it by cancelling
          stream: requestsRef
              .where('fromUid', isEqualTo: currentUser.uid)
              .where('status', whereIn: ['pending', 'expired'])
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ErrorState(message: loc.failedToLoadOutgoing);
            }

            // Filter to show: pending + recently expired (last 7 days)
            // so user sees the expiry notification, then it disappears
            final allDocs = snapshot.data?.docs ?? [];
            final now = DateTime.now();
            final requests = allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? '';
              if (status == 'pending') return true;
              if (status == 'expired') {
                // Show expired requests for 1 day so user sees the badge
                final createdAt = data['createdAt'] as Timestamp?;
                if (createdAt == null) return false;
                final age = now.difference(createdAt.toDate());
                return age.inDays <= 3; // 2 days pending + 1 day visible
              }
              return false;
            }).toList();

            if (requests.isEmpty) {
              return EmptyState(
                icon: Icons.outbox,
                title: loc.noOutgoingRequests,
                subtitle: loc.outgoingRequestsSubtitle,
              );
            }

            return ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                final data = request.data() as Map<String, dynamic>;
                final toUid = data['toUid'] as String? ?? '';
                final status = data['status'] as String? ?? 'pending';
                final isExpired = status == 'expired';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(toUid)
                      .get(),
                  builder: (context, userSnapshot) {

                    if (userSnapshot.hasError) {
                      return ListTile(title: Text(loc.failedToLoadUser));
                    }

                    if (!userSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                                child: Icon(Icons.person)),
                            title: SizedBox(
                              height: 12,
                              child: LinearProgressIndicator(),
                            ),
                          ),
                        ),
                      );
                    }

                    final userData = userSnapshot.data!.data()
                        as Map<String, dynamic>? ?? {};

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Card(
                        // Grey out expired requests
                        color: isExpired ? Colors.grey[100] : null,
                        child: ListTile(
                          onTap: isExpired
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerProfileViewScreen(
                                        userData: userData,
                                        onCancel: () async {
                                          await cancelRequest(request.id);
                                        },
                                      ),
                                    ),
                                  );
                                },
                          leading: CircleAvatar(
                            backgroundImage: (userData['photoUrl'] != null &&
                                    userData['photoUrl']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(userData['photoUrl'])
                                : null,
                            child: userData['photoUrl'] == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            userData['name'] ?? loc.unknown,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isExpired ? Colors.grey[600] : null,
                            ),
                          ),
                          subtitle: Text(
                            isExpired
                                ? loc.requestExpired
                                : loc.waitingForResponse,
                            style: TextStyle(
                              color: isExpired
                                  ? Colors.orange[700]
                                  : Colors.grey,
                              fontWeight: isExpired
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: isExpired
                              ? Icon(Icons.timer_off,
                                  color: Colors.orange[700])
                              : const Icon(Icons.arrow_forward_ios),
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