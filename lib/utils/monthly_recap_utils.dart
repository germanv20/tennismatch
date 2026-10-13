import 'achievements_utils.dart' show computeWeeklyStreaks;

/// Pure monthly-recap computation (no Firebase/Flutter). See CLAUDE.md
/// ("Monthly recap").

enum RecapHighlight { bagel, winStreak, tiebreak, bigWin, none }

/// One completed match from the viewer's perspective.
class RecapMatch {
  final DateTime? date;

  /// 1 = win, -1 = loss, 0 = tie.
  final int outcome;
  final int durationMinutes;

  /// Real opponent account (regular matches only).
  final String? opponentUid;
  final String? opponentName;
  final String? location;
  final bool wonBagel;
  final bool wonTiebreak;

  /// My games minus their games across all sets.
  final int gameDiff;

  /// Set scores from my perspective, e.g. "6-1, 6-2".
  final String scoreText;

  const RecapMatch({
    required this.date,
    required this.outcome,
    required this.durationMinutes,
    required this.opponentUid,
    required this.opponentName,
    required this.location,
    required this.wonBagel,
    required this.wonTiebreak,
    required this.gameDiff,
    required this.scoreText,
  });
}

class MonthlyRecap {
  final int year;
  final int month;
  final int matches;
  final int previousMatches;
  final int wins;
  final int losses;
  final int ties;
  final int totalMinutes;
  final int distinctOpponents;
  final int newOpponents;
  final String? topOpponentName;
  final int topOpponentCount;
  final RecapHighlight highlight;

  /// Win-streak length (winStreak) or null.
  final int? highlightStreak;

  /// Score text (bigWin) or null.
  final String? highlightScore;
  final String? topCourt;
  final int topCourtCount;
  final int weeklyStreakAtEnd;

  /// Whether the user has ever completed a match (any month) — the
  /// "you didn't play" nudge is pointless for brand-new users.
  final bool hasEverPlayed;

  const MonthlyRecap({
    required this.year,
    required this.month,
    required this.matches,
    required this.previousMatches,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.totalMinutes,
    required this.distinctOpponents,
    required this.newOpponents,
    required this.topOpponentName,
    required this.topOpponentCount,
    required this.highlight,
    required this.highlightStreak,
    required this.highlightScore,
    required this.topCourt,
    required this.topCourtCount,
    required this.weeklyStreakAtEnd,
    required this.hasEverPlayed,
  });
}

bool _inMonth(DateTime d, int year, int month) =>
    d.year == year && d.month == month;

MonthlyRecap buildMonthlyRecap({
  required List<RecapMatch> all,
  required int year,
  required int month,
}) {
  final inMonth = all
      .where((m) => m.date != null && _inMonth(m.date!, year, month))
      .toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));

  final prev = DateTime(year, month - 1);
  final previousMatches = all
      .where((m) => m.date != null && _inMonth(m.date!, prev.year, prev.month))
      .length;

  final monthStart = DateTime(year, month);
  final wins = inMonth.where((m) => m.outcome == 1).length;
  final losses = inMonth.where((m) => m.outcome == -1).length;
  final ties = inMonth.where((m) => m.outcome == 0).length;
  final minutes = inMonth.fold<int>(0, (a, m) => a + m.durationMinutes);

  // Opponents (regular matches only).
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final m in inMonth) {
    final u = m.opponentUid;
    if (u == null) continue;
    counts.update(u, (v) => v + 1, ifAbsent: () => 1);
    if ((m.opponentName ?? '').isNotEmpty) names[u] = m.opponentName!;
  }
  final playedBefore = <String>{
    for (final m in all)
      if (m.opponentUid != null &&
          m.date != null &&
          m.date!.isBefore(monthStart))
        m.opponentUid!,
  };
  final newOpp = counts.keys.where((u) => !playedBefore.contains(u)).length;
  String? topName;
  int topCount = 0;
  counts.forEach((u, c) {
    if (c > topCount) {
      topCount = c;
      topName = names[u];
    }
  });

  // Highlight: bagel > win streak (>=3) > tiebreak win > biggest win.
  RecapHighlight highlight = RecapHighlight.none;
  int? streak;
  String? score;
  if (inMonth.any((m) => m.wonBagel)) {
    highlight = RecapHighlight.bagel;
  } else {
    int best = 0, run = 0;
    for (final m in inMonth) {
      if (m.outcome == 1) {
        run++;
        if (run > best) best = run;
      } else {
        run = 0;
      }
    }
    if (best >= 3) {
      highlight = RecapHighlight.winStreak;
      streak = best;
    } else if (inMonth.any((m) => m.wonTiebreak)) {
      highlight = RecapHighlight.tiebreak;
    } else {
      RecapMatch? bestWin;
      for (final m in inMonth) {
        if (m.outcome == 1 &&
            m.scoreText.isNotEmpty &&
            (bestWin == null || m.gameDiff > bestWin.gameDiff)) {
          bestWin = m;
        }
      }
      if (bestWin != null) {
        highlight = RecapHighlight.bigWin;
        score = bestWin.scoreText;
      }
    }
  }

  // Favourite court (case/whitespace-insensitive).
  final courtCounts = <String, int>{};
  final courtNames = <String, String>{};
  for (final m in inMonth) {
    final raw = (m.location ?? '').trim();
    if (raw.isEmpty) continue;
    final k = raw.toLowerCase();
    courtCounts.update(k, (v) => v + 1, ifAbsent: () => 1);
    courtNames.putIfAbsent(k, () => raw);
  }
  String? court;
  int courtCount = 0;
  courtCounts.forEach((k, c) {
    if (c > courtCount) {
      courtCount = c;
      court = courtNames[k];
    }
  });

  // Weekly streak as of the last day of the recap month.
  final endOfMonth = DateTime(year, month + 1, 0, 23, 59);
  final dates = [
    for (final m in all)
      if (m.date != null && !m.date!.isAfter(endOfMonth)) m.date!,
  ];
  final streaks = computeWeeklyStreaks(dates, endOfMonth);

  return MonthlyRecap(
    year: year,
    month: month,
    matches: inMonth.length,
    previousMatches: previousMatches,
    wins: wins,
    losses: losses,
    ties: ties,
    totalMinutes: minutes,
    distinctOpponents: counts.length,
    newOpponents: newOpp,
    topOpponentName: topName,
    topOpponentCount: topCount,
    highlight: highlight,
    highlightStreak: streak,
    highlightScore: score,
    topCourt: court,
    topCourtCount: courtCount,
    weeklyStreakAtEnd: streaks.current,
    hasEverPlayed: all.isNotEmpty,
  );
}
