import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'match_chat_screen.dart';
import 'add_match_result_screen.dart';
import 'package:tennismatch/services/h2h_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/rate_opponent_dialog.dart';
import '../utils/scoring_mode_utils.dart';

class MatchDetailScreen extends StatefulWidget {
  final DocumentSnapshot matchDoc;
  final Map<String, dynamic> opponentData;

  const MatchDetailScreen({
    super.key,
    required this.matchDoc,
    required this.opponentData,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  bool _showSafetyTip = false;

  @override
  void initState() {
    super.initState();
    _checkSafetyTip();
  }

  Future<void> _checkSafetyTip() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'safety_tip_dismissed_${widget.matchDoc.id}';
    final dismissed = prefs.getBool(key) ?? false;
    if (!dismissed && mounted) {
      setState(() => _showSafetyTip = true);
    }
  }

  Future<void> _dismissSafetyTip() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'safety_tip_dismissed_${widget.matchDoc.id}';
    await prefs.setBool(key, true);
    if (mounted) setState(() => _showSafetyTip = false);
  }

  // Forward widget fields for convenience
  DocumentSnapshot get matchDoc => widget.matchDoc;
  Map<String, dynamic> get opponentData => widget.opponentData;

  String translateStatus(String status, AppLocalizations loc) {
    switch (status) {
      case 'pending': return loc.statusPending;
      case 'confirmed': return loc.statusConfirmed;
      case 'completed': return loc.statusCompleted;
      case 'cancelled': return loc.statusCancelled;
      default: return status;
    }
  }

  /// Pick a date and time for the match, constrained to the next 7 days.
  Future<DateTime?> _pickScheduledDateTime(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 7));

    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: maxDate,
    );
    if (date == null) return null;
    if (!context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return null;

    final scheduled = DateTime(
      date.year, date.month, date.day,
      time.hour, time.minute,
    );

    // Must be in the future
    if (scheduled.isBefore(now)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.schedulePastError)),
        );
      }
      return null;
    }

    return scheduled;
  }

  Future<void> _saveScheduledDate(
    BuildContext context,
    AppLocalizations loc,
    DateTime scheduled,
  ) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchDoc.id)
        .update({
      'scheduledDate': Timestamp.fromDate(scheduled),
    });

    if (context.mounted) {
      // Refresh the screen so the scheduled card appears immediately
      final updatedDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchDoc.id)
          .get();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.matchScheduledWithReminders),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        // Replace current screen with fresh data
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(
              matchDoc: updatedDoc,
              opponentData: opponentData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _clearScheduledDate(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchDoc.id)
        .update({'scheduledDate': FieldValue.delete()});

    if (context.mounted) {
      final updatedDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(matchDoc.id)
          .get();

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => MatchDetailScreen(
              matchDoc: updatedDoc,
              opponentData: opponentData,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final data = matchDoc.data() as Map<String, dynamic>? ?? {};

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final players = List<String>.from(data['players'] ?? []);
    final derivedOpponentUid = players.firstWhere(
      (uid) => uid != currentUid,
      orElse: () => '',
    );

    final String otherPlayerUid =
        (opponentData['uid'] as String?)?.isNotEmpty == true
            ? opponentData['uid'] as String
            : derivedOpponentUid;

    final String otherPlayerName =
        opponentData['name'] as String? ?? loc.unknown;
    final String otherPlayerPhotoUrl =
        opponentData['photoUrl'] as String? ?? '';

    // Scheduled date if set
    final Timestamp? scheduledTs = data['scheduledDate'] as Timestamp?;
    final DateTime? scheduledDate = scheduledTs?.toDate();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.link_off),
            onPressed: () async {
              final confirm = await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.unmatchTitle),
                  content: Text(loc.unmatchConfirmation),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(loc.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(loc.unmatch),
                    ),
                  ],
                ),
              );

              if (!context.mounted) return;

              if (confirm == true) {
                await FirebaseFirestore.instance
                    .collection('matches')
                    .doc(matchDoc.id)
                    .update({'status': 'cancelled'});

                await H2HService.recalculateHeadToHead(
                  userA: currentUid,
                  userB: otherPlayerUid,
                );

                if (!context.mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context, 'cancelled');
                }
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Safety tip banner — shown once per match, dismissed
                // permanently via SharedPreferences ──
                if (_showSafetyTip) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.security_outlined,
                            color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            loc.safetyTipMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _dismissSafetyTip,
                          child: Icon(Icons.close,
                              size: 18, color: Colors.amber.shade700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Opponent header ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: otherPlayerPhotoUrl.isNotEmpty
                          ? NetworkImage(otherPlayerPhotoUrl)
                          : null,
                      child: otherPlayerPhotoUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      otherPlayerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                Text(
                  '${loc.statusLabel}: ${translateStatus(data['status'] as String? ?? '', loc)}',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 8),

                if (data['createdAt'] != null)
                  Text(
                    '${loc.createdAtLabel}: ${(data['createdAt'] as Timestamp).toDate()}',
                    style: const TextStyle(color: Colors.grey),
                  ),

                const SizedBox(height: 30),
                const Divider(),

                // ── Open Chat button ──
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('matches')
                      .doc(matchDoc.id)
                      .collection('messages')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int unreadCount = 0;
                    if (snapshot.hasData) {
                      unreadCount = snapshot.data!.docs.where((doc) {
                        final msg = doc.data() as Map<String, dynamic>;
                        if (msg['senderUid'] == currentUid) return false;
                        final readBy = Map<String, dynamic>.from(
                          msg['readBy'] ?? {},
                        );
                        return readBy[currentUid] != true;
                      }).length;
                    }

                    return Stack(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: Text(loc.openChat),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MatchChatScreen(
                                  matchId: matchDoc.id,
                                  otherPlayerUid: otherPlayerUid,
                                  otherPlayerName: otherPlayerName,
                                  otherPlayerPhotoUrl: otherPlayerPhotoUrl,
                                ),
                              ),
                            );
                          },
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 9 ? '9+' : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // ── Scheduled date card ──
                if (data['status'] != 'completed' &&
                    data['status'] != 'cancelled') ...[

                  const SizedBox(height: 20),

                  if (scheduledDate != null) ...[
                    // Scheduled date is set — show it prominently
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event,
                                color: Colors.green.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                loc.scheduledFor,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}'
                            '  ${scheduledDate.hour.toString().padLeft(2, '0')}:'
                            '${scheduledDate.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Static reminder info — always visible so both
                          // players know reminders are coming automatically
                          Row(
                            children: [
                              Icon(Icons.notifications_outlined,
                                  size: 14,
                                  color: Colors.green.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  loc.remindersWillBeSent,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  final newDate =
                                      await _pickScheduledDateTime(
                                          context, loc);
                                  if (newDate != null && context.mounted) {
                                    await _saveScheduledDate(
                                        context, loc, newDate);
                                  }
                                },
                                child: Text(loc.changeSchedule),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () async {
                                  await _clearScheduledDate(context);
                                },
                                child: Text(
                                  loc.cancelSchedule,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // No date scheduled yet — show schedule button
                    OutlinedButton.icon(
                      icon: const Icon(Icons.event),
                      label: Text(loc.scheduleMatch),
                      onPressed: () async {
                        final scheduled =
                            await _pickScheduledDateTime(context, loc);
                        if (scheduled != null && context.mounted) {
                          await _saveScheduledDate(context, loc, scheduled);
                        }
                      },
                    ),
                  ],
                ],

                // ── Add Match Result button ──
                if (data['status'] != 'completed' &&
                    data['status'] != 'cancelled') ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.emoji_events),
                    label: Text(loc.addMatchResult),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddMatchResultScreen(
                            matchId: matchDoc.id,
                            matchData: data,
                          ),
                        ),
                      );
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                  ),
                ],

                // ── Completed match result summary ──
                if (data['status'] == 'completed' &&
                    data['result'] != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    loc.matchResult,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    (data['result']['sets'] as List).length,
                    (index) {
                      final set = data['result']['sets'][index];
                      final entryLabel =
                          data['result']['scoringMode'] == 'tiebreakOnly'
                              ? loc.tiebreakEntryLabel(index + 1)
                              : loc.setLabel(index + 1);
                      return Text('$entryLabel: ${set['p1']} - ${set['p2']}');
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${loc.locationLabel}: ${data['result']['location']}'),
                  Text(
                    '${loc.durationLabel}: ${data['result']['durationMinutes']} min'),
                  const SizedBox(height: 4),
                  Text(
                    '${loc.scoringModeLabel}: '
                    '${scoringModeDisplayLabel(data['result']['scoringMode'] as String?, loc)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],

                // ── Rate opponent — Phase 1, regular matches only ──
                if (data['status'] == 'completed' &&
                    (data['type'] == null || data['type'] == 'regular') &&
                    otherPlayerUid.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  RateOpponentSection(
                    matchId: matchDoc.id,
                    ratedUid: otherPlayerUid,
                    raterUid: currentUid,
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