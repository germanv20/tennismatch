import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/name_utils.dart';

/// Horizontal "Recent opponents" shortcut row shown at the top of Available
/// Players: the last [maxItems] distinct players the signed-in user has
/// completed a match against, most recent first. Chosen over a
/// level/ranking-closeness "suggestions" list because the ranking doesn't
/// have enough players yet to be meaningful (see CLAUDE.md).
///
/// Renders nothing until loaded, or when there are no past opponents (a
/// brand-new user). Opponents are resolved against [allUsers] (the full
/// `users` collection Available Players already streams), so no extra
/// profile reads; deleted accounts simply don't resolve and are skipped.
/// Pending/scheduled opponents ([blockedUserIds]) are greyed out and
/// non-tappable, mirroring the player cards below; opponents who sent the
/// viewer a request ([incomingRequestUids]) get a blue ring instead.
class RecentOpponentsRow extends StatefulWidget {
  final List<QueryDocumentSnapshot> allUsers;
  final Set<String> blockedUserIds;
  final Set<String> incomingRequestUids;

  /// Called when a non-blocked chip is tapped.
  final void Function(
    QueryDocumentSnapshot doc,
    Map<String, dynamic> data,
    bool hasIncomingRequest,
  ) onTap;

  final int maxItems;

  const RecentOpponentsRow({
    super.key,
    required this.allUsers,
    required this.blockedUserIds,
    required this.incomingRequestUids,
    required this.onTap,
    this.maxItems = 5,
  });

  @override
  State<RecentOpponentsRow> createState() => _RecentOpponentsRowState();
}

class _RecentOpponentsRowState extends State<RecentOpponentsRow> {
  late final Future<List<String>> _future = _loadRecentOpponentUids();

  /// Distinct opponent UIDs from the viewer's completed matches, newest
  /// first. Date fallback chain mirrors match_history_screen.dart
  /// (`completedAt`, then summary/result `matchDate`); matches with no
  /// resolvable date sort last rather than being dropped.
  Future<List<String>> _loadRecentOpponentUids() async {
    final me = FirebaseAuth.instance.currentUser!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('matches')
        .where('players', arrayContains: me)
        .where('status', isEqualTo: 'completed')
        .get();

    DateTime dateOf(Map<String, dynamic> data) {
      final raw = data['completedAt'] ??
          (data['summary'] as Map?)?['matchDate'] ??
          (data['result'] as Map?)?['matchDate'];
      if (raw is Timestamp) return raw.toDate();
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    final entries = <MapEntry<String, DateTime>>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final players = List<String>.from(data['players'] ?? const []);
      final when = dateOf(data);
      for (final uid in players) {
        if (uid != me && uid != 'guest' && uid.isNotEmpty) {
          entries.add(MapEntry(uid, when));
        }
      }
    }
    entries.sort((a, b) => b.value.compareTo(a.value));

    final seen = <String>{};
    final result = <String>[];
    for (final e in entries) {
      if (seen.add(e.key)) result.add(e.key);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return FutureBuilder<List<String>>(
      future: _future,
      builder: (context, snapshot) {
        final uids = snapshot.data;
        if (uids == null || uids.isEmpty) return const SizedBox.shrink();

        final usersById = {for (final d in widget.allUsers) d.id: d};
        final opponents = <QueryDocumentSnapshot>[];
        for (final uid in uids) {
          final doc = usersById[uid];
          if (doc != null) opponents.add(doc);
          if (opponents.length >= widget.maxItems) break;
        }
        if (opponents.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.history,
                        size: 16, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      loc.recentOpponents,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: opponents.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) =>
                      _buildChip(context, loc, opponents[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(
    BuildContext context,
    AppLocalizations loc,
    QueryDocumentSnapshot doc,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final uid = doc.id;
    final hasIncoming = widget.incomingRequestUids.contains(uid);
    final blocked = widget.blockedUserIds.contains(uid) && !hasIncoming;

    final lastActive = data['lastActive'] as Timestamp?;
    final isOnline = lastActive != null &&
        DateTime.now().difference(lastActive.toDate()) <
            const Duration(minutes: 2);

    final formatted = formatNameDisplay((data['name'] as String?) ?? '');
    final firstName =
        formatted.isEmpty ? loc.unknown : formatted.split(' ').first;
    final photoUrl = (data['photoUrl'] as String?) ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: blocked ? null : () => widget.onTap(doc, data, hasIncoming),
      child: Opacity(
        opacity: blocked ? 0.45 : 1,
        child: SizedBox(
          width: 68,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: hasIncoming
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.blue, width: 2),
                          )
                        : null,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                firstName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
