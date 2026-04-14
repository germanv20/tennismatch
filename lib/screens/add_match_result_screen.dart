import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:tennismatch/services/h2h_service.dart';

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

class _AddMatchResultScreenState
    extends State<AddMatchResultScreen> {

  List<Map<String, TextEditingController>> sets = [];

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
    addSet();
    loadPlayerNames();
  }

  void addSet() {
    sets.add({
      'p1': TextEditingController(),
      'p2': TextEditingController(),
    });
  }

  void removeSet(int index) {
    if (sets.length == 1) return; // prevent removing last set

    // Dispose controllers to avoid memory leaks
    sets[index]['p1']!.dispose();
    sets[index]['p2']!.dispose();

    setState(() {
      sets.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (var set in sets) {
      set['p1']?.dispose();
      set['p2']?.dispose();
    }

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
      // One player must reach at least 6
      if (p1 < 6 && p2 < 6) return false;

      // Normal win (6-x where x <= 4)
      if ((p1 == 6 && p2 <= 4) || (p2 == 6 && p1 <= 4)) {
        return true;
      }

      // 7-5 case
      if ((p1 == 7 && p2 == 5) || (p2 == 7 && p1 == 5)) {
        return true;
      }

      // 7-6 case (tiebreak)
      if ((p1 == 7 && p2 == 6) || (p2 == 7 && p1 == 6)) {
        return true;
      }

      return false;
    }
  
  Future<void> pickMatchDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedMatchDate = picked;
      });
    }
  }


  Future<void> saveResult() async {
    final matchRef = FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId);

    final matchDoc = await matchRef.get();

    if (matchDoc['status'] == 'completed') {
      showError("Match already completed");
      return;
    }

    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;
    List<Map<String, int>> formattedSets = [];

    int p1Wins = 0;
    int p2Wins = 0;

    for (var set in sets) {

      // ✅ NEW: prevent empty fields
      if (set['p1']!.text.isEmpty || set['p2']!.text.isEmpty) {
        showError("Complete all set scores");
        return;
      }

      final int p1 = int.parse(set['p1']!.text);
      final int p2 = int.parse(set['p2']!.text);

      if (p1 == 0 && p2 == 0) {
        showError(loc.setScoresZeroError);
        return;
      }

      if (useOfficialScoring) {
        if (!isValidTennisSet(p1, p2)) {
          showError(loc.invalidSetScore);
          return;
        }
      }

      formattedSets.add({'p1': p1, 'p2': p2});

      if (p1 > p2) p1Wins++;
      if (p2 > p1) p2Wins++;
    }

    if (formattedSets.isEmpty) {
      showError(loc.addAtLeastOneSet); // "Add at least one set."
      return;
    }

    if (p1Wins == p2Wins) {
      showError(loc.mustHaveWinner); // "There must be a winner."
      return;
    }

    final duration = int.tryParse(durationController.text);

    if (duration == null || duration <= 0) {
      showError(loc.enterDuration); // "Enter match duration."
      return;
    }
      

    if (locationController.text.trim().isEmpty) {
      showError(loc.enterLocation); // "Enter match location."
      return;
    }

    if (selectedMatchDate == null) {
      showError(loc.selectDateError); // "Select match date."
      return;
    }


    final players = widget.matchData['players'] as List;

    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final opponentUid = players.firstWhere((uid) => uid != currentUid);

    final winnerUid = p1Wins > p2Wins
        ? currentUid
        : opponentUid;


    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final currentUserName = currentUserDoc['name'];

    final opponentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(opponentUid)
        .get();

    final opponentName = opponentDoc['name'];

    final batch = FirebaseFirestore.instance.batch();

    // ------------------
    // MATCH UPDATE
    // ------------------
    batch.update(matchRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'winnerUid': winnerUid,
      // IMPORTANT:
      // p1 ALWAYS represents the current user perspective
      // NEVER use players[0] directly for UI or results
      'player1Uid': currentUid,
      'player2Uid': opponentUid,
      'playerNames': {
        currentUid: currentUserName,
        opponentUid: opponentName,
      },
      'result': {
        'sets': formattedSets,
        'location': locationController.text.trim(),
        'durationMinutes': duration,
        'matchDate': selectedMatchDate,
      },
      'summary': {
        'p1Name': currentUserName,
        'p2Name': opponentName,
        'p1Sets': p1Wins,
        'p2Sets': p2Wins,
        'matchDate': selectedMatchDate,
      },
    });

    // ------------------
    // CURRENT USER STATS
    // ------------------
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid);

    batch.update(userRef, {
      'matchesPlayed': FieldValue.increment(1),
      'totalDuration': FieldValue.increment(duration),
      'wins': winnerUid == currentUid
          ? FieldValue.increment(1)
          : FieldValue.increment(0),
      'losses': winnerUid == currentUid
          ? FieldValue.increment(0)
          : FieldValue.increment(1),
    });


    // ------------------
    // COMMIT ONCE
    // ------------------
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

    final opponentUid =
        players.firstWhere((uid) => uid != currentUid);

    final currentUserDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .get();

    final opponentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(opponentUid)
        .get();

    if (!mounted) return;

    setState(() {
      // ✅ ALWAYS enforce correct perspective
      player1Name = currentUserDoc['name'];
      player2Name = opponentDoc['name'];
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save result')),
      );
    } finally {
        if (mounted) {
          setState(() => isSaving = false);
        }
      }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.addMatchResult)), // 'Add Match Result'
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SwitchListTile(
              title: Text(loc.useOfficialScoring), // "Use official tennis scoring"
              value: useOfficialScoring,
              onChanged: (value) {
                setState(() {
                  useOfficialScoring = value;
                });
              },
            ),
            Text(
              loc.sets,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;

              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: set['p1'],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: player1Name ?? loc.loading, // "Loading..."
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: TextField(
                      controller: set['p2'],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: player2Name ?? loc.loading, // "Loading..."
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ❌ REMOVE BUTTON
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: (sets.length > 1 && !isSaving)
                        ? () => removeSet(index)
                        : null,
                  ),
                ],
              );
            }),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: isSaving
                  ? null
                  : () {
                      setState(() {
                        addSet();
                      });
                    },
              icon: const Icon(Icons.add),
              label: Text(loc.addSet),
            ),

             const SizedBox(height: 20),

              ListTile(
                title: Text(
                  selectedMatchDate == null
                      ? loc.selectMatchDate
                      : loc.matchDateLabel(
                          "${selectedMatchDate!.day}/${selectedMatchDate!.month}/${selectedMatchDate!.year}",
                        )
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: pickMatchDate,
              ),

            const SizedBox(height: 20),

            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: loc.durationMinutes), // 'Duration (minutes)'
            ),

            const SizedBox(height: 10),

            TextField(
              controller: locationController,
              decoration:
                  InputDecoration(labelText: loc.location), // 'Location'
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: isSaving ? null : handleSave,
              child: isSaving
                  ? const CircularProgressIndicator()
                  : Text(loc.saveResult),
            ),
          ],
        ),
      ),
    );
  }
}
