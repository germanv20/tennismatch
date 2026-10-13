/// Pure achievements/streak computation (no Firebase, no Flutter), fed by
/// [AchievementMatch]es the service normalizes from completed match docs.
/// See CLAUDE.md ("Achievements & streaks").

/// Monthly "play N matches" goal shown next to the weekly streak.
const int monthlyMatchGoal = 2;

/// Minimum star ratings before the reputation badge can unlock.
const int reputationBadgeMinRatings = 5;
const double reputationBadgeMinAverage = 4.5;

/// "Giant killer": beat a regular opponent whose ranking score is at least
/// this many points above yours.
const int giantKillerEloGap = 100;

enum BadgeGroup { playing, social, performance, reputation }

/// One normalized completed match from the viewer's perspective.
class AchievementMatch {
  final DateTime? date;

  /// 1 = win, -1 = loss, 0 = tie.
  final int outcome;

  /// Real opponent account (regular matches only), else null.
  final String? opponentUid;
  final bool isRegular;
  final bool wonBagel; // won at least one set 6-0
  final bool wonTiebreak;

  const AchievementMatch({
    required this.date,
    required this.outcome,
    required this.opponentUid,
    required this.isRegular,
    required this.wonBagel,
    required this.wonTiebreak,
  });
}

class AchievementBadge {
  /// Stable id, also what's persisted as "already seen".
  final String id;
  final BadgeGroup group;
  final int progress;
  final int target;

  /// Used by the UI to pick the right localized title/description.
  final String kind;

  const AchievementBadge({
    required this.id,
    required this.group,
    required this.kind,
    required this.progress,
    required this.target,
  });

  bool get unlocked => progress >= target;
  int get shownProgress => progress > target ? target : progress;
}

class AchievementsData {
  final List<AchievementBadge> badges;
  final int weeklyStreak;
  final int bestWeeklyStreak;
  final bool playedThisWeek;
  final int matchesThisMonth;
  final int matchesPlayed;

  const AchievementsData({
    required this.badges,
    required this.weeklyStreak,
    required this.bestWeeklyStreak,
    required this.playedThisWeek,
    required this.matchesThisMonth,
    required this.matchesPlayed,
  });

  Set<String> get unlockedIds =>
      badges.where((b) => b.unlocked).map((b) => b.id).toSet();
}

/// Monday 00:00 of [d]'s week.
DateTime _weekStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// Consecutive-week streaks. Weeks are Monday-based. The current streak
/// stays alive through a week in which the user hasn't played *yet* (it
/// only breaks once a full week passes with no match).
({int current, int best, bool playedThisWeek}) computeWeeklyStreaks(
  List<DateTime> dates,
  DateTime now,
) {
  final weeks = <DateTime>{for (final d in dates) _weekStart(d)};
  final thisWeek = _weekStart(now);
  final playedThisWeek = weeks.contains(thisWeek);

  // Best: walk sorted weeks, counting runs exactly 7 days apart.
  final sorted = weeks.toList()..sort();
  int best = 0;
  int run = 0;
  DateTime? prev;
  for (final w in sorted) {
    if (prev != null && w.difference(prev).inDays == 7) {
      run++;
    } else {
      run = 1;
    }
    if (run > best) best = run;
    prev = w;
  }

  // Current: start from this week (or last week if not played yet).
  DateTime cursor =
      playedThisWeek ? thisWeek : thisWeek.subtract(const Duration(days: 7));
  int current = 0;
  while (weeks.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return (current: current, best: best, playedThisWeek: playedThisWeek);
}

/// Best-ever run of consecutive wins (ties and losses break it), in date
/// order. Undated matches are ignored.
int bestWinStreak(List<AchievementMatch> matches) {
  final dated = matches.where((m) => m.date != null).toList()
    ..sort((a, b) => a.date!.compareTo(b.date!));
  int best = 0;
  int run = 0;
  for (final m in dated) {
    if (m.outcome == 1) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  return best;
}

AchievementsData buildAchievements({
  required List<AchievementMatch> matches,
  required DateTime now,
  required int ratingsGiven,
  required int reputationRatingCount,
  required double reputationAverage,
  required bool beatHigherRatedOpponent,
}) {
  final dates = [for (final m in matches) if (m.date != null) m.date!];
  final streaks = computeWeeklyStreaks(dates, now);

  final regular = matches.where((m) => m.isRegular && m.opponentUid != null);
  final perOpponent = <String, int>{};
  for (final m in regular) {
    perOpponent.update(m.opponentUid!, (v) => v + 1, ifAbsent: () => 1);
  }
  final distinctOpponents = perOpponent.length;
  final maxVsSame =
      perOpponent.values.fold<int>(0, (a, b) => a > b ? a : b);

  final total = matches.length;
  final wins = matches.where((m) => m.outcome == 1).length;
  final monthCount = dates
      .where((d) => d.year == now.year && d.month == now.month)
      .length;

  AchievementBadge b(String id, BadgeGroup g, String kind, int progress, int target) =>
      AchievementBadge(id: id, group: g, kind: kind, progress: progress, target: target);

  final badges = <AchievementBadge>[
    // Playing
    b('first_match', BadgeGroup.playing, 'first_match', total, 1),
    b('matches_5', BadgeGroup.playing, 'matches', total, 5),
    b('matches_10', BadgeGroup.playing, 'matches', total, 10),
    b('matches_25', BadgeGroup.playing, 'matches', total, 25),
    b('matches_50', BadgeGroup.playing, 'matches', total, 50),
    b('week_streak_3', BadgeGroup.playing, 'week_streak',
        streaks.best, 3),
    // Social
    b('opponents_5', BadgeGroup.social, 'opponents', distinctOpponents, 5),
    b('rivalry_3', BadgeGroup.social, 'rivalry', maxVsSame, 3),
    b('first_rating', BadgeGroup.social, 'first_rating', ratingsGiven, 1),
    // Performance
    b('first_win', BadgeGroup.performance, 'first_win', wins, 1),
    b('win_streak_3', BadgeGroup.performance, 'win_streak',
        bestWinStreak(matches), 3),
    b('bagel', BadgeGroup.performance, 'bagel',
        matches.where((m) => m.wonBagel).length, 1),
    b('tiebreak_win', BadgeGroup.performance, 'tiebreak',
        matches.where((m) => m.wonTiebreak).length, 1),
    b('giant_killer', BadgeGroup.performance, 'giant',
        beatHigherRatedOpponent ? 1 : 0, 1),
    // Reputation
    b(
      'reputation',
      BadgeGroup.reputation,
      'reputation',
      (reputationRatingCount >= reputationBadgeMinRatings &&
              reputationAverage >= reputationBadgeMinAverage)
          ? 1
          : 0,
      1,
    ),
  ];

  return AchievementsData(
    badges: badges,
    weeklyStreak: streaks.current,
    bestWeeklyStreak: streaks.best,
    playedThisWeek: streaks.playedThisWeek,
    matchesThisMonth: monthCount,
    matchesPlayed: total,
  );
}
