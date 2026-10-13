import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import '../services/achievements_service.dart';
import '../utils/achievement_labels.dart';
import '../utils/achievements_utils.dart';
import 'monthly_recap_screen.dart';

/// Badge grid (locked ones greyed out with progress) plus the weekly-streak /
/// monthly-goal header. Data is computed on the device — see
/// [AchievementsService].
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Future<AchievementsData> _future = _load();

  Future<AchievementsData> _load() async {
    final data = await AchievementsService.load();
    // Opening this screen counts as having seen everything unlocked.
    await AchievementsService.markSeen(data.unlockedIds);
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.achievementsTitle)),
      body: FutureBuilder<AchievementsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return Center(child: Text(loc.failedToLoadStats));
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _Header(data: data),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(loc.recapSeeLastMonth),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final now = DateTime.now();
                    final prev = DateTime(now.year, now.month - 1);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MonthlyRecapScreen(
                            year: prev.year, month: prev.month),
                      ),
                    );
                  },
                ),
                for (final g in BadgeGroup.values)
                  ..._group(context, loc, g, data),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _group(BuildContext context, AppLocalizations loc,
      BadgeGroup g, AchievementsData data) {
    final items = data.badges.where((b) => b.group == g).toList();
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(
          badgeGroupTitle(g, loc),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.82,
        children: [for (final b in items) _BadgeTile(badge: b)],
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  final AchievementsData data;
  const _Header({required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final unlocked = data.badges.where((b) => b.unlocked).length;
    final streakHint = data.weeklyStreak == 0
        ? loc.weekStreakStart
        : (data.playedThisWeek ? null : loc.weekStreakKeepAlive);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: Colors.orange, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.weekStreakChip(data.weeklyStreak),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(loc.bestWeekStreak(data.bestWeeklyStreak),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            if (streakHint != null) ...[
              const SizedBox(height: 4),
              Text(streakHint,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 14),
            Text(
              loc.monthGoalProgress(
                  data.matchesThisMonth > monthlyMatchGoal
                      ? monthlyMatchGoal
                      : data.matchesThisMonth,
                  monthlyMatchGoal),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value:
                    (data.matchesThisMonth / monthlyMatchGoal).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(height: 14),
            Text(loc.achievementsUnlockedCount(unlocked, data.badges.length),
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AchievementBadge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final unlocked = badge.unlocked;
    final color = unlocked ? Colors.amber.shade700 : Colors.grey;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showDetail(context, loc),
      child: Opacity(
        opacity: unlocked ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: unlocked ? Colors.amber.shade600 : Colors.grey.shade400),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(badgeIcon(badge), size: 34, color: color),
              const SizedBox(height: 6),
              Text(
                badgeTitle(badge, loc),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (!unlocked && badge.target > 1) ...[
                const SizedBox(height: 4),
                Text('${badge.shownProgress}/${badge.target}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, AppLocalizations loc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(badgeIcon(badge),
                  size: 56,
                  color: badge.unlocked ? Colors.amber.shade700 : Colors.grey),
              const SizedBox(height: 12),
              Text(badgeTitle(badge, loc),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(badgeDescription(badge, loc), textAlign: TextAlign.center),
              if (!badge.unlocked && badge.target > 1) ...[
                const SizedBox(height: 10),
                Text('${badge.shownProgress}/${badge.target}',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
