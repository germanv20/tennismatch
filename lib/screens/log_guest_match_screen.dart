import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import '../main.dart' show navigatorKey;
import '../widgets/set_score_row.dart';

class LogGuestMatchScreen extends StatefulWidget {
  const LogGuestMatchScreen({super.key});

  @override
  State<LogGuestMatchScreen> createState() => _LogGuestMatchScreenState();
}

class _LogGuestMatchScreenState extends State<LogGuestMatchScreen> {
  // Opponent info
  final opponentNameController = TextEditingController();
  final opponentPhoneController = TextEditingController();

  // Sets
  final List<GlobalKey<SetScoreRowState>> _setKeys = [];

  // Match info
  final durationController = TextEditingController();
  final locationController = TextEditingController();
  bool useOfficialScoring = true;
  DateTime? selectedMatchDate;

  // Player names (loaded from Firestore)
  String? currentUserName;
  String? currentUserUid;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    addSet();
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

  void addSet() {
    setState(() {
      _setKeys.add(GlobalKey<SetScoreRowState>());
    });
  }

  void removeSet(int index) {
    if (_setKeys.length == 1) return;
    setState(() {
      _setKeys.removeAt(index);
    });
  }

  @override
  void dispose() {
    opponentNameController.dispose();
    opponentPhoneController.dispose();
    durationController.dispose();
    locationController.dispose();
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

  Future<void> pickMatchDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => selectedMatchDate = picked);
    }
  }

  /// Builds the WhatsApp share message in the current app locale
  String _buildWhatsAppMessage(
    AppLocalizations loc, {
    required String opponentName,
    required String playerName,
    required String score,
    required String location,
    required String date,
  }) {
    return loc.whatsappMessageTemplate(
      opponentName,
      playerName,
      score,
      location,
      date,
      'https://tennismatch.app', // placeholder — replace with real link
    );
  }

  /// Formats sets into a readable score string e.g. "6-4, 7-5"
  String _formatScore(List<Map<String, dynamic>> formattedSets) {
    return formattedSets
        .map((s) => '${s['p1']}-${s['p2']}')
        .join(', ');
  }

  Future<void> _shareViaWhatsApp({
    required AppLocalizations loc,
    required String opponentName,
    required String opponentPhone,
    required List<Map<String, dynamic>> formattedSets,
    required String location,
    required DateTime matchDate,
  }) async {
    final playerName = currentUserName ?? 'Player';
    final score = _formatScore(formattedSets);
    final date =
        '${matchDate.day}/${matchDate.month}/${matchDate.year}';

    final message = _buildWhatsAppMessage(
      loc,
      opponentName: opponentName,
      playerName: playerName,
      score: score,
      location: location,
      date: date,
    );

    // Capture the not-installed message before any await
    final notInstalledMsg = loc.whatsappNotInstalled;

    final encodedMessage = Uri.encodeComponent(message);

    // wa.me requires digits only — strip +, spaces, dashes, parens
    final String rawPhone =
        opponentPhone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    final Uri whatsappUri = rawPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$rawPhone?text=$encodedMessage')
        : Uri.parse('https://wa.me/?text=$encodedMessage');

    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      // Use root context — this screen may already be popped at this point
      final rootContext = navigatorKey.currentContext;
      if (rootContext == null) return;
      ScaffoldMessenger.of(rootContext).showSnackBar(
        SnackBar(content: Text(notInstalledMsg)),
      );
    }
  }

  Future<void> _handleSave() async {
    if (isSaving) return;
    setState(() => isSaving = true);

    try {
      await _saveGuestMatch();
    } catch (e) {
      debugPrint('❌ Save guest match error: $e');
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showError(loc.failedToSaveGuestMatch);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _saveGuestMatch() async {
    if (!mounted) return;
    final loc = AppLocalizations.of(context)!;

    // ── Validate opponent name ──
    final opponentName = opponentNameController.text.trim();
    if (opponentName.isEmpty) {
      showError(loc.guestOpponentName);
      return;
    }

    // ── Validate sets ──
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

    // ── Validate match info ──
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

    // ── Build match document ──
    final uid = currentUserUid!;
    // Normalise phone to E.164 with + prefix for consistent storage
    // This ensures phoneIndex lookup matches CompleteProfileScreen format
    final rawPhoneInput = opponentPhoneController.text.trim();
    final opponentPhone = rawPhoneInput.isNotEmpty && !rawPhoneInput.startsWith('+')
        ? '+$rawPhoneInput'
        : rawPhoneInput;

    // p1 = current user (always), p2 = guest opponent
    final bool currentUserWon = p1Wins > p2Wins;
    final String winnerUid = currentUserWon ? uid : 'guest';

    final matchData = {
      'type': 'guest',
      'players': [uid],
      'createdBy': uid,
      'player1Uid': uid,
      'player2Uid': 'guest',
      'playerNames': {
        uid: currentUserName ?? 'Player',
        'guest': opponentName,
      },
      'guestOpponent': {
        'name': opponentName,
        'phone': opponentPhone,
        'claimedBy': null,
      },
      'status': 'completed',
      'winnerUid': winnerUid,
      'createdAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'result': {
        'sets': formattedSets,
        'location': location,
        'durationMinutes': duration,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
      },
      'summary': {
        'p1Name': currentUserName ?? 'Player',
        'p2Name': opponentName,
        'p1Sets': p1Wins,
        'p2Sets': p2Wins,
        'matchDate': Timestamp.fromDate(selectedMatchDate!),
      },
    };

    // ── Batch write: match + user stats + phoneIndex ──
    final batch = FirebaseFirestore.instance.batch();

    final matchRef =
        FirebaseFirestore.instance.collection('matches').doc();
    batch.set(matchRef, matchData);

    // Write to phoneIndex so the claim mechanic can find this match
    // phoneIndex/{phone}/matches/{matchId}
    // This is a separate readable collection keyed by phone number
    if (opponentPhone.isNotEmpty) {
      final indexRef = FirebaseFirestore.instance
          .collection('phoneIndex')
          .doc(opponentPhone)
          .collection('matches')
          .doc(matchRef.id);
      batch.set(indexRef, {
        'matchId': matchRef.id,
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

    if (currentUserWon) {
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

    if (!mounted) return;

    // ── Pop first so we return to HomeScreen ──
    // Store what we need before popping (context will be gone after)
    final opponentPhoneCopy = opponentPhone;
    final opponentNameCopy = opponentName;
    final formattedSetsCopy = List<Map<String, int>>.from(formattedSets);
    final locationCopy = location;
    final matchDateCopy = selectedMatchDate!;

    Navigator.pop(context, true);

    // ── Show WhatsApp share dialog on HomeScreen after returning ──
    // Small delay lets the home screen finish its transition first
    await Future.delayed(const Duration(milliseconds: 400));

    await _showShareDialogOnRoot(
      loc: loc,
      opponentName: opponentNameCopy,
      opponentPhone: opponentPhoneCopy,
      formattedSets: formattedSetsCopy,
      location: locationCopy,
      matchDate: matchDateCopy,
    );
  }

  /// Shows the share dialog using the root navigator key so it works
  /// even after this screen has been popped from the stack
  Future<void> _showShareDialogOnRoot({
    required AppLocalizations loc,
    required String opponentName,
    required String opponentPhone,
    required List<Map<String, dynamic>> formattedSets,
    required String location,
    required DateTime matchDate,
  }) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text(loc.shareMatchTitle),
        content: Text(loc.shareMatchSubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(loc.skipSharing),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send),
            label: Text(loc.shareViaWhatsApp),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _shareViaWhatsApp(
                loc: loc,
                opponentName: opponentName,
                opponentPhone: opponentPhone,
                formattedSets: formattedSets,
                location: location,
                matchDate: matchDate,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.logMatch),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

            // ── Section: Opponent Info ──
            Text(
              loc.opponentLabel,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: opponentNameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: loc.guestOpponentName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: opponentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: loc.guestOpponentPhone,
                hintText: loc.phoneNumberHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.phone_outlined),
                helperText: loc.phoneOptionalHint,
              ),
            ),

            const SizedBox(height: 24),

            // ── Section: Score ──
            Text(
              loc.sets,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    loc.useOfficialScoring,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Switch(
                  value: useOfficialScoring,
                  onChanged: (v) => setState(() => useOfficialScoring = v),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Set score rows header
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      currentUserName ?? loc.loading,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Center(
                    child: Text(
                      opponentNameController.text.isEmpty
                          ? loc.guestOpponent
                          : opponentNameController.text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 48), // space for remove button
              ],
            ),

            const SizedBox(height: 8),

            ..._setKeys.asMap().entries.map((entry) {
              final index = entry.key;
              final key = entry.value;
              return SetScoreRow(
                key: key,
                index: index,
                player1Name: currentUserName ?? loc.loading,
                player2Name: opponentNameController.text.isEmpty
                    ? loc.guestOpponent
                    : opponentNameController.text,
                canRemove: _setKeys.length > 1,
                isSaving: isSaving,
                onRemove: () => removeSet(index),
                onChanged: (_) {},
              );
            }),

            TextButton.icon(
              onPressed: isSaving ? null : addSet,
              icon: const Icon(Icons.add),
              label: Text(loc.addSet),
            ),

            const SizedBox(height: 16),

            // ── Section: Match Info ──
            Text(
              loc.matchDetailsTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

            const SizedBox(height: 32),

            // ── Save button ──
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