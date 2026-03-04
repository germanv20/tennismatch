import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    addSet();
  }

  void addSet() {
    sets.add({
      'p1': TextEditingController(),
      'p2': TextEditingController(),
    });
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> saveResult() async {
    List<Map<String, int>> formattedSets = [];

    int p1Wins = 0;
    int p2Wins = 0;

    for (var set in sets) {
      final int p1 = int.tryParse(set['p1']!.text) ?? 0;
      final int p2 = int.tryParse(set['p2']!.text) ?? 0;

      if (p1 == 0 && p2 == 0) {
        showError("Set scores cannot both be zero.");
        return;
      }


      formattedSets.add({'p1': p1, 'p2': p2});

      if (p1 > p2) p1Wins++;
      if (p2 > p1) p2Wins++;
    }

    if (formattedSets.isEmpty) {
      showError("Add at least one set.");
      return;
    }

    if (p1Wins == p2Wins) {
      showError("There must be a winner.");
      return;
    }

    if (durationController.text.isEmpty) {
      showError("Enter match duration.");
      return;
    }

    if (locationController.text.trim().isEmpty) {
      showError("Enter match location.");
      return;
    }

    final winnerUid = p1Wins > p2Wins
        ? widget.matchData['player1Uid']
        : widget.matchData['player2Uid'];

    await FirebaseFirestore.instance
        .collection('matches')
        .doc(widget.matchId)
        .update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'result': {
        'winnerUid': winnerUid,
        'sets': formattedSets,
        'durationMinutes':
            int.tryParse(durationController.text) ?? 0,
        'location': locationController.text,
        'matchDate': FieldValue.serverTimestamp(),
      }
    });

    if (!mounted) return;

    Navigator.pop(context);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Match completed 🎾')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Match Result')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Sets',
              style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            ...sets.map((set) => Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: set['p1'],
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'P1'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: set['p2'],
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'P2'),
                      ),
                    ),
                  ],
                )),

            const SizedBox(height: 10),

            TextButton(
              onPressed: () {
                setState(() {
                  addSet();
                });
              },
              child: const Text('+ Add Set'),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Duration (minutes)'),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: locationController,
              decoration:
                  const InputDecoration(labelText: 'Location'),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveResult,
              child: const Text('Save Result'),
            ),
          ],
        ),
      ),
    );
  }
}
