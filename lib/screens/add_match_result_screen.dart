import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:tennismatch/services/h2h_service.dart';
import '../widgets/set_score_row.dart';
import '../widgets/rate_opponent_dialog.dart';

class AddMatchResultScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> matchData;

  const AddMatchResultScreen({
    super.key,
    required this.matchId,
    required this.matchData,
  });

  @override
  State<AddMatchResultScreen> createState() =>
      _AddMatchResultScreenState();
}

class _AddMatchResultScreenState extends State<AddMatchResultScreen> {

  final List<GlobalKey<SetScoreRowState>> _setKeys = [];

  final durationController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  ScoringMode scoringMode = ScoringMode.official;
  DateTime? selectedMatchDate;
  String? player1Name;
  String? player2Name;
  bool isSaving = false;
  bool allowTie = false;

  @override
  void initState() {
    super.initState();
    _addSet();
    loadPlayerNames();
  }

  void _addSet() {
    if (_setKeys.length >= _maxEntriesForCurrentMode) return;
    setState(() {
      _setKeys.add(GlobalKey<SetScoreRowState>());
    });
  }

  void _removeSet(int index) {
    if (_setKeys.length == 1) return;
    setState(() {
      _setKeys.removeAt(index);
    });
  }

  void _setScoringMode(ScoringMode mode) {
    setState(() {
      scoringMode = mode;
      // Pro-set is always a single deciding set, short-set is always
      // best-of-3 (2 sets + an optional super tie-break decider) — trim
      // down if more entries were added under another mode.
      final maxEntries = mode == ScoringMode.proSet
          ? 1
          : mode == ScoringMode.shortSet
              ? kMaxShortSetEntries
              : kMaxMatchEntries;
      if (_setKeys.length > maxEntries) {
        _setKeys.removeRange(maxEntries, _setKeys.length);
      }
    });
  }

  Widget _scoringModeChip({required String label, required ScoringMode mode}) {
    final isSelected = scoringMode == mode;
    return GestureDetector(
      onTap: isSaving ? null : () => _setScoringMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    durationController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool isValidTennisSet(int p1, int p2) {
    if (p1 < 6 && p2 < 6) return false;
    if ((p1 == 6 && p2 <= 4) || (p2 == 6 && p1 <= 4)) return true;
    if ((p1 == 7 && p2 == 5) || (p2 == 7 && p1 == 5)) return true;
    if ((p1 == 7 && p2 == 6) || (p2 == 7 && p1 == 6)) return true;
    if ((p1 >= 10 || p2 >= 10) && (p1 - p2).abs() >= 2) return true;
    return false;
  }

  bool isValidTiebreak(int tb1, int tb2) {
    final maxScore = tb1 > tb2 ? tb1 : tb2;
    final minScore = tb1 < tb2 ? tb1 : tb2;
    return maxScore >= 7 && (maxScore - minScore) >= 2;
  }

  bool isValidProSet(int p1, int p2) {
    if (p1 < 8 && p2 < 8) return false;
    if ((p1 == 8 && p2 <= 6) || (p2 == 8 && p1 <= 6)) return true;
    if ((p1 == 8 && p2 == 7) || (p2 == 8 && p1 == 7)) return true;
    if ((p1 >= 9 || p2 >= 9) && (p1 - p2).abs() >= 2) return true;
    return false;
  }

  bool isValidProSetTiebreak(int tb1, int tb2) {
    final maxScore = tb1 > tb2 ? tb1 : tb2;
    final minScore = tb1 < tb2 ? tb1 : tb2;
    return maxScore >= 7 && (maxScore - minScore) >= 2;
  }

  /// Short set: single set to 4 games, win by 2, tiebreak at 3-3 (recorded
  /// as a 4-3 set score). The breaker itself follows the same first-to-7,
  /// win-by-2 rule as every other tiebreak in the app (isValidTiebreak).
  bool isValidShortSet(int p1, int p2) {
    if (p1 < 4 && p2 < 4) return false;
    if ((p1 == 4 && p2 <= 2) || (p2 == 4 && p1 <= 2)) return true;
    if ((p1 == 4 && p2 == 3) || (p2 == 4 && p1 == 3)) return true;
    return false;
  }

  /// Super tie-break: the match-deciding breaker played instead of a 3rd
  /// short set when the first two are split 1-1. First to 10, win by 2 —
  /// no upper cap, keeps going past 9-9 until someone is ahead by 2.
  bool isValidSuperTiebreak(int p1, int p2) {
    final maxScore = p1 > p2 ? p1 : p2;
    final minScore = p1 < p2 ? p1 : p2;
    return maxScore >= 10 && (maxScore - minScore) >= 2;
  }

  /// True when [index] is the match-deciding super tie-break under
  /// ScoringMode.shortSet — the 3rd entry, once the first two short sets
  /// (already-entered scores, read live via their GlobalKeys) are split
  /// 1-1. Drives both the live "Super Tie-break" label and its validation.
  bool _isShortSetDecider(int index) {
    if (scoringMode != ScoringMode.shortSet || index != 2) return false;
    if (_setKeys.length < 2) return false;
    final s0 = _setKeys[0].currentState?.currentData;
    final s1 = _setKeys[1].currentState?.currentData;
    if (s0?.p1 == null || s0?.p2 == null || s1?.p1 == null || s1?.p2 == null) {
      return false;
    }
    final p1Wins = (s0!.p1! > s0.p2! ? 1 : 0) + (s1!.p1! > s1.p2! ? 1 : 0);
    final p2Wins = (s0.p1! < s0.p2! ? 1 : 0) + (s1.p1! < s1.p2! ? 1 : 0);
    return p1Wins == 1 && p2Wins == 1;
  }

  /// Max score entries allowed for the current scoring mode: pro-set is
  /// always a single deciding set, short-set is always best-of-3 (2 sets
  /// + an optional super tie-break decider), everything else shares the
  /// generic hard cap.
  int get _maxEntriesForCurrentMode {
    if (scoringMode == ScoringMode.proSet) return 1;
    if (scoringMode == ScoringMode.shortSet) return kMaxShortSetEntries;
    return kMaxMatchEntries;
  }

  Future<void> pickMatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedMatchDate = picked);
  }

  Future<void> saveResult() async {
    if (widget.matchData['status'] == 'completed') {
      showError('Match already completed');
      return;
    }

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;

    List<Map<String, dynamic>> formattedSets = [];
    int p1Wins = 0;
    int p2Wins = 0;

    for (int i = 0; i < _setKeys.length; i++) {
      final data = _setKeys[i].currentState?.currentData;

      if (data == null || data.p1 == null || data.p2 == null) {
        showError(loc.addAtLeastOneSet);
        return;
      }

      final p1 = data.p1!;
      final p2 = data.p2!;

      if (p1 == 0 && p2 == 0) {
        showError(loc.setScoresZeroError);
        return;
      }

      if (scoringMode == ScoringMode.official &&
          !isValidTennisSet(p1, p2)) {
        showError(loc.invalidSetScore);
        return;
      }
      if (scoringMode == ScoringMode.proSet &&
          !isValidProSet(p1, p2)) {
        showError(loc.invalidProSetScore);
        return;
      }
      if (scoringMode == ScoringMode.tiebreakOnly &&
          !isValidTiebreak(p1, p2)) {
        showError(loc.invalidTiebreakScore);
        return;
      }
      // Under shortSet, a 3rd entry after sets split 1-1 is the mandatory
      // super tie-break decider, not another best-of-4 short set.
      final isShortSetDecider = scoringMode == ScoringMode.shortSet &&
          i == 2 &&
          p1Wins == 1 &&
          p2Wins == 1;
      if (scoringMode == ScoringMode.shortSet &&
          !isShortSetDecider &&
          !isValidShortSet(p1, p2)) {
        showError(loc.invalidShortSetScore);
        return;
      }
      if (isShortSetDecider && !isValidSuperTiebreak(p1, p2)) {
        showError(loc.invalidSuperTiebreakScore);
        return;
      }

      if (data.isTiebreak) {
        if (data.tb1 == null || data.tb2 == null) {
          showError(loc.enterTiebreakScore);
          return;
        }
        if (scoringMode == ScoringMode.official &&
            !isValidTiebreak(data.tb1!, data.tb2!)) {
          showError(loc.invalidTiebreakScore);
          return;
        }
        if (scoringMode == ScoringMode.proSet &&
            !isValidProSetTiebreak(data.tb1!, data.tb2!)) {
          showError(loc.invalidTiebreakScore);
          return;
        }
        if (scoringMode == ScoringMode.shortSet &&
            !isValidTiebreak(data.tb1!, data.tb2!)) {
          showError(loc.invalidTiebreakScore);
          return;
        }
        final setWinnerIsP1 = p1 > p2;
        final tbWinnerIsP1 = data.tb1! > data.tb2!;
        if (setWinnerIsP1 != tbWinnerIsP1) {
          showError(loc.tiebreakWinnerMismatch);
          return;
        }
      }

      formattedSets.add(data.toMap());
      if (p1 > p2) p1Wins++;
      if (p2 > p1) p2Wins++;
    }

    if (formattedSets.isEmpty) {
      showError(loc.addAtLeastOneSet);
      return;
    }
    if (p1Wins == p2Wins && !allowTie) {
      showError(loc.mustHaveWinner);
      return;
    }

    final duration = int.tryParse(durationController.text);
    if (duration == null || duration <= 0) {
      showError(loc.enterDuration);
      return;
    }
    if (locationController.text.trim().isEmpty) {
      showError(loc.enterLocation);
      return;
    }
    if (selectedMatchDate == null) {
      showError(loc.selectDateError);
      return;
    }

    final players = widget.matchData['players'] as List;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final opponentUid = players.firstWhere((uid) => uid != currentUid);
    // For ties, winnerUid is null
    final String? winnerUid = (p1Wins == p2Wins)
        ? null
        : (p1Wins > p2Wins ? currentUid : opponentUid);
    final currentUserName = player1Name ?? 'Player 1';
    final opponentName = player2Name ?? 'Player 2';

    final matchRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId);

    final batch = FirebaseFirestore.instance.batch();

    batch.update(matchRef, {
      // Explicit type tag (regular matches never had one before) so the
      // city activity feed's Firestore query/rules can target completed
      // regular matches directly. Every read path elsewhere already
      // treats a missing `type` as 'regular' (`data['type'] ?? 'regular'`),
      // so this is additive and doesn't change any existing behavior.
      'type': 'regular',
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'winnerUid': winnerUid, // null for ties
      'isTie': p1Wins == p2Wins,
      'player1Uid': currentUid,
      'player2Uid': opponentUid,
      'playerNames': {currentUid: currentUserName, opponentUid: opponentName},
      'result': {
        'sets': formattedSets,
        'location': locationController.text.trim(),
        'durationMinutes': duration,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
        'scoringMode': scoringMode.name,
        if (notesController.text.trim().isNotEmpty)
          'notes': notesController.text.trim(),
      },
      'summary': {
        'p1Name': currentUserName,
        'p2Name': opponentName,
        'p1Sets': p1Wins,
        'p2Sets': p2Wins,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
      },
    });

    // NOTE: matchesPlayed/wins/losses/totalDuration for BOTH players are
    // now updated server-side by the onMatchCompleted Cloud Function,
    // which triggers when this match's status becomes 'completed'.
    // This avoids client-side permission issues (a player can't write to
    // their opponent's stats fields directly) and keeps both players'
    // stats symmetric and reliable.

    await batch.commit();

    await H2HService.recalculateHeadToHead(
      userA: currentUid,
      userB: opponentUid,
    );

    if (!mounted) return;

    // ── Rate opponent right away, Uber/InDrive-style — the moment is
    // freshest right when the result is submitted. Still skippable via
    // Cancel; not a forced/blocking step. ──
    await showRateOpponentDialog(
      context,
      loc,
      matchId: widget.matchId,
      ratedUid: opponentUid,
      raterUid: currentUid,
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> loadPlayerNames() async {
    final players = widget.matchData['players'] as List;
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final opponentUid = players.firstWhere((uid) => uid != currentUid);

    final results = await Future.wait([
      FirebaseFirestore.instance.collection('users').doc(currentUid).get(),
      FirebaseFirestore.instance.collection('users').doc(opponentUid).get(),
    ]);

    if (!mounted) return;
    setState(() {
      player1Name = results[0].data()?['name'] as String? ?? 'Player 1';
      player2Name = results[1].data()?['name'] as String? ?? 'Player 2';
    });
  }

  Future<void> handleSave() async {
    if (!mounted) return;
    setState(() => isSaving = true);
    try {
      await saveResult();
    } catch (e) {
      debugPrint('❌ Save result error: $e');
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.failedToSaveResult)),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.addMatchResult)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(loc.sets, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),

            // ── Scoring mode selector ──
            Text(loc.scoringModeLabel,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                      label: loc.officialScoring,
                      mode: ScoringMode.official),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _scoringModeChip(
                      label: loc.proSetScoring,
                      mode: ScoringMode.proSet),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                      label: loc.shortSetScoring,
                      mode: ScoringMode.shortSet),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _scoringModeChip(
                      label: loc.tiebreakOnlyScoring,
                      mode: ScoringMode.tiebreakOnly),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                      label: loc.openScoring,
                      mode: ScoringMode.open),
                ),
                const SizedBox(width: 6),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
            if (scoringMode == ScoringMode.proSet)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  loc.proSetHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (scoringMode == ScoringMode.tiebreakOnly)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  loc.tiebreakOnlyHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (scoringMode == ScoringMode.shortSet)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  loc.shortSetHint,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Center(child: Text(player1Name ?? loc.loading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 10),
                Expanded(child: Center(child: Text(player2Name ?? loc.loading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 8),
            ..._setKeys.asMap().entries.map((entry) {
              final index = entry.key;
              final key = entry.value;
              return SetScoreRow(
                key: key,
                index: index,
                player1Name: player1Name ?? loc.loading,
                player2Name: player2Name ?? loc.loading,
                canRemove: _setKeys.length > 1,
                isSaving: isSaving,
                scoringMode: scoringMode,
                isSuperTiebreak: _isShortSetDecider(index),
                onRemove: () => _removeSet(index),
                onChanged: (_) => setState(() {}),
              );
            }),
            if (scoringMode != ScoringMode.proSet &&
                _setKeys.length < _maxEntriesForCurrentMode)
              TextButton.icon(
                onPressed: isSaving ? null : _addSet,
                icon: const Icon(Icons.add),
                label: Text(loc.addSet),
              ),

            // ── Tie option ──
            Row(
              children: [
                Checkbox(
                  value: allowTie,
                  onChanged: isSaving
                      ? null
                      : (v) => setState(() => allowTie = v ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => allowTie = !allowTie),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.allowTie,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          loc.tieTooltip,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Text(loc.matchDetailsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(selectedMatchDate == null ? loc.selectMatchDate : loc.matchDateLabel('${selectedMatchDate!.day}/${selectedMatchDate!.month}/${selectedMatchDate!.year}')),
              onTap: pickMatchDate,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: loc.durationMinutes, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.timer_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: loc.location, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.location_on_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: loc.matchNotesLabel,
                hintText: loc.matchNotesHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.notes_outlined),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : handleSave,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(loc.saveResult, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}