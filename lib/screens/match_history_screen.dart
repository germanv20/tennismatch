import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../../widgets/match_card.dart';
import '../../widgets/empty_state.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {

  String currentUserName = "";

  List<DocumentSnapshot> matches = [];

  bool isLoading = false;
  bool hasMore = true;

  DocumentSnapshot? lastDocument;

  final int pageSize = 20;

  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = AppLocalizations.of(context)!;

      loadCurrentUserName(loc.failedToLoadUser);
      loadMatches(loc.failedToLoadMatches);
    });

    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 100) {

        final loc = AppLocalizations.of(context)!;
        loadMatches(loc.failedToLoadMatches);
      }
    });
  }

  Future<void> loadCurrentUserName(String errorMessage) async {

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      setState(() {
        currentUserName = doc['name'];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)), // "Failed to load user info"
      );
    }
  }

  Future<void> loadMatches(String errorMessage) async {
    
    if (isLoading || !hasMore) return;

    setState(() {
      isLoading = true;
    });

    try {
      final currentUid = FirebaseAuth.instance.currentUser!.uid;

      Query query = FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: currentUid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        lastDocument = snapshot.docs.last;
      }

      if (snapshot.docs.length < pageSize) {
        hasMore = false;
      }

      if (!mounted) return;

      setState(() {
        matches.addAll(snapshot.docs);
        isLoading = false;
      });

    } catch (e) {

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)), // "Error loading match history"
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final loc = AppLocalizations.of(context)!;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchHistory), // "Match History"
      ),
      body: SafeArea(
        child: matches.isEmpty && isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(loc.loading),
                ],
              ),
            )
          : matches.isEmpty
              ? EmptyState(
                  icon: Icons.history,
                  title: loc.noMatchHistory, // "No match history yet"
                  subtitle: loc.playMatchesToSeeHistory, // "Play some matches to see them here 🎾"
                )
              : ListView.builder(
                  controller: scrollController,
                  itemCount: matches.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {

                    if (index == matches.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final match =
                        matches[index].data() as Map<String, dynamic>;

                    final List players = match['players'] ?? [];
                    final playerNames = match['playerNames'] ?? {};

                    final opponentUid =
                        players.firstWhere((uid) => uid != currentUid);

                    final opponentName =
                        playerNames[opponentUid] ?? loc.unknown;

                    final summary =
                        match['summary'] as Map<String, dynamic>? ?? {};

                    final player1Uid = match['player1Uid'];
                    final player2Uid = match['player2Uid'];

                    final bool currentUserIsP1 = currentUid == player1Uid;

                    // Safe match date handling
                   Timestamp? matchDateTs =
                      summary['matchDate'] ?? match['result']?['matchDate'];

                    final DateTime matchDate =
                        matchDateTs != null
                            ? matchDateTs.toDate()
                            : DateTime.now();

                    // Real sets for UI display
                    final rawSets = match['result']?['sets'] ?? [];

                    // Fix perspective so p1 always = current user
                    List sets = [];

                    for (var set in rawSets) {
                      if (currentUserIsP1) {
                        sets.add(set);
                      } else {
                        sets.add({
                          'p1': set['p2'],
                          'p2': set['p1'],
                        });
                      }
                    }

                    final location = match['result']?['location'] ?? '';
                    final duration =
                        match['result']?['durationMinutes'] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: MatchCard(
                        playerName: currentUserName,
                        opponentName: opponentName,
                        opponentUid: opponentUid, 
                        sets: sets,
                        location: location,
                        duration: duration,
                        matchDate: matchDate,
                        winnerUid: match['winnerUid'],
                        currentUserUid: currentUid
                      ),
                    );
                  },
                ),
      ),
    );
  }
}
