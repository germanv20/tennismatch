import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/scoring_mode_utils.dart';

class DoublesMatchDetailsScreen extends StatelessWidget {
  final String matchId;
  final String team1Player1;
  final String team1Player2;
  final String team2Player1;
  final String team2Player2;
  final int winnerTeam;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final String? notes;
  final String? scoringMode;

  const DoublesMatchDetailsScreen({
    super.key,
    required this.matchId,
    required this.team1Player1,
    required this.team1Player2,
    required this.team2Player1,
    required this.team2Player2,
    required this.winnerTeam,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
    this.notes,
    this.scoringMode,
  });

  Future<void> _deleteMatch(BuildContext context, AppLocalizations loc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.deleteMatchQuestion),
        content: Text(loc.deleteGuestMatchConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.confirm,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .delete();

    if (!context.mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool team1Won = winnerTeam == 1;

    final team1Label = '$team1Player1 / $team1Player2';
    final team2Label = '$team2Player1 / $team2Player2';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.doublesResult),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── GUEST badge ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.group_outlined, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      loc.doubles.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Result sentence ──
              Text(
                loc.result,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  children: [
                    TextSpan(
                      text: loc.matchResultSentenceDoubles(
                        team1Won ? team1Label : team2Label,
                        team1Won ? team2Label : team1Label,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Scoreboard ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      // Header
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            const SizedBox(width: 56),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      team1Label,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: team1Won
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (team1Won) ...[
                                    const SizedBox(width: 4),
                                    const Text('🏆', style: TextStyle(fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      team2Label,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: !team1Won
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (!team1Won) ...[
                                    const SizedBox(width: 4),
                                    const Text('🏆', style: TextStyle(fontSize: 11)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 16),

                      // Set rows
                      ...sets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        final p1 = set['p1'] as int;
                        final p2 = set['p2'] as int;
                        final p1Won = p1 > p2;
                        final hasTb = set['tb1'] != null && set['tb2'] != null;

                        final p1TbText = (hasTb && !p1Won) ? '(${set['tb1']})' : '';
                        final p2TbText = (hasTb && p1Won) ? '(${set['tb2']})' : '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 56,
                                child: Text(
                                  scoringMode == 'tiebreakOnly'
                                      ? loc.tiebreakEntryLabel(index + 1)
                                      : loc.setLabel(index + 1),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      p1.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: p1Won
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: p1Won
                                            ? Colors.black
                                            : Colors.grey[500],
                                      ),
                                    ),
                                    if (p1TbText.isNotEmpty) ...[
                                      const SizedBox(width: 3),
                                      Text(p1TbText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        )),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      p2.toString(),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: !p1Won
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: !p1Won
                                            ? Colors.black
                                            : Colors.grey[500],
                                      ),
                                    ),
                                    if (p2TbText.isNotEmpty) ...[
                                      const SizedBox(width: 3),
                                      Text(p2TbText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        )),
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

              const SizedBox(height: 16),

              // ── Match info ──
              Text('${loc.locationLabel}: $location',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('${loc.durationLabel}: $duration ${loc.minutesShort}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('${loc.dateLabel}: ${matchDate.day}/${matchDate.month}/${matchDate.year}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(
                '${loc.scoringModeLabel}: ${scoringModeDisplayLabel(scoringMode, loc)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),

              if (notes != null && notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        notes!,
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

              const SizedBox(height: 32),

              // ── Delete button ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: Text(loc.deleteMatch),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: () => _deleteMatch(context, loc),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}