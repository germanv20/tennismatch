import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/match_card.dart';
import '../widgets/empty_state.dart';
import 'match_details_screen.dart';
import 'guest_match_details_screen.dart';
import 'doubles_match_details_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  String currentUserName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentUserName();
    });
  }

  Future<void> _loadCurrentUserName() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      setState(() {
        currentUserName = doc['name'] ?? '';
      });
    } catch (e) {
      debugPrint('❌ Failed to load user name: $e');
    }
  }

  /// Normalises set perspective so p1 is always the current user
  List _normaliseSets(
    List rawSets,
    bool currentUserIsP1,
  ) {
    if (currentUserIsP1) return rawSets;
    // Flip both score and tiebreak fields so p1 always = current user
    return rawSets.map((s) {
      final flipped = <String, dynamic>{'p1': s['p2'], 'p2': s['p1']};
      // Also flip tiebreak scores if present
      if (s['tb1'] != null && s['tb2'] != null) {
        flipped['tb1'] = s['tb2'];
        flipped['tb2'] = s['tb1'];
      }
      return flipped;
    }).toList();
  }

  /// Builds a card for a REGULAR (non-guest) completed match
  Widget _buildRegularMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final List players = match['players'] ?? [];
    final playerNames = match['playerNames'] ?? {};
    final opponentUid =
        players.firstWhere((uid) => uid != currentUid, orElse: () => '');
    final opponentName = playerNames[opponentUid] ?? loc.unknown;

    final summary = match['summary'] as Map<String, dynamic>? ?? {};
    final player1Uid = match['player1Uid'];
    final bool currentUserIsP1 = currentUid == player1Uid;

    Timestamp? matchDateTs =
        summary['matchDate'] ?? match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final rawSets = match['result']?['sets'] ?? [];
    final List sets = _normaliseSets(rawSets, currentUserIsP1);

    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;
    final deletionRequest = match['deletionRequest'];

    final bool hasDeleteNotification = deletionRequest != null &&
        ((deletionRequest['status'] == 'pending' &&
                deletionRequest['requestedBy'] != currentUid &&
                !(deletionRequest['seenBy'] ?? []).contains(currentUid)) ||
            (deletionRequest['requestedBy'] == currentUid &&
                (deletionRequest['status'] == 'accepted' ||
                    deletionRequest['status'] == 'rejected') &&
                !(deletionRequest['seenBy'] ?? []).contains(currentUid)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailsScreen(
                matchId: matchDoc.id,
                players: players,
                playerName: currentUserName,
                opponentName: opponentName,
                opponentUid: opponentUid,
                sets: sets,
                location: location,
                duration: duration,
                matchDate: matchDate,
              ),
            ),
          );

          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          }
        },
        child: MatchCard(
          hasDeleteRequest: hasDeleteNotification,
          deletionRequest: deletionRequest,
          matchId: matchDoc.id,
          players: players,
          playerName: currentUserName,
          opponentName: opponentName,
          opponentUid: opponentUid,
          sets: sets,
          location: location,
          duration: duration,
          matchDate: matchDate,
          winnerUid: match['winnerUid'] ?? '',
          currentUserUid: currentUid,
          isTie: match['isTie'] == true,
        ),
      ),
    );
  }

  /// Builds a card for a GUEST match
  Widget _buildGuestMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final guest = match['guestOpponent'] as Map<String, dynamic>? ?? {};
    // p1 in Firestore is always the match creator (createdBy).
    // If the current user claimed the match (is not the creator),
    // flip scores and names so the current user always sees their
    // own perspective on the left.
    final createdBy = match['createdBy'] as String? ?? '';
    final bool userIsCreator = createdBy == currentUid;

    // Creator sees guestOpponent as opponent.
    // Claimant sees the creator as opponent — name from playerNames.
    final String opponentName;
    final String opponentPhone;
    if (userIsCreator) {
      opponentName = guest['name'] ?? loc.guestOpponent;
      opponentPhone = guest['phone'] ?? '';
    } else {
      final playerNames = match['playerNames'] as Map<String, dynamic>? ?? {};
      opponentName = playerNames[createdBy] as String? ?? loc.guestOpponent;
      opponentPhone = '';
    }

    final rawSets = match['result']?['sets'] ?? [];
    final List sets = userIsCreator
        ? List.from(rawSets)
        : rawSets.map((s) {
            final flipped = <String, dynamic>{
              'p1': s['p2'],
              'p2': s['p1'],
            };
            if (s['tb1'] != null && s['tb2'] != null) {
              flipped['tb1'] = s['tb2'];
              flipped['tb2'] = s['tb1'];
            }
            return flipped;
          }).toList();

    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;

    Timestamp? matchDateTs = match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final winnerUid = match['winnerUid'] ?? '';
    // winnerUid stores the creator's UID when they won.
    // For a claimed match viewed by the claimant, flip the win/loss perspective.
    final bool currentUserWon = userIsCreator
        ? winnerUid == currentUid
        : winnerUid != currentUid;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GuestMatchDetailsScreen(
                matchId: matchDoc.id,
                playerName: currentUserName,
                opponentName: opponentName,
                opponentPhone: opponentPhone,
                sets: sets,
                location: location,
                duration: duration,
                matchDate: matchDate,
                // Pass a synthetic winnerUid from current user's perspective:
                // if currentUserWon, use currentUid; otherwise use a placeholder
                winnerUid: currentUserWon ? currentUid : 'opponent',
                currentUserUid: currentUid,
              ),
            ),
          );

          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2),
                ),
              );
            });
          }
        },
        child: _GuestMatchCard(
          playerName: currentUserName,
          opponentName: opponentName,
          sets: sets,
          location: location,
          duration: duration,
          matchDate: matchDate,
          currentUserWon: currentUserWon,
          isTie: false, // guest matches can't be tied via app flow
          loc: loc,
        ),
      ),
    );
  }

  Widget _buildDoublesMatchCard(
    BuildContext context,
    DocumentSnapshot matchDoc,
    AppLocalizations loc,
    String currentUid,
  ) {
    final match = matchDoc.data() as Map<String, dynamic>;
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final winnerTeam = match['winnerTeam'] as int? ?? 1;
    final bool team1Won = winnerTeam == 1;

    final rawSets = match['result']?['sets'] ?? [];
    final location = match['result']?['location'] ?? '';
    final duration = match['result']?['durationMinutes'] ?? 0;
    Timestamp? matchDateTs = match['result']?['matchDate'];
    final DateTime matchDate =
        matchDateTs != null ? matchDateTs.toDate() : DateTime.now();

    final team1Label = '${team1['player1'] ?? ''} / ${team1['player2'] ?? ''}';
    final team2Label = '${team2['player1'] ?? ''} / ${team2['player2'] ?? ''}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoublesMatchDetailsScreen(
                matchId: matchDoc.id,
                team1Player1: team1['player1'] ?? '',
                team1Player2: team1['player2'] ?? '',
                team2Player1: team2['player1'] ?? '',
                team2Player2: team2['player2'] ?? '',
                winnerTeam: winnerTeam,
                sets: List.from(rawSets),
                location: location,
                duration: duration,
                matchDate: matchDate,
              ),
            ),
          );
          if (result == true && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(loc.matchDeleted),
                  duration: const Duration(seconds: 2)),
              );
            });
          }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 35, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Team 1
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(team1Label,
                                style: TextStyle(
                                  fontWeight: team1Won
                                      ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis)),
                              if (team1Won) ...[
                                const SizedBox(width: 4),
                                const Text('🏆'),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: rawSets.map<Widget>((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p1 > p2;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(p1.toString(),
                                style: TextStyle(fontSize: 16,
                                  fontWeight: won ? FontWeight.bold : FontWeight.normal,
                                  color: won ? Colors.green.shade700 : Colors.grey)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Team 2
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(child: Text(team2Label,
                                style: TextStyle(
                                  fontWeight: !team1Won
                                      ? FontWeight.bold : FontWeight.normal),
                                overflow: TextOverflow.ellipsis)),
                              if (!team1Won) ...[
                                const SizedBox(width: 4),
                                const Text('🏆'),
                              ],
                            ],
                          ),
                        ),
                        Row(
                          children: rawSets.map<Widget>((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p2 > p1;
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(p2.toString(),
                                style: TextStyle(fontSize: 16,
                                  fontWeight: won ? FontWeight.bold : FontWeight.normal,
                                  color: won ? Colors.green.shade700 : Colors.grey)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Win/Loss badge
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: team1Won ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    team1Won ? loc.win : loc.loss,
                    style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              // Doubles badge
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    loc.doubles.toUpperCase(),
                    style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

    Widget _buildMatchList(
    BuildContext context,
    AppLocalizations loc,
    String currentUid,
    List<String> types,
    String emptyTitle,
    String emptySubtitle,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: currentUid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(loc.loading),
              ],
            ),
          );
        }

        // Filter by type
        final docs = snapshot.data!.docs.where((doc) {
          final match = doc.data() as Map<String, dynamic>;
          final type = match['type'] as String? ?? 'regular';
          return types.contains(type);
        }).toList();

        if (docs.isEmpty) {
          return EmptyState(
            icon: Icons.history,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final matchDoc = docs[index];
            final match = matchDoc.data() as Map<String, dynamic>;
            final type = match['type'] as String? ?? 'regular';

            if (type == 'doubles_guest') {
              return _buildDoublesMatchCard(
                context, matchDoc, loc, currentUid,
              );
            } else if (type == 'guest') {
              return _buildGuestMatchCard(
                context, matchDoc, loc, currentUid,
              );
            } else {
              return _buildRegularMatchCard(
                context, matchDoc, loc, currentUid,
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.matchHistory),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: loc.singles),
              Tab(text: loc.doubles),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // Singles tab: regular + guest matches
              _buildMatchList(
                context, loc, currentUid,
                ['regular', 'guest'],
                loc.noMatchHistory,
                loc.playMatchesToSeeHistory,
              ),
              // Doubles tab: doubles_guest matches
              _buildMatchList(
                context, loc, currentUid,
                ['doubles_guest'],
                loc.noDoublesHistory,
                loc.playDoublesToSeeHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline card widget for guest matches — visually distinct with orange accent
class _GuestMatchCard extends StatelessWidget {
  final String playerName;
  final String opponentName;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final bool currentUserWon;
  final bool isTie;
  final AppLocalizations loc;

  const _GuestMatchCard({
    required this.playerName,
    required this.opponentName,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
    required this.currentUserWon,
    required this.isTie,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 35, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player rows
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          playerName,
                          style: TextStyle(
                            fontWeight: currentUserWon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (currentUserWon) ...[
                          const SizedBox(width: 4),
                          const Text('🏆'),
                        ],
                      ],
                    ),
                    Row(
                      children: sets.map<Widget>((set) {
                        final p1 = set['p1'] ?? 0;
                        final p2 = set['p2'] ?? 0;
                        final won = p1 > p2;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            p1.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: won
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: won
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          opponentName,
                          style: TextStyle(
                            fontWeight: !currentUserWon
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (!currentUserWon) ...[
                          const SizedBox(width: 4),
                          const Text('🏆'),
                        ],
                      ],
                    ),
                    Row(
                      children: sets.map<Widget>((set) {
                        final p1 = set['p1'] ?? 0;
                        final p2 = set['p2'] ?? 0;
                        final won = p2 > p1;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            p2.toString(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: won
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: won
                                  ? Colors.green.shade700
                                  : Colors.grey,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  '$location • ${matchDate.day}/${matchDate.month}/${matchDate.year} • $duration min',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Win/Loss/Tie badge top-right
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: isTie
                    ? Colors.grey[600]
                    : currentUserWon ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isTie ? loc.tieMatchLabel
                    : currentUserWon ? loc.win : loc.loss,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          // Guest badge top-left (orange)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Text(
                loc.guestMatchBadge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}