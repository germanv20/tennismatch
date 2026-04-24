import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/empty_state.dart';

class PlayerStatisticsScreen extends StatelessWidget {
  final String userId;

  const PlayerStatisticsScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.playerStatisticsTitle),
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
        body: TabBarView(
          children: [
            _StatsTab(userId: userId, isDoubles: false),
            _StatsTab(userId: userId, isDoubles: true),
          ],
        ),
      ),
    );
  }
}

class _StatsTab extends StatefulWidget {
  final String userId;
  final bool isDoubles;

  const _StatsTab({required this.userId, required this.isDoubles});

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  int matchesPlayed = 0;
  int wins = 0;
  int losses = 0;
  int setsWon = 0;
  int setsLost = 0;
  double winRate = 0;
  int averageDuration = 0;

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

      for (var doc in snapshot.docs) {
        final match = doc.data() as Map<String, dynamic>?;
        if (match == null) continue;

        final type = match['type'] as String? ?? 'regular';
        final isDoublesMatch = type == 'doubles_guest';

        if (widget.isDoubles != isDoublesMatch) continue;

        matchesPlayed++;

        if (widget.isDoubles) {
          final winnerTeam = match['winnerTeam'] as int? ?? 0;
          if (winnerTeam == 1) wins++; else losses++;
        } else {
          if (match['winnerUid'] == uid) wins++; else losses++;
        }

        final result = match['result'] as Map<String, dynamic>? ?? {};
        final duration = (result['durationMinutes'] ?? 0) as num;
        totalDuration += duration.toInt();

        final sets = result['sets'] as List? ?? [];
        final String? player1Uid = match['player1Uid'] as String?;
        final bool userIsP1 = widget.isDoubles ? true : (player1Uid == uid);

        for (var set in sets) {
          final setMap = set as Map<String, dynamic>? ?? {};
          final p1 = (setMap['p1'] ?? 0) as int;
          final p2 = (setMap['p2'] ?? 0) as int;
          final int myScore = userIsP1 ? p1 : p2;
          final int opponentScore = userIsP1 ? p2 : p1;
          if (myScore > opponentScore) setsWon++; else setsLost++;
        }
      }

      if (matchesPlayed > 0) {
        winRate = (wins / matchesPlayed) * 100;
        averageDuration = (totalDuration / matchesPlayed).round();
      }

    } catch (e) {
      debugPrint('STATS ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loc = AppLocalizations.of(context)!;

    if (loading) {
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

    if (matchesPlayed == 0) {
      return EmptyState(
        icon: Icons.bar_chart,
        title: widget.isDoubles ? loc.noDoublesStats : loc.noStatsYet,
        subtitle: widget.isDoubles
            ? loc.playFirstDoublesMatch
            : loc.playFirstMatchStats,
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              StatTile(
                widget.isDoubles ? loc.doublesMatchesPlayed : loc.matchesPlayed,
                matchesPlayed.toString(),
              ),
              StatTile(
                widget.isDoubles ? loc.doublesWins : loc.wins,
                wins.toString(),
              ),
              StatTile(
                widget.isDoubles ? loc.doublesLosses : loc.losses,
                losses.toString(),
              ),
              StatTile(
                widget.isDoubles ? loc.doublesWinRate : loc.winRate,
                '${winRate.toStringAsFixed(1)}%',
              ),
              StatTile(
                widget.isDoubles ? loc.doublesSetsWon : loc.totalSetsWon,
                setsWon.toString(),
              ),
              StatTile(
                widget.isDoubles ? loc.doublesSetsLost : loc.totalSetsLost,
                setsLost.toString(),
              ),
              StatTile(
                widget.isDoubles ? loc.doublesAvgDuration : loc.averageMatchDuration,
                '$averageDuration ${loc.minutesShort}',
              ),
            ],
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
        title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}