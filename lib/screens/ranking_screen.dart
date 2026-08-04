import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/city_utils.dart';
import '../utils/ranking_utils.dart';
import '../widgets/empty_state.dart';
import 'player_profile_view_screen.dart';

/// City-scoped Elo leaderboard (Phase 3). Ranks players who share the
/// viewer's city and have at least [eloRankingMinMatches] rated regular
/// matches, highest Elo first. No new Firestore query/index is needed —
/// it fetches the same full `users` collection stream
/// available_players_screen.dart already uses and filters/sorts
/// client-side via buildCityRanking(), for the same reason that screen
/// does: city names aren't stored normalized, so accent/case-insensitive
/// matching has to happen in Dart either way.
class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.rankingTitle)),
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

            final userData =
                userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
            final String rawCity =
                (userData['city'] as String? ?? '').trim();
            final int myMatchesPlayed =
                (userData['eloMatchesPlayed'] as int?) ?? 0;

            if (rawCity.isEmpty) {
              return EmptyState(
                icon: Icons.location_off,
                title: loc.rankingNoCityTitle,
                subtitle: loc.rankingNoCitySubtitle,
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, allSnapshot) {
                if (!allSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final ranking =
                    buildCityRanking(allSnapshot.data!.docs, rawCity);
                final displayCity = formatCityDisplay(rawCity);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          loc.rankingCityHeader(displayCity),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    if (myMatchesPlayed < eloRankingMinMatches)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  loc.rankingMatchesNeeded(
                                      eloRankingMinMatches -
                                          myMatchesPlayed),
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    Expanded(
                      child: ranking.isEmpty
                          ? EmptyState(
                              icon: Icons.leaderboard_outlined,
                              title: loc.rankingEmptyTitle,
                              subtitle: loc.rankingEmptySubtitle,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 12, 16, 16),
                              itemCount: ranking.length,
                              itemBuilder: (context, index) {
                                final doc = ranking[index];
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final isMe = doc.id == currentUser.uid;
                                final name =
                                    data['name'] as String? ?? loc.unknown;
                                final photoUrl = data['photoUrl'] as String?;
                                final eloRating =
                                    (data['eloRating'] as int?) ?? 1200;
                                final rank = index + 1;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.indigo.shade50
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isMe
                                          ? Colors.indigo.shade200
                                          : Colors.grey.shade200,
                                      width: isMe ? 1.5 : 1,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: SizedBox(
                                      width: 32,
                                      child: Text(
                                        '#$rank',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: rank == 1
                                              ? Colors.amber.shade800
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundImage: (photoUrl !=
                                                      null &&
                                                  photoUrl.isNotEmpty)
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: (photoUrl == null ||
                                                  photoUrl.isEmpty)
                                              ? const Icon(Icons.person,
                                                  size: 18)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            isMe
                                                ? '$name (${loc.you})'
                                                : name,
                                            style: TextStyle(
                                              fontWeight: isMe
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    trailing: Text(
                                      '$eloRating',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    onTap: isMe
                                        ? null
                                        : () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PlayerProfileViewScreen(
                                                  userData: data,
                                                ),
                                              ),
                                            ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
