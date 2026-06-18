import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../widgets/set_score_row.dart';

class LogDoublesMatchScreen extends StatefulWidget {
  const LogDoublesMatchScreen({super.key});

  @override
  State<LogDoublesMatchScreen> createState() => _LogDoublesMatchScreenState();
}

class _LogDoublesMatchScreenState extends State<LogDoublesMatchScreen> {
  // Team 1 (current user's team)
  final partnerNameController = TextEditingController();

  // Team 2 (opponents)
  final opponent1Controller = TextEditingController();
  final opponent2Controller = TextEditingController();

  // Match info
  final durationController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();

  // Sets
  final List<GlobalKey<SetScoreRowState>> _setKeys = [];

  ScoringMode scoringMode = ScoringMode.official;
  DateTime? selectedMatchDate;
  bool isSaving = false;
  bool allowTie = false;

  // Winner selection: 1 = your team, 2 = opponent team
  // Determined automatically from set wins
  String? currentUserName;
  String? currentUserUid;

  @override
  void initState() {
    super.initState();
    _addSet();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    currentUserUid = user.uid;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      currentUserName = doc['name'] ?? user.displayName ?? 'Player';
    });
  }

  void _addSet() {
    setState(() {
      _setKeys.add(GlobalKey<SetScoreRowState>());
    });
  }

  void _removeSet(int index) {
    if (_setKeys.length == 1) return;
    setState(() => _setKeys.removeAt(index));
  }

  void _setScoringMode(ScoringMode mode) {
    setState(() {
      scoringMode = mode;
      if (mode == ScoringMode.proSet && _setKeys.length > 1) {
        _setKeys.removeRange(1, _setKeys.length);
      }
    });
  }

  Widget _scoringModeChip({
    required String label,
    required ScoringMode mode,
  }) {
    final isSelected = scoringMode == mode;
    return GestureDetector(
      onTap: isSaving ? null : () => _setScoringMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
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
    partnerNameController.dispose();
    opponent1Controller.dispose();
    opponent2Controller.dispose();
    durationController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void showError(String message) {
    if (!mounted) return;
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

  Future<void> pickMatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedMatchDate = picked);
  }

  Future<void> _handleSave() async {
    if (isSaving) return;
    setState(() => isSaving = true);
    try {
      await _saveDoublesMatch();
    } catch (e) {
      debugPrint('❌ Save doubles match error: $e');
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showError(loc.failedToSaveDoublesMatch);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _saveDoublesMatch() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;

    // ── Validate team names ──
    final partnerName = partnerNameController.text.trim();
    final opponent1 = opponent1Controller.text.trim();
    final opponent2 = opponent2Controller.text.trim();

    if (partnerName.isEmpty) {
      showError(loc.yourPartner);
      return;
    }
    if (opponent1.isEmpty) {
      showError(loc.opponent1);
      return;
    }
    if (opponent2.isEmpty) {
      showError(loc.opponent2);
      return;
    }

    // ── Validate sets ──
    List<Map<String, dynamic>> formattedSets = [];
    int team1Wins = 0;
    int team2Wins = 0;

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
        final setWinnerIsP1 = p1 > p2;
        final tbWinnerIsP1 = data.tb1! > data.tb2!;
        if (setWinnerIsP1 != tbWinnerIsP1) {
          showError(loc.tiebreakWinnerMismatch);
          return;
        }
      }

      formattedSets.add(data.toMap());
      if (p1 > p2) { team1Wins++; } else { team2Wins++; }
    }

    if (formattedSets.isEmpty) {
      showError(loc.addAtLeastOneSet);
      return;
    }
    if (team1Wins == team2Wins && !allowTie) {
      showError(loc.mustHaveWinner);
      return;
    }

    final duration = int.tryParse(durationController.text);
    if (duration == null || duration <= 0) {
      showError(loc.enterDuration);
      return;
    }
    final location = locationController.text.trim();
    if (location.isEmpty) {
      showError(loc.enterLocation);
      return;
    }
    if (selectedMatchDate == null) {
      showError(loc.selectDateError);
      return;
    }

    final uid = currentUserUid!;
    final myName = currentUserName ?? 'Player';
    final bool isTie = allowTie && team1Wins == team2Wins;
    final int? winnerTeam = isTie ? null
        : (team1Wins > team2Wins ? 1 : 2);

    final matchData = {
      'type': 'doubles_guest',
      'createdBy': uid,
      'players': [uid],
      'status': 'completed',
      'winnerTeam': winnerTeam,
      if (isTie) 'isTie': true,
      'team1': {
        'player1': myName,
        'player2': partnerName,
      },
      'team2': {
        'player1': opponent1,
        'player2': opponent2,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'result': {
        'sets': formattedSets,
        'location': location,
        'durationMinutes': duration,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
        'scoringMode': scoringMode.name,
        if (notesController.text.trim().isNotEmpty)
          'notes': notesController.text.trim(),
      },
    };

    await FirebaseFirestore.instance
        .collection('matches')
        .add(matchData);

    // NOTE: matchesPlayed/wins/losses/totalDuration are now updated
    // server-side by the onMatchCompleted Cloud Function, which triggers
    // when this match document is created with status 'completed'.

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final myName = currentUserName ?? loc.loading;

    // Team label strings for SetScoreRow
    final team1Label = '$myName / ${partnerNameController.text.isEmpty ? loc.yourPartner : partnerNameController.text}';
    final team2Label = opponent1Controller.text.isEmpty && opponent2Controller.text.isEmpty
        ? loc.team2
        : '${opponent1Controller.text} / ${opponent2Controller.text}';

    return Scaffold(
      appBar: AppBar(title: Text(loc.logDoublesMatch)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

            // ── Team 1 (your team) ──
            Text(
              loc.team1,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Current user's name (read-only display)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Text(myName, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'You',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: partnerNameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}), // rebuild team label
              decoration: InputDecoration(
                labelText: loc.yourPartner,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 20),

            // ── Team 2 (opponents) ──
            Text(
              loc.team2,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: opponent1Controller,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.opponent1,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: opponent2Controller,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: loc.opponent2,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 24),

            // ── Sets ──
            Text(
              loc.sets,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // ── Scoring mode selector ──
            Text(
              loc.scoringModeLabel,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                    label: loc.officialScoring,
                    mode: ScoringMode.official,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _scoringModeChip(
                    label: loc.proSetScoring,
                    mode: ScoringMode.proSet,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _scoringModeChip(
                    label: loc.openScoring,
                    mode: ScoringMode.open,
                  ),
                ),
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

            const SizedBox(height: 8),

            // Team name header
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      team1Label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Center(
                    child: Text(
                      team2Label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
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
                player1Name: team1Label,
                player2Name: team2Label,
                canRemove: _setKeys.length > 1,
                isSaving: isSaving,
                scoringMode: scoringMode,
                onRemove: () => _removeSet(index),
                onChanged: (_) {},
              );
            }),

            if (scoringMode != ScoringMode.proSet)
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

            // ── Match Details ──
            Text(
              loc.matchDetailsTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                selectedMatchDate == null
                    ? loc.selectMatchDate
                    : loc.matchDateLabel(
                        '${selectedMatchDate!.day}/${selectedMatchDate!.month}/${selectedMatchDate!.year}',
                      ),
              ),
              onTap: pickMatchDate,
            ),

            const SizedBox(height: 8),

            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: loc.durationMinutes,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.timer_outlined),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: locationController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: loc.location,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
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
                onPressed: isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        loc.saveResult,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}