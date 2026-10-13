import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

import '../screens/achievements_screen.dart';
import '../services/achievements_service.dart';
import '../utils/achievement_labels.dart';
import '../utils/achievements_utils.dart';

/// Thin Home strip: weekly play streak + monthly goal, tapping through to
/// [AchievementsScreen]. It also owns the "achievement unlocked" celebration:
/// it watches the user's own doc, and when `matchesPlayed` changes (a match
/// was just completed, which the stats Cloud Function reflects there) it
/// recomputes achievements and, if something new unlocked, shows a bottom
/// sheet — waiting until Home is the visible route so it never lands on top
/// of the rating dialog or a result screen. Hidden until first loaded.
class AchievementsStrip extends StatefulWidget {
  const AchievementsStrip({super.key});

  @override
  State<AchievementsStrip> createState() => _AchievementsStripState();
}

class _AchievementsStripState extends State<AchievementsStrip> {
  AchievementsData? _data;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _retry;
  int? _lastMatchesPlayed;
  List<String> _pending = const [];

  @override
  void initState() {
    super.initState();
    _refresh();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _sub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((snap) {
        final mp = (snap.data()?['matchesPlayed'] as num?)?.toInt();
        if (mp == null) return;
        final changed = _lastMatchesPlayed != null && _lastMatchesPlayed != mp;
        _lastMatchesPlayed = mp;
        if (changed) _refresh();
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final data = await AchievementsService.load();
      final unseen = await AchievementsService.takeUnseen(data);
      if (!mounted) return;
      setState(() => _data = data);
      if (unseen.isNotEmpty) {
        _pending = {..._pending, ...unseen}.toList();
        _tryCelebrate(0);
      }
    } catch (_) {
      // Non-critical: the strip just stays as it was.
    }
  }

  void _tryCelebrate(int attempt) {
    if (!mounted || _pending.isEmpty || _data == null) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) {
      if (attempt >= 40) return; // ~80s, then give up until next change
      _retry?.cancel();
      _retry = Timer(const Duration(seconds: 2), () => _tryCelebrate(attempt + 1));
      return;
    }
    final ids = _pending;
    _pending = const [];
    AchievementsService.markSeen(ids);
    final badges = _data!.badges.where((b) => ids.contains(b.id)).toList();
    _showCelebration(badges);
  }

  void _showCelebration(List<AchievementBadge> badges) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.achievementUnlockedTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (final b in badges)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      badgeVisual(b, size: 44, color: Colors.amber.shade700),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(badgeTitle(b, loc),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(badgeDescription(b, loc),
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openAchievements();
                      },
                      child: Text(loc.achievementViewAll),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: Text(loc.achievementNice),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAchievements() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AchievementsScreen()),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context)!;
    final streak = data.weeklyStreak;
    final String main = streak > 0
        ? loc.weekStreakChip(streak)
        : loc.weekStreakStart;
    final done = data.matchesThisMonth > monthlyMatchGoal
        ? monthlyMatchGoal
        : data.matchesThisMonth;
    final atRisk = streak > 0 && !data.playedThisWeek;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _openAchievements,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: streak > 0 ? Colors.orange : Colors.grey, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(main,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      atRisk
                          ? loc.weekStreakKeepAlive
                          : loc.monthGoalProgress(done, monthlyMatchGoal),
                      style: TextStyle(
                          fontSize: 12,
                          color: atRisk
                              ? Colors.orange.shade800
                              : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              if (streak > 0)
                Text(loc.monthGoalProgress(done, monthlyMatchGoal),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
