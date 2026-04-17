import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:tennismatch/services/h2h_service.dart';

class MatchDetailsScreen extends StatefulWidget {

  final String playerName;
  final String opponentName;
  final String opponentUid;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final String matchId;
  final List players;

  const MatchDetailsScreen({
    super.key,
    required this.matchId,
    required this.players,
    required this.playerName,
    required this.opponentName,
    required this.opponentUid,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {

  int h2hMatches = 0;
  int h2hWins = 0;
  int h2hLosses = 0;
  int h2hSetsWon = 0;
  int h2hSetsLost = 0;

  bool loadingH2H = true;
  bool hasMarkedSeen = false;

  @override
  void initState() {
    super.initState();
    loadHeadToHead();
  }

  Future<void> loadHeadToHead() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final opponentUid = widget.opponentUid;

    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('status', isEqualTo: 'completed')
        .where('players', arrayContains: uid)
        .get();

    int matches = 0;
    int wins = 0;
    int losses = 0;
    int setsWon = 0;
    int setsLost = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final players = List<String>.from(data['players'] ?? []);

      // ✅ Only matches between these two players
      if (!players.contains(opponentUid)) continue;

      matches++;

      if (data['winnerUid'] == uid) {
        wins++;
      } else {
        losses++;
      }

      final result = data['result'] ?? {};
      final sets = result['sets'] ?? [];

      final bool userIsP1 = players[0] == uid;

      for (var set in sets) {
        final p1 = set['p1'] ?? 0;
        final p2 = set['p2'] ?? 0;

        int myScore = userIsP1 ? p1 : p2;
        int opponentScore = userIsP1 ? p2 : p1;

        if (myScore > opponentScore) {
          setsWon++;
        } else {
          setsLost++;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      h2hMatches = matches;
      h2hWins = wins;
      h2hLosses = losses;
      h2hSetsWon = setsWon;
      h2hSetsLost = setsLost;
      loadingH2H = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    final loc = AppLocalizations.of(context)!;

    int playerSetsWon = 0;
    int opponentSetsWon = 0;

    for (var set in widget.sets) {
      if (set['p1'] > set['p2']) {
        playerSetsWon++;
      } else {
        opponentSetsWon++;
      }
    }

    final bool playerWon = playerSetsWon > opponentSetsWon;

    final winnerName = playerWon ? widget.playerName : widget.opponentName;
    final loserName = playerWon ? widget.opponentName : widget.playerName;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle), // "Match Details"
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final deletionRequest = data['deletionRequest'] as Map<String, dynamic>?;
          final currentUid = FirebaseAuth.instance.currentUser!.uid;

          if (!hasMarkedSeen &&
              deletionRequest != null &&
              deletionRequest['status'] == 'pending' &&
              !(deletionRequest['seenBy'] ?? []).contains(currentUid)) {

            hasMarkedSeen = true;

            Future.microtask(() async {
              try {
                print("🔥 Attempting to mark deletionRequest as seen");

                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(widget.matchId)
                    .update({
                  'deletionRequest.seenBy': FieldValue.arrayUnion([currentUid])
                });

                print("✅ Successfully marked as seen");
              } catch (e) {
                print("❌ ERROR updating seenBy: $e");
              }
            });
          }

          final isRequester = deletionRequest != null &&
              deletionRequest['requestedBy'] == currentUid;

          final isPending = deletionRequest != null &&
              deletionRequest['status'] == 'pending';

          final isRejected = deletionRequest != null &&
              deletionRequest['status'] == 'rejected';

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(
                      loc.result, // "Result"
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.black, fontSize: 16),
                        children: [
                          TextSpan(
                            text: loc.matchResultSentence(winnerName, loserName),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [

                            // Header row (SET1 SET2 SET3...)
                            Row(
                              children: [
                                const SizedBox(width: 120),
                                ...widget.sets.asMap().entries.map((entry) {
                                  final index = entry.key;

                                  return Expanded(
                                    child: Center(
                                      child: Text(
                                        loc.setLabel(index + 1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Player 1 row
                            Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(widget.playerName),
                                ),
                                ...widget.sets.map((set) {

                                  final p1 = set['p1'];
                                  final p2 = set['p2'];
                                  final isWinner = p1 > p2;

                                  return Expanded(
                                    child: Center(
                                      child: Text(
                                        p1.toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                          color: isWinner ? Colors.black : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Player 2 row
                            Row(
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(widget.opponentName),
                                ),
                                ...widget.sets.map((set) {

                                  final p1 = set['p1'];
                                  final p2 = set['p2'];
                                  final isWinner = p2 > p1;

                                  return Expanded(
                                    child: Center(
                                      child: Text(
                                        p2.toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                                          color: isWinner ? Colors.black : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),

                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      '${loc.locationLabel}: ${widget.location}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${loc.durationLabel}: ${widget.duration} ${loc.minutesShort}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${loc.dateLabel}: ${widget.matchDate.day}/${widget.matchDate.month}/${widget.matchDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 30),

                    Text(
                      loc.headToHead, // "Head-to-Head"
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    loadingH2H
                      ? const Center(child: CircularProgressIndicator())
                        : Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.headToHead), // Matches
                                      Text(h2hMatches.toString()),
                                    ],
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.wins), // "Wins"
                                      Text(h2hWins.toString()),
                                    ],
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.losses), // "Losses"
                                      Text(h2hLosses.toString()),
                                    ],
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.totalSetsWon), // "Sets Won"
                                      Text(h2hSetsWon.toString()),
                                    ],
                                  ),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(loc.totalSetsLost), // "Sets Lost"
                                      Text(h2hSetsLost.toString()),
                                    ],
                                  ),                            

                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // 🔴 DELETE SECTION HERE (outside card)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (deletionRequest == null) ...[
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Delete Match'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete match?'),
                                        content: const Text('This will request deletion.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm != true) return;

                                    await FirebaseFirestore.instance
                                        .collection('matches')
                                        .doc(widget.matchId)
                                        .update({
                                      'deletionRequest': {
                                        'requestedBy': currentUid,
                                        'status': 'pending',
                                        'createdAt': FieldValue.serverTimestamp(),
                                        'seenBy': [currentUid],
                                      }
                                    });
                                  },
                                ),
                              ]

                              // 🟡 WAITING STATE (PERSISTENT)
                              else if (isPending && isRequester) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Waiting for opponent approval...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]

                              // 🟢 ACCEPT / REJECT
                              else if (isPending && !isRequester) ...[
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Opponent requested match deletion',
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection('matches')
                                                  .doc(widget.matchId)
                                                  .delete();

                                              await H2HService.recalculateHeadToHead(
                                                userA: currentUid,
                                                userB: widget.opponentUid,
                                              );

                                              if (!mounted) return;

                                              Navigator.pop(context);

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Match deleted')),
                                              );
                                            },
                                            child: const Text('Accept'),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                                            onPressed: () async {
                                              await FirebaseFirestore.instance
                                                  .collection('matches')
                                                  .doc(widget.matchId)
                                                  .update({
                                                    'deletionRequest': FieldValue.delete(),
                                                  });

                                              if (!mounted) return;

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Request rejected')),
                                              );
                                            },
                                            child: const Text('Reject'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ]

                              // 🔴 REJECTED STATE
                              else if (isRejected) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Deletion request was rejected',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]
                            ],
                          ),

                  ],
                ),
              ),
            ),
          );
        }
      ),        
    );
  }
}