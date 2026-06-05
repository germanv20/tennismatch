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
  final String? notes;

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
    this.notes,
  });

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen> {

  int h2hMatches = 0;
  int h2hWins = 0;
  int h2hLosses = 0;
  int h2hTies = 0;
  int h2hSetsWon = 0;
  int h2hSetsLost = 0;

  bool loadingH2H = true;
  bool hasMarkedSeen = false;
  bool hasHandledDeletion = false;

  @override
  void initState() {
    super.initState();
    loadHeadToHead();
  }

  void handleMatchDeleted() {
    if (hasHandledDeletion) return;
    hasHandledDeletion = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, true);
      });
    });
  }

  Widget buildDeletedUI() {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            Text(loc.matchDeleted,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(loc.matchNoLongerAvailable,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  bool hasShownResultDialog = false;

  void handleDeletionResult(bool isAccepted, Map<String, dynamic> deletionRequest) {
    if (hasShownResultDialog) return;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final loc = AppLocalizations.of(context)!;
    if (deletionRequest['requestedBy'] != currentUid) return;
    hasShownResultDialog = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(isAccepted ? loc.matchDeleted : loc.requestRejected),
          content: Text(isAccepted
              ? loc.opponentAcceptedDeletion
              : loc.opponentRejectedDeletion),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (isAccepted) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('matches')
                        .doc(widget.matchId)
                        .delete();
                    if (!mounted) return;
                    Navigator.pop(context, true);
                  } catch (e) {
                    debugPrint('Delete failed: $e');
                    if (!mounted) return;
                    hasShownResultDialog = false;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.somethingWentWrong)),
                    );
                  }
                } else {
                  try {
                    await FirebaseFirestore.instance
                        .collection('matches')
                        .doc(widget.matchId)
                        .update({'deletionRequest': FieldValue.delete()});
                  } catch (e) {
                    debugPrint('Clear deletion request failed: $e');
                  }
                }
              },
              child: Text(loc.ok),
            ),
          ],
        ),
      );
    });
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
    int ties = 0;
    int setsWon = 0;
    int setsLost = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final players = List<String>.from(data['players'] ?? []);
      if (!players.contains(opponentUid)) continue;
      matches++;
      final bool isTie = data['isTie'] == true;
      if (isTie) {
        ties++;
      } else if (data['winnerUid'] == uid) {
        wins++;
      } else {
        losses++;
      }

      final result = data['result'] ?? {};
      final sets = result['sets'] ?? [];
      final bool userIsP1 = data['player1Uid'] == uid;

      for (var set in sets) {
        final p1 = set['p1'] ?? 0;
        final p2 = set['p2'] ?? 0;
        int myScore = userIsP1 ? p1 : p2;
        int opponentScore = userIsP1 ? p2 : p1;
        if (myScore > opponentScore) setsWon++; else setsLost++;
      }
    }

    if (!mounted) return;
    setState(() {
      h2hMatches = matches;
      h2hWins = wins;
      h2hLosses = losses;
      h2hTies = ties;
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
      if (set['p1'] > set['p2']) playerSetsWon++; else opponentSetsWon++;
    }

    final bool playerWon = playerSetsWon > opponentSetsWon;
    final winnerName = playerWon ? widget.playerName : widget.opponentName;
    final loserName = playerWon ? widget.opponentName : widget.playerName;

    return Scaffold(
      appBar: AppBar(title: Text(loc.matchDetailsTitle)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .doc(widget.matchId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            if (error.contains('permission-denied')) {
              handleMatchDeleted();
              return buildDeletedUI();
            }
            return Center(child: Text(loc.somethingWentWrong));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            handleMatchDeleted();
            return buildDeletedUI();
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
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(widget.matchId)
                    .update({
                  'deletionRequest.seenBy': FieldValue.arrayUnion([currentUid])
                });
              } catch (e) {
                debugPrint('❌ ERROR updating seenBy: $e');
              }
            });
          }

          final isRequester = deletionRequest != null &&
              deletionRequest['requestedBy'] == currentUid;
          final isPending = deletionRequest != null &&
              deletionRequest['status'] == 'pending';
          final isRejected = deletionRequest != null &&
              deletionRequest['status'] == 'rejected';
          final isAccepted = deletionRequest != null &&
              deletionRequest['status'] == 'accepted';

          // Use null-check pattern: req is Map<String, dynamic> (non-nullable)
          final req = deletionRequest;
          if (req != null && (isAccepted || isRejected)) {
            handleDeletionResult(isAccepted, req);
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Text(loc.result,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    // Show tie label or winner sentence
                    if (data['isTie'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          loc.matchEndedAsTie,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    else
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black, fontSize: 16),
                          children: [
                            TextSpan(text: loc.matchResultSentence(winnerName, loserName)),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [

                            // ── Header: player names ──
                            IntrinsicHeight(
                              child: Row(
                                children: [
                                  // Set label spacer
                                  const SizedBox(width: 56),
                                  // Player 1 name — centered over score area
                                  Expanded(
                                    child: Text(
                                      widget.playerName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  // Player 2 name — centered over score area
                                  Expanded(
                                    child: Text(
                                      widget.opponentName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(height: 16),

                            // ── One row per set ──
                            ...widget.sets.asMap().entries.map((entry) {
                              final index = entry.key;
                              final set = entry.value;
                              final p1 = set['p1'] as int;
                              final p2 = set['p2'] as int;
                              final p1Won = p1 > p2;
                              final hasTb = set['tb1'] != null && set['tb2'] != null;

                              // tb1 belongs to p1 (current user perspective after flip in history screen)
                              // Show tiebreak on LOSER's side only
                              final p1TbText = (hasTb && !p1Won) ? '(${set['tb1']})' : '';
                              final p2TbText = (hasTb && p1Won) ? '(${set['tb2']})' : '';

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    // Set label
                                    SizedBox(
                                      width: 56,
                                      child: Text(
                                        loc.setLabel(index + 1),
                                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                      ),
                                    ),
                                    // P1 score + tiebreak — centered as a unit
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            p1.toString(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: p1Won ? FontWeight.bold : FontWeight.normal,
                                              color: p1Won ? Colors.black : Colors.grey[500],
                                            ),
                                          ),
                                          if (p1TbText.isNotEmpty) ...[
                                            const SizedBox(width: 3),
                                            Text(
                                              p1TbText,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // P2 score + tiebreak — centered as a unit
                                    Expanded(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            p2.toString(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: !p1Won ? FontWeight.bold : FontWeight.normal,
                                              color: !p1Won ? Colors.black : Colors.grey[500],
                                            ),
                                          ),
                                          if (p2TbText.isNotEmpty) ...[
                                            const SizedBox(width: 3),
                                            Text(
                                              p2TbText,
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                                        const SizedBox(height: 20),

                    Text('${loc.locationLabel}: ${widget.location}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${loc.durationLabel}: ${widget.duration} ${loc.minutesShort}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('${loc.dateLabel}: ${widget.matchDate.day}/${widget.matchDate.month}/${widget.matchDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),

                    if (widget.notes != null && widget.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_outlined,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.notes!,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 30),

                    Text(loc.headToHead,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),

                    loadingH2H
                      ? const Center(child: CircularProgressIndicator())
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [Text(loc.headToHead), Text(h2hMatches.toString())]),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [Text(loc.wins), Text(h2hWins.toString())]),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [Text(loc.losses), Text(h2hLosses.toString())]),
                                if (h2hTies > 0)
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [Text(loc.ties), Text(h2hTies.toString())]),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [Text(loc.totalSetsWon), Text(h2hSetsWon.toString())]),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [Text(loc.totalSetsLost), Text(h2hSetsLost.toString())]),
                              ],
                            ),
                          ),
                        ),

                    const SizedBox(height: 30),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (deletionRequest == null) ...[
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: Text(loc.deleteMatch),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(loc.deleteMatchQuestion),
                                  content: Text(loc.deleteMatchConfirmation),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.cancel)),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: Text(loc.confirm)),
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
                        else if (isPending && isRequester) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(8)),
                            child: Text(loc.waitingOpponentApproval,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ]
                        else if (isPending && !isRequester) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.opponentRequestedDeletion,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                                            .update({
                                          'deletionRequest.status': 'accepted',
                                          'deletionRequest.resolvedAt': FieldValue.serverTimestamp(),
                                          'deletionRequest.resolvedBy': currentUid,
                                          'deletionRequest.seenBy': [currentUid],
                                        });
                                        await H2HService.recalculateHeadToHead(
                                          userA: currentUid,
                                          userB: widget.opponentUid,
                                        );
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(loc.deletionAcceptedWaiting)),
                                        );
                                      },
                                      child: Text(loc.accept),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () async {
                                        await FirebaseFirestore.instance
                                            .collection('matches')
                                            .doc(widget.matchId)
                                            .update({
                                          'deletionRequest.status': 'rejected',
                                          'deletionRequest.resolvedAt': FieldValue.serverTimestamp(),
                                          'deletionRequest.resolvedBy': currentUid,
                                          'deletionRequest.seenBy': [currentUid],
                                        });
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(loc.requestRejected)),
                                        );
                                      },
                                      child: Text(loc.reject),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ]
                        else if (isAccepted && !isRequester) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)),
                            child: Text(loc.deletionAccepted,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ]
                        else if (isRejected) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                            child: Text(loc.deletionRejected,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),

                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}