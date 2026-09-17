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
  // Parent-owned mirror of each row's latest SetScoreData, kept in sync via
  // each SetScoreRow's onChanged callback (fires on every keystroke).
  // Validation/save reads from THIS list rather than reaching back into
  // _setKeys[i].currentState?.currentData at save time — a real-world bug
  // report (scores for 2 of 3 sets disappearing right when Save was tapped)
  // traced to that read pattern depending on the child widgets' live state
  // still being exactly correct at that one instant. Always kept the same
  // length as _setKeys (see _addSet/_removeSet/_setScoringMode and the
  // officialSuperTiebreakEnabled checkbox below).
  final List<SetScoreData?> _liveSetData = [];

  final durationController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  ScoringMode scoringMode = ScoringMode.official;
  DateTime? selectedMatchDate;
  String? player1Name;
  String? player2Name;
  bool isSaving = false;
  bool allowTie = false;
  // Optional, Official-mode-only: decide the match with a super tie-break
  // instead of a 3rd set once the first two sets split 1-1. Mirrors
  // ScoringMode.shortSet's mandatory decider rule, but opt-in here since
  // most Official matches still want a real 3rd set.
  bool officialSuperTiebreakEnabled = false;

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
      _liveSetData.add(null);
    });
  }

  void _removeSet(int index) {
    if (_setKeys.length == 1) return;
    setState(() {
      _setKeys.removeAt(index);
      _liveSetData.removeAt(index);
    });
  }

  void _setScoringMode(ScoringMode mode) {
    setState(() {
      scoringMode = mode;
      final maxEntries = _maxEntriesForCurrentMode;
      if (_setKeys.length > maxEntries) {
        _setKeys.removeRange(maxEntries, _setKeys.length);
        _liveSetData.removeRange(maxEntries, _liveSetData.length);
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
    if (_liveSetData.length < 2) return false;
    final s0 = _liveSetData[0];
    final s1 = _liveSetData[1];
    if (s0?.p1 == null || s0?.p2 == null || s1?.p1 == null || s1?.p2 == null) {
      return false;
    }
    final p1Wins = (s0!.p1! > s0.p2! ? 1 : 0) + (s1!.p1! > s1.p2! ? 1 : 0);
    final p2Wins = (s0.p1! < s0.p2! ? 1 : 0) + (s1.p1! < s1.p2! ? 1 : 0);
    return p1Wins == 1 && p2Wins == 1;
  }

  /// Same idea as _isShortSetDecider, but for ScoringMode.official's
  /// optional super tie-break (officialSuperTiebreakEnabled) — only fires
  /// once that option is checked, unlike shortSet where it's mandatory.
  bool _isOfficialSuperTiebreakDecider(int index) {
    if (scoringMode != ScoringMode.official ||
        !officialSuperTiebreakEnabled ||
        index != 2) {
      return false;
    }
    if (_liveSetData.length < 2) return false;
    final s0 = _liveSetData[0];
    final s1 = _liveSetData[1];
    if (s0?.p1 == null || s0?.p2 == null || s1?.p1 == null || s1?.p2 == null) {
      return false;
    }
    final p1Wins = (s0!.p1! > s0.p2! ? 1 : 0) + (s1!.p1! > s1.p2! ? 1 : 0);
    final p2Wins = (s0.p1! < s0.p2! ? 1 : 0) + (s1.p1! < s1.p2! ? 1 : 0);
    return p1Wins == 1 && p2Wins == 1;
  }

  /// True when [index] is the match-deciding super tie-break under either
  /// rule — shortSet's mandatory one or official's opt-in one. Single call
  /// site used everywhere the "is this entry the decider" question matters.
  bool _isMatchDecider(int index) =>
      _isShortSetDecider(index) || _isOfficialSuperTiebreakDecider(index);

  /// Max score entries allowed for the current scoring mode: pro-set is
  /// always a single deciding set, short-set is always best-of-3 (2 sets
  /// + an optional super tie-break decider), everything else shares the
  /// generic hard cap.
  int get _maxEntriesForCurrentMode {
    if (scoringMode == ScoringMode.proSet) return 1;
    if (scoringMode == ScoringMode.shortSet) return kMaxShortSetEntries;
    if (scoringMode == ScoringMode.official && officialSuperTiebreakEnabled) {
      return kMaxShortSetEntries;
    }
    if (scoringMode == ScoringMode.official) return kMaxOfficialEntries;
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
    // True only once an Official-mode super tie-break decider entry is
    // actually validated below — the toggle alone (officialSuperTiebreakEnabled)
    // doesn't guarantee the match ever reached a 1-1 split that needed one.
    bool officialDeciderReached = false;

    for (int i = 0; i < _liveSetData.length; i++) {
      final data = _liveSetData[i];

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

      // Under Official mode with the optional super tie-break toggle on, a
      // 3rd entry after sets split 1-1 is the decider, not another full set.
      final isOfficialDecider = scoringMode == ScoringMode.official &&
          officialSuperTiebreakEnabled &&
          i == 2 &&
          p1Wins == 1 &&
          p2Wins == 1;
      if (scoringMode == ScoringMode.official &&
          !isOfficialDecider &&
          !isValidTennisSet(p1, p2)) {
        showError(loc.invalidSetScore);
        return;
      }
      if (isOfficialDecider && !isValidSuperTiebreak(p1, p2)) {
        showError(loc.invalidSuperTiebreakScore);
        return;
      }
      if (isOfficialDecider) officialDeciderReached = true;
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
        if (officialDeciderReached) 'superTiebreakDecider': true,
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
    // Dismiss the keyboard/focus before reading anything, so any pending
    // IME commit happens deterministically here rather than interleaving
    // with the validation read right below.
    FocusScope.of(context).unfocus();
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
          // A large cacheExtent keeps every child (including the
          // SetScoreRow widgets and their TextEditingControllers) mounted
          // regardless of scroll position. Without this, ListView's normal
          // Sliver-based virtualization disposes elements that scroll far
          // enough outside the viewport (default cache extent ~250px) —
          // and the keyboard opening (which shrinks/reflows the viewport)
          // plus scrolling down to the Save button and back up was enough
          // to push earlier set rows past that threshold, permanently
          // destroying their State (and the score the user had just
          // typed) well before Save was ever tapped. This form is small
          // and bounded (a handful of fields + up to kMaxMatchEntries sets),
          // so there's no real virtualization benefit being given up here.
          cacheExtent: 5000,
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
                isSuperTiebreak: _isMatchDecider(index),
                initialData: _liveSetData[index],
                onRemove: () => _removeSet(index),
                onChanged: (data) => setState(() => _liveSetData[index] = data),
              );
            }),
            if (scoringMode != ScoringMode.proSet &&
                _setKeys.length < _maxEntriesForCurrentMode)
              TextButton.icon(
                onPressed: isSaving ? null : _addSet,
                icon: const Icon(Icons.add),
                label: Text(loc.addSet),
              ),

            if (scoringMode == ScoringMode.official) ...[
              const SizedBox(height: 8),
              // ── Official-mode super tie-break option ──
              Row(
                children: [
                  Checkbox(
                    value: officialSuperTiebreakEnabled,
                    onChanged: isSaving
                        ? null
                        : (v) => setState(() {
                              officialSuperTiebreakEnabled = v ?? false;
                              if (officialSuperTiebreakEnabled &&
                                  _setKeys.length > kMaxShortSetEntries) {
                                _setKeys.removeRange(
                                    kMaxShortSetEntries, _setKeys.length);
                                _liveSetData.removeRange(
                                    kMaxShortSetEntries, _liveSetData.length);
                              }
                            }),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: isSaving
                          ? null
                          : () => setState(() {
                                officialSuperTiebreakEnabled =
                                    !officialSuperTiebreakEnabled;
                                if (officialSuperTiebreakEnabled &&
                                    _setKeys.length > kMaxShortSetEntries) {
                                  _setKeys.removeRange(
                                      kMaxShortSetEntries, _setKeys.length);
                                  _liveSetData.removeRange(
                                      kMaxShortSetEntries, _liveSetData.length);
                                }
                              }),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.officialSuperTiebreakOption,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            loc.officialSuperTiebreakOptionHint,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

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