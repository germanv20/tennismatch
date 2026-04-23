import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

class PlayerStatisticsScreen extends StatefulWidget {
  final String userId;

  const PlayerStatisticsScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PlayerStatisticsScreen> createState() =>
      _PlayerStatisticsScreenState();
}

class _PlayerStatisticsScreenState extends State<PlayerStatisticsScreen> {
  int matchesPlayed = 0;
  int wins = 0;
  int losses = 0;
  int setsWon = 0;
  int setsLost = 0;
  double winRate = 0;
  int averageDuration = 0;

  // Breakdown
  int regularMatches = 0;
  int guestMatches = 0;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = AppLocalizations.of(context)!;
      loadStats(loc.failedToLoadStats);
    });
  }

  Future<void> loadStats(String errorMessage) async {
    final uid = widget.userId;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('players', arrayContains: uid)
          .where('status', isEqualTo: 'completed')
          .get();

      int totalDuration = 0;

      matchesPlayed = 0;
      wins = 0;
      losses = 0;
      setsWon = 0;
      setsLost = 0;
      regularMatches = 0;
      guestMatches = 0;

      for (var doc in snapshot.docs) {
        final match = doc.data() as Map<String, dynamic>?;
        if (match == null) continue;

        matchesPlayed++;

        final isGuest = match['type'] == 'guest';
        if (isGuest) {
          guestMatches++;
        } else {
          regularMatches++;
        }

        if (match['winnerUid'] == uid) {
          wins++;
        } else {
          losses++;
        }

        final result = match['result'] as Map<String, dynamic>? ?? {};
        final duration = (result['durationMinutes'] ?? 0) as num;
        totalDuration += duration.toInt();

        final sets = result['sets'] as List? ?? [];

        // ✅ Use player1Uid for perspective — correct for both regular and guest
        // For guest matches player1Uid is always currentUid so this is safe
        final String? player1Uid = match['player1Uid'] as String?;
        final bool userIsP1 = player1Uid == uid;

        for (var set in sets) {
          final setMap = set as Map<String, dynamic>? ?? {};
          final p1 = (setMap['p1'] ?? 0) as int;
          final p2 = (setMap['p2'] ?? 0) as int;

          final int myScore = userIsP1 ? p1 : p2;
          final int opponentScore = userIsP1 ? p2 : p1;

          if (myScore > opponentScore) {
            setsWon++;
          } else {
            setsLost++;
          }
        }
      }

      if (matchesPlayed > 0) {
        winRate = (wins / matchesPlayed) * 100;
        averageDuration = (totalDuration / matchesPlayed).round();
      }
    } catch (e) {
      debugPrint('🔥 STATS ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(loc.loading),
            ],
          ),
        ),
      );
    }

    if (matchesPlayed == 0) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.playerStatisticsTitle)),
        body: EmptyState(
          icon: Icons.bar_chart,
          title: loc.noStatsYet,
          subtitle: loc.playFirstMatchStats,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(loc.playerStatisticsTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatTile(loc.matchesPlayed, matchesPlayed.toString()),
                StatTile(loc.wins, wins.toString()),
                StatTile(loc.losses, losses.toString()),
                StatTile(
                  loc.winRate,
                  '${winRate.toStringAsFixed(1)}%',
                ),
                StatTile(loc.totalSetsWon, setsWon.toString()),
                StatTile(loc.totalSetsLost, setsLost.toString()),
                StatTile(
                  loc.averageMatchDuration,
                  '$averageDuration ${loc.minutesShort}',
                ),

                // ── Match type breakdown ──
                if (guestMatches > 0) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 4),
                  _BreakdownTile(
                    label: 'App matches',
                    value: regularMatches,
                    color: Colors.green.shade600,
                  ),
                  _BreakdownTile(
                    label: loc.guestMatchBadge,
                    value: guestMatches,
                    color: Colors.orange.shade600,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;

  const StatTile(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _BreakdownTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
