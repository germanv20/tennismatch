import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:tennismatch/services/h2h_service.dart';
import '../widgets/set_score_row.dart';

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
  bool useOfficialScoring = true;
  DateTime? selectedMatchDate;
  String? player1Name;
  String? player2Name;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _addSet();
    loadPlayerNames();
  }

  void _addSet() {
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

  @override
  void dispose() {
    durationController.dispose();
    locationController.dispose();
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

      if (useOfficialScoring && !isValidTennisSet(p1, p2)) {
        showError(loc.invalidSetScore);
        return;
      }

      if (data.isTiebreak) {
        if (data.tb1 == null || data.tb2 == null) {
          showError(loc.enterTiebreakScore);
          return;
        }
        if (useOfficialScoring && !isValidTiebreak(data.tb1!, data.tb2!)) {
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
    if (p1Wins == p2Wins) {
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
    final winnerUid = p1Wins > p2Wins ? currentUid : opponentUid;
    final currentUserName = player1Name ?? 'Player 1';
    final opponentName = player2Name ?? 'Player 2';

    final matchRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId);

    final batch = FirebaseFirestore.instance.batch();

    batch.update(matchRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'winnerUid': winnerUid,
      'player1Uid': currentUid,
      'player2Uid': opponentUid,
      'playerNames': {currentUid: currentUserName, opponentUid: opponentName},
      'result': {
        'sets': formattedSets,
        'location': locationController.text.trim(),
        'durationMinutes': duration,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
      },
      'summary': {
        'p1Name': currentUserName,
        'p2Name': opponentName,
        'p1Sets': p1Wins,
        'p2Sets': p2Wins,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
      },
    });

    final userRef = FirebaseFirestore.instance.collection('users').doc(currentUid);
    if (winnerUid == currentUid) {
      batch.update(userRef, {
        'matchesPlayed': FieldValue.increment(1),
        'totalDuration': FieldValue.increment(duration),
        'wins': FieldValue.increment(1),
      });
    } else {
      batch.update(userRef, {
        'matchesPlayed': FieldValue.increment(1),
        'totalDuration': FieldValue.increment(duration),
        'losses': FieldValue.increment(1),
      });
    }

    await batch.commit();

    await H2HService.recalculateHeadToHead(
      userA: currentUid,
      userB: opponentUid,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(loc.useOfficialScoring, style: const TextStyle(fontSize: 13))),
                Switch(value: useOfficialScoring, onChanged: (v) => setState(() => useOfficialScoring = v)),
              ],
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
                onRemove: () => _removeSet(index),
                onChanged: (_) {},
              );
            }),
            TextButton.icon(
              onPressed: isSaving ? null : _addSet,
              icon: const Icon(Icons.add),
              label: Text(loc.addSet),
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