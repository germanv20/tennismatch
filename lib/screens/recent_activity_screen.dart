import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/city_utils.dart';
import '../utils/city_activity_utils.dart';
import '../widgets/empty_state.dart';

/// City-scoped "recent activity" feed (Idea 1): every completed match from
/// the last [cityActivityWindowDays] played by someone in the viewer's
/// city, newest first — across regular, guest, and doubles_guest matches.
///
/// Reduced-detail cards only (names, result, date) — not full match detail
/// (score breakdown, location, notes) — even though completed regular
/// matches are now broadly readable to support this feed. See
/// firestore.rules and city_activity_utils.dart for the read-scope and
/// city cross-referencing design.
class RecentActivityScreen extends StatelessWidget {
  const RecentActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.recentActivityTitle)),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawData = userSnapshot.data!.data();
            final userData = rawData as Map<String, dynamic>? ?? {};
            final String rawCity = (userData['city'] as String? ?? '').trim();

            if (rawCity.isEmpty) {
              return EmptyState(
                icon: Icons.location_off,
                title: loc.recentActivityNoCityTitle,
                subtitle: loc.recentActivityNoCitySubtitle,
              );
            }

            final displayCity = formatCityDisplay(rawCity);
            final cutoff = Timestamp.fromDate(
              DateTime.now()
                  .subtract(const Duration(days: cityActivityWindowDays)),
            );

            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                if (!usersSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('matches')
                      .where('type', isEqualTo: 'regular')
                      .where('status', isEqualTo: 'completed')
                      .where('completedAt', isGreaterThanOrEqualTo: cutoff)
                      .orderBy('completedAt', descending: true)
                      .snapshots(),
                  builder: (context, regularSnapshot) {
                    if (!regularSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('matches')
                          .where('type',
                              whereIn: ['guest', 'doubles_guest'])
                          .where('completedAt',
                              isGreaterThanOrEqualTo: cutoff)
                          .orderBy('completedAt', descending: true)
                          .snapshots(),
                      builder: (context, guestDoublesSnapshot) {
                        if (!guestDoublesSnapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final feed = buildCityActivityFeed(
                          regularMatches: regularSnapshot.data!.docs,
                          guestDoublesMatches:
                              guestDoublesSnapshot.data!.docs,
                          allUsers: usersSnapshot.data!.docs,
                          viewerCity: rawCity,
                        );

                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  loc.recentActivityCityHeader(displayCity),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: feed.isEmpty
                                  ? EmptyState(
                                      icon: Icons.groups_outlined,
                                      title: loc.recentActivityEmptyTitle,
                                      subtitle:
                                          loc.recentActivityEmptySubtitle,
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 12, 16, 16),
                                      itemCount: feed.length,
                                      itemBuilder: (context, index) {
                                        return _ActivityCard(
                                          match: feed[index],
                                          loc: loc,
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
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

class _ActivityCard extends StatelessWidget {
  final CityActivityMatch match;
  final AppLocalizations loc;

  const _ActivityCard({required this.match, required this.loc});

  IconData get _typeIcon {
    switch (match.type) {
      case 'doubles_guest':
        return Icons.group;
      case 'guest':
        return Icons.person_outline;
      default:
        return Icons.sports_tennis;
    }
  }

  String _relativeDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final matchDay = DateTime(
        match.completedAt.year, match.completedAt.month, match.completedAt.day);
    final diff = today.difference(matchDay).inDays;

    if (diff <= 0) return loc.today;
    if (diff == 1) return loc.yesterday;
    return loc.daysAgoCount(diff);
  }

  @override
  Widget build(BuildContext context) {
    final resultLine = match.isTie
        ? loc.recentActivityTieLine(match.player1Label, match.player2Label)
        : (match.player1Won
            ? loc.recentActivityWinnerLine(
                match.player1Label, match.player2Label)
            : loc.recentActivityWinnerLine(
                match.player2Label, match.player1Label));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.green.shade50,
            child: Icon(_typeIcon, size: 18, color: Colors.green.shade800),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultLine,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (match.scoreText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    match.scoreText,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeDate(),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
