import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
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
  int ties = 0;
  int setsWon = 0;
  int setsLost = 0;
  int tiebreaksWon = 0;
  int tiebreaksLost = 0;
  double winRate = 0;
  int averageDuration = 0;

  // Current streak: positive = consecutive wins, negative = consecutive
  // losses, 0 = no active streak (no matches yet, or the most recent
  // match was a tie).
  int currentStreak = 0;

  // Matches-per-month activity, oldest to newest, always exactly 6
  // entries (zero-filled for months with no matches) so the bar chart
  // has a stable x-axis regardless of how sparse recent activity is.
  final List<int> monthlyCounts = List.filled(6, 0);
  final List<DateTime> monthlyLabels = [];

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
      ties = 0;
      setsWon = 0;
      setsLost = 0;
      tiebreaksWon = 0;
      tiebreaksLost = 0;

      // (matchDate, outcome) per match of this tab's type, outcome is
      // 1 = win, -1 = loss, 0 = tie — used below for the streak and
      // monthly-activity computations. Matches with no resolvable date
      // still count toward every other stat, just not these two.
      final List<MapEntry<DateTime, int>> dated = [];

      for (var doc in snapshot.docs) {
        final match = doc.data() as Map<String, dynamic>?;
        if (match == null) continue;

        final type = match['type'] as String? ?? 'regular';
        final isDoublesMatch = type == 'doubles_guest';

        if (widget.isDoubles != isDoublesMatch) continue;

        matchesPlayed++;

        final bool isTie = match['isTie'] == true;
        bool userWon = false;

        if (!isTie) {
          if (widget.isDoubles) {
            // doubles_guest only ever has the creator as a real
            // account, so no claimant-perspective issue here.
            final winnerTeam = match['winnerTeam'] as int? ?? 0;
            userWon = winnerTeam == 1;
          } else if (type == 'guest') {
            // winnerUid is the creator's real UID when they won, or
            // the literal 'guest' placeholder when the (then
            // unregistered) opponent won — that placeholder is set at
            // creation time and never updated, so it can never equal
            // the claimant's UID once they sign up. Compare against
            // createdBy (stable) rather than uid (whose meaning flips
            // depending on who's viewing), same fix as
            // match_history_screen.dart / h2h_service.dart.
            final createdBy = match['createdBy'] as String? ?? '';
            final bool creatorWon = match['winnerUid'] == createdBy;
            final bool userIsCreator = createdBy == uid;
            userWon = userIsCreator ? creatorWon : !creatorWon;
          } else {
            userWon = match['winnerUid'] == uid;
          }
          if (userWon) { wins++; } else { losses++; }
        } else {
          ties++;
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
          if (myScore > opponentScore) { setsWon++; } else { setsLost++; }

          // A tiebreak (tb1/tb2 present) decides its set, so whoever
          // won the set also won that tiebreak.
          final bool hadTiebreak =
              setMap['tb1'] != null && setMap['tb2'] != null;
          if (hadTiebreak) {
            if (myScore > opponentScore) {
              tiebreaksWon++;
            } else {
              tiebreaksLost++;
            }
          }
        }

        final summary = match['summary'] as Map<String, dynamic>? ?? {};
        final Timestamp? matchDateTs =
            summary['matchDate'] as Timestamp? ??
                result['matchDate'] as Timestamp?;
        if (matchDateTs != null) {
          dated.add(
            MapEntry(matchDateTs.toDate(), isTie ? 0 : (userWon ? 1 : -1)),
          );
        }
      }

      if (matchesPlayed > 0) {
        winRate = (wins / matchesPlayed) * 100;
        averageDuration = (totalDuration / matchesPlayed).round();
      }

      // Streak: walk newest-first, counting consecutive identical
      // outcomes until a tie or the opposite result breaks it.
      dated.sort((a, b) => b.key.compareTo(a.key));
      currentStreak = 0;
      if (dated.isNotEmpty && dated.first.value != 0) {
        final int sign = dated.first.value;
        int count = 0;
        for (final entry in dated) {
          if (entry.value == sign) {
            count++;
          } else {
            break;
          }
        }
        currentStreak = sign * count;
      }

      // Monthly activity: last 6 months including the current one,
      // oldest first, zero-filled.
      final now = DateTime.now();
      monthlyLabels
        ..clear()
        ..addAll(List.generate(
          6,
          (i) => DateTime(now.year, now.month - (5 - i)),
        ));
      for (var i = 0; i < monthlyCounts.length; i++) {
        monthlyCounts[i] = 0;
      }
      for (final entry in dated) {
        final d = entry.key;
        for (var i = 0; i < monthlyLabels.length; i++) {
          final label = monthlyLabels[i];
          if (d.year == label.year && d.month == label.month) {
            monthlyCounts[i]++;
            break;
          }
        }
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

    final hasTiebreaks = tiebreaksWon + tiebreaksLost > 0;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero row: win-rate ring + streak badge. Deliberately no
            // crossAxisAlignment: stretch here — this Row sits inside a
            // SingleChildScrollView's Column, which gives it an unbounded
            // height, and "stretch" tries to pass that infinite height
            // down into the chart widgets, crashing with "BoxConstraints
            // forces an infinite height". Both cards already fix their
            // own height via an internal SizedBox(height: 140), so no
            // stretch is needed for them to line up.
            Row(
              children: [
                Expanded(child: _WinRateRing(winRate: winRate, loc: loc)),
                const SizedBox(width: 12),
                Expanded(
                  child: _StreakCard(streak: currentStreak, loc: loc),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SimpleStatRow(
              children: [
                _MiniStat(
                  label: widget.isDoubles
                      ? loc.doublesMatchesPlayed
                      : loc.matchesPlayed,
                  value: matchesPlayed.toString(),
                ),
                _MiniStat(
                  label: widget.isDoubles
                      ? loc.doublesAvgDuration
                      : loc.averageMatchDuration,
                  value: '$averageDuration ${loc.minutesShort}',
                ),
              ],
            ),

            const SizedBox(height: 24),
            _SectionTitle(loc.statsResultsTitle),
            const SizedBox(height: 8),
            _ResultsDonut(
              wins: wins,
              losses: losses,
              ties: ties,
              loc: loc,
              isDoubles: widget.isDoubles,
            ),

            const SizedBox(height: 24),
            _SectionTitle(loc.statsSetsTitle),
            const SizedBox(height: 8),
            _WonLostBarChart(
              won: setsWon,
              lost: setsLost,
              wonLabel: widget.isDoubles ? loc.doublesSetsWon : loc.totalSetsWon,
              lostLabel:
                  widget.isDoubles ? loc.doublesSetsLost : loc.totalSetsLost,
            ),

            if (hasTiebreaks) ...[
              const SizedBox(height: 24),
              _SectionTitle(loc.statsTiebreaksTitle),
              const SizedBox(height: 8),
              _WonLostBarChart(
                won: tiebreaksWon,
                lost: tiebreaksLost,
                wonLabel: widget.isDoubles
                    ? loc.doublesTiebreaksWon
                    : loc.totalTiebreaksWon,
                lostLabel: widget.isDoubles
                    ? loc.doublesTiebreaksLost
                    : loc.totalTiebreaksLost,
              ),
            ],

            const SizedBox(height: 24),
            _SectionTitle(loc.statsActivityTitle,
                subtitle: loc.statsMatchesPerMonthSubtitle),
            const SizedBox(height: 8),
            _ActivityBarChart(
              counts: monthlyCounts,
              labels: monthlyLabels,
              localeName: loc.localeName,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}

class _SimpleStatRow extends StatelessWidget {
  final List<Widget> children;
  const _SimpleStatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .map((c) => Expanded(child: c))
          .expand((w) => [w, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Donut-style win-rate ring with the percentage centered inside — the
/// "hero" number for this tab, replacing the old plain win-rate StatTile.
class _WinRateRing extends StatelessWidget {
  final double winRate;
  final AppLocalizations loc;
  const _WinRateRing({required this.winRate, required this.loc});

  @override
  Widget build(BuildContext context) {
    final clamped = winRate.clamp(0, 100).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 0,
                  centerSpaceRadius: 42,
                  sections: [
                    PieChartSectionData(
                      value: clamped,
                      color: Colors.green.shade600,
                      showTitle: false,
                      radius: 16,
                    ),
                    PieChartSectionData(
                      value: 100 - clamped,
                      color: Colors.grey.shade200,
                      showTitle: false,
                      radius: 16,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${clamped.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    loc.winRate,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small card showing the current win/loss streak, e.g. "🔥 3-match win
/// streak" — hidden state (just the title + "No active streak") when the
/// most recent match was a tie or there's no streak yet.
class _StreakCard extends StatelessWidget {
  final int streak;
  final AppLocalizations loc;
  const _StreakCard({required this.streak, required this.loc});

  @override
  Widget build(BuildContext context) {
    final bool isWinStreak = streak > 0;
    final bool isLossStreak = streak < 0;
    final String text = isWinStreak
        ? loc.winStreakLabel(streak)
        : isLossStreak
            ? loc.lossStreakLabel(-streak)
            : loc.noActiveStreak;
    final Color color = isWinStreak
        ? Colors.green.shade700
        : isLossStreak
            ? Colors.red.shade700
            : Colors.grey.shade600;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                loc.currentStreakTitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Icon(
                isWinStreak
                    ? Icons.local_fire_department
                    : isLossStreak
                        ? Icons.trending_down
                        : Icons.remove,
                color: color,
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Win / Loss / Tie donut with a legend below.
class _ResultsDonut extends StatelessWidget {
  final int wins;
  final int losses;
  final int ties;
  final AppLocalizations loc;
  final bool isDoubles;

  const _ResultsDonut({
    required this.wins,
    required this.losses,
    required this.ties,
    required this.loc,
    required this.isDoubles,
  });

  @override
  Widget build(BuildContext context) {
    final winColor = Colors.green.shade600;
    final lossColor = Colors.red.shade400;
    final tieColor = Colors.grey.shade500;

    final sections = <PieChartSectionData>[
      if (wins > 0)
        PieChartSectionData(
          value: wins.toDouble(),
          color: winColor,
          title: '$wins',
          radius: 34,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      if (losses > 0)
        PieChartSectionData(
          value: losses.toDouble(),
          color: lossColor,
          title: '$losses',
          radius: 34,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      if (ties > 0)
        PieChartSectionData(
          value: ties.toDouble(),
          color: tieColor,
          title: '$ties',
          radius: 34,
          titleStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Sized smaller than the old 140x140 box (which the ring's
            // radius + centerSpaceRadius actually exceeded, causing it to
            // overflow past the box and touch the card's edge) and given
            // extra spacing before the legend so the two don't crowd
            // each other.
            SizedBox(
              height: 120,
              width: 120,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: 2,
                  centerSpaceRadius: 24,
                ),
              ),
            ),
            const SizedBox(width: 28),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LegendRow(
                    color: winColor,
                    label: isDoubles ? loc.doublesWins : loc.wins,
                    value: wins,
                  ),
                  const SizedBox(height: 8),
                  _LegendRow(
                    color: lossColor,
                    label: isDoubles ? loc.doublesLosses : loc.losses,
                    value: losses,
                  ),
                  if (ties > 0) ...[
                    const SizedBox(height: 8),
                    _LegendRow(color: tieColor, label: loc.ties, value: ties),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  const _LegendRow({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Text(
          '$value',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Simple two-bar "won vs lost" chart, reused for both sets and
/// tiebreaks so the two sections look identical apart from their data.
class _WonLostBarChart extends StatelessWidget {
  final int won;
  final int lost;
  final String wonLabel;
  final String lostLabel;

  const _WonLostBarChart({
    required this.won,
    required this.lost,
    required this.wonLabel,
    required this.lostLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = [won, lost, 1].reduce((a, b) => a > b ? a : b).toDouble();
    final wonColor = Colors.green.shade600;
    final lostColor = Colors.red.shade400;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceEvenly,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                // Shows the bar's own count above it, reusing the same
                // x-axis positions as bottomTitles (0 = won, 1 = lost) —
                // otherwise the bars have no visible number at all.
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final count = value.toInt() == 0 ? won : lost;
                      return Text(
                        '$count',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final text = value.toInt() == 0 ? wonLabel : lostLabel;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          text,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                BarChartGroupData(x: 0, barRods: [
                  BarChartRodData(
                    toY: won.toDouble(),
                    color: wonColor,
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ]),
                BarChartGroupData(x: 1, barRods: [
                  BarChartRodData(
                    toY: lost.toDouble(),
                    color: lostColor,
                    width: 40,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ]),
              ],
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ),
    );
  }
}

/// Matches-per-month activity bar chart, last 6 months.
class _ActivityBarChart extends StatelessWidget {
  final List<int> counts;
  final List<DateTime> labels;
  final String localeName;

  const _ActivityBarChart({
    required this.counts,
    required this.labels,
    required this.localeName,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = counts.isEmpty
        ? 1.0
        : [...counts, 1].reduce((a, b) => a > b ? a : b).toDouble();
    final barColor = Colors.blue.shade400;
    final monthFormat = intl.DateFormat.MMM(localeName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: SizedBox(
          height: 160,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceEvenly,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                // Count above each month's bar, same reasoning as
                // _WonLostBarChart's topTitles above.
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= counts.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${counts[i]}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          monthFormat.format(labels[i]),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(counts.length, (i) {
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    color: barColor,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ]);
              }),
              barTouchData: BarTouchData(enabled: false),
            ),
          ),
        ),
      ),
    );
  }
}
