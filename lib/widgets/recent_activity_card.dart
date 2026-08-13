import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/city_activity_utils.dart';
import '../screens/recent_activity_screen.dart';

/// Rappi-style teaser: a wide home-screen card showing the single most
/// recent match played by someone in the viewer's city this week, tapping
/// through to the full [RecentActivityScreen]. Hidden entirely if the
/// viewer has no city set (nothing to show yet); shows an empty-state
/// message rather than disappearing once a city is set, so the card stays
/// a stable, discoverable entry point into the full feed.
///
/// Reuses the same nested-stream + [buildCityActivityFeed] approach as
/// the full screen, just rendering only the newest item.
class RecentActivityCard extends StatelessWidget {
  const RecentActivityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return const SizedBox.shrink();

        final rawData = userSnapshot.data!.data();
        final userData = rawData as Map<String, dynamic>? ?? {};
        final String rawCity = (userData['city'] as String? ?? '').trim();
        if (rawCity.isEmpty) return const SizedBox.shrink();

        final cutoff = Timestamp.fromDate(
          DateTime.now()
              .subtract(const Duration(days: cityActivityWindowDays)),
        );

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            if (!usersSnapshot.hasData) return const SizedBox.shrink();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('type', isEqualTo: 'regular')
                  .where('status', isEqualTo: 'completed')
                  .where('completedAt', isGreaterThanOrEqualTo: cutoff)
                  .orderBy('completedAt', descending: true)
                  .snapshots(),
              builder: (context, regularSnapshot) {
                if (!regularSnapshot.hasData) return const SizedBox.shrink();

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('matches')
                      .where('type', whereIn: ['guest', 'doubles_guest'])
                      .where('completedAt', isGreaterThanOrEqualTo: cutoff)
                      .orderBy('completedAt', descending: true)
                      .snapshots(),
                  builder: (context, guestDoublesSnapshot) {
                    if (!guestDoublesSnapshot.hasData) {
                      return const SizedBox.shrink();
                    }

                    final feed = buildCityActivityFeed(
                      regularMatches: regularSnapshot.data!.docs,
                      guestDoublesMatches: guestDoublesSnapshot.data!.docs,
                      allUsers: usersSnapshot.data!.docs,
                      viewerCity: rawCity,
                    );

                    final latest = feed.isEmpty ? null : feed.first;

                    return _CardShell(
                      loc: loc,
                      latest: latest,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RecentActivityScreen(),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _CardShell extends StatelessWidget {
  final AppLocalizations loc;
  final CityActivityMatch? latest;
  final VoidCallback onTap;

  const _CardShell({
    required this.loc,
    required this.latest,
    required this.onTap,
  });

  String _headline() {
    if (latest == null) return loc.recentActivityCardSubtitle;
    if (latest!.isTie) {
      return loc.recentActivityTieLine(
          latest!.player1Label, latest!.player2Label);
    }
    return latest!.player1Won
        ? loc.recentActivityWinnerLine(
            latest!.player1Label, latest!.player2Label)
        : loc.recentActivityWinnerLine(
            latest!.player2Label, latest!.player1Label);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6FF4D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.groups, size: 32, color: Colors.green[900]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.recentActivityTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _headline(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.green[900]!.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      loc.recentActivityCardSeeAll,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[900],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.green[900]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
