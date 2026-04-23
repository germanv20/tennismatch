import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

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
  });

  String _formatScore() {
    return sets
        .map((s) => '${s['p1']}-${s['p2']}')
        .join(', ');
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
                      // Header
                      Row(
                        children: [
                          const SizedBox(width: 130),
                          ...sets.asMap().entries.map((e) => Expanded(
                            child: Center(
                              child: Text(
                                loc.setLabel(e.key + 1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Player 1 row (current user)
                      Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    playerName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: currentUserWon
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (currentUserWon) ...[
                                  const SizedBox(width: 4),
                                  const Text('🏆'),
                                ],
                              ],
                            ),
                          ),
                          ...sets.map((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p1 > p2;
                            return Expanded(
                              child: Center(
                                child: Text(
                                  p1.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: won
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: won
                                        ? Colors.black
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Player 2 row (guest)
                      Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    opponentName,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: !currentUserWon
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (!currentUserWon) ...[
                                  const SizedBox(width: 4),
                                  const Text('🏆'),
                                ],
                              ],
                            ),
                          ),
                          ...sets.map((set) {
                            final p1 = set['p1'] ?? 0;
                            final p2 = set['p2'] ?? 0;
                            final won = p2 > p1;
                            return Expanded(
                              child: Center(
                                child: Text(
                                  p2.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: won
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: won
                                        ? Colors.black
                                        : Colors.grey[500],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
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