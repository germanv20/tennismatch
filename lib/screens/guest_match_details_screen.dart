import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../utils/scoring_mode_utils.dart';

class GuestMatchDetailsScreen extends StatelessWidget {
  final String matchId;
  final String playerName;
  final String opponentName;
  final String opponentPhone;
  final List sets;
  final String location;
  final int duration;
  final DateTime matchDate;
  final String winnerUid;
  final String currentUserUid;
  final String? notes;
  final String? scoringMode;

  const GuestMatchDetailsScreen({
    super.key,
    required this.matchId,
    required this.playerName,
    required this.opponentName,
    required this.opponentPhone,
    required this.sets,
    required this.location,
    required this.duration,
    required this.matchDate,
    required this.winnerUid,
    required this.currentUserUid,
    this.notes,
    this.scoringMode,
  });

  String _formatScore() {
    return sets.map((s) {
      final p1 = s['p1'] as int;
      final p2 = s['p2'] as int;
      // In the WhatsApp message, show loser's tiebreak points
      // e.g. "7-6 (4)" where 4 = loser's tiebreak points
      if (s['tb1'] != null && s['tb2'] != null) {
        final loserTb = p1 > p2 ? s['tb2'] : s['tb1'];
        return '$p1-$p2 ($loserTb)';
      }
      return '$p1-$p2';
    }).join(', ');
  }

  Future<void> _shareViaWhatsApp(
    BuildContext context,
    AppLocalizations loc,
  ) async {
    final message = loc.whatsappMessageTemplate(
      opponentName,
      playerName,
      _formatScore(),
      location,
      '${matchDate.day}/${matchDate.month}/${matchDate.year}',
      'https://tennismatch.app',
    );

    final encodedMessage = Uri.encodeComponent(message);
    // wa.me requires digits only — strip +, spaces, dashes, parens
    final rawPhone = opponentPhone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    final Uri uri = rawPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$rawPhone?text=$encodedMessage')
        : Uri.parse('https://wa.me/?text=$encodedMessage');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.whatsappNotInstalled)),
      );
    }
  }

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
    final bool currentUserWon = winnerUid == currentUserUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.matchDetailsTitle),
        actions: [
          // Reshare via WhatsApp
          if (opponentPhone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: loc.shareViaWhatsApp,
              onPressed: () => _shareViaWhatsApp(context, loc),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Guest badge ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 14,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      loc.guestMatchBadge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Result sentence ──
              Text(
                loc.result,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  children: [
                    TextSpan(
                      text: loc.matchResultSentence(
                        currentUserWon ? playerName : opponentName,
                        currentUserWon ? opponentName : playerName,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Scoreboard card ──
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [

                      // Header: player names
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
                                      playerName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: currentUserWon
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (currentUserWon) ...[
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
                                      opponentName,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: !currentUserWon
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (!currentUserWon) ...[
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

                      // One row per set
                      ...sets.asMap().entries.map((entry) {
                        final index = entry.key;
                        final set = entry.value;
                        final p1 = set['p1'] as int;
                        final p2 = set['p2'] as int;
                        final p1Won = p1 > p2;
                        final hasTb = set['tb1'] != null && set['tb2'] != null;

                        final p1TbText = (hasTb && !p1Won) ? '(${set["tb1"]})' : '';
                        final p2TbText = (hasTb && p1Won) ? '(${set["tb2"]})' : '';

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
                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
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
                                        fontWeight: p1Won ? FontWeight.bold : FontWeight.normal,
                                        color: p1Won ? Colors.black : Colors.grey[500],
                                      ),
                                    ),
                                    if (p1TbText.isNotEmpty) ...[
                                      const SizedBox(width: 3),
                                      Text(p1TbText,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
                                        fontWeight: !p1Won ? FontWeight.bold : FontWeight.normal,
                                        color: !p1Won ? Colors.black : Colors.grey[500],
                                      ),
                                    ),
                                    if (p2TbText.isNotEmpty) ...[
                                      const SizedBox(width: 3),
                                      Text(p2TbText,
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
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
              Text(
                '${loc.locationLabel}: $location',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '${loc.durationLabel}: $duration ${loc.minutesShort}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                '${loc.dateLabel}: ${matchDate.day}/${matchDate.month}/${matchDate.year}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
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

              if (opponentPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '${loc.opponentLabel}: $opponentName ($opponentPhone)',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Share button ──
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.send),
                  label: Text(loc.shareViaWhatsApp),
                  onPressed: () => _shareViaWhatsApp(context, loc),
                ),
              ),

              const SizedBox(height: 12),

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