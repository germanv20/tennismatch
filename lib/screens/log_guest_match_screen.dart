import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:country_picker/country_picker.dart';
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
  final notesController = TextEditingController();
  ScoringMode scoringMode = ScoringMode.official;
  DateTime? selectedMatchDate;

  // Player names (loaded from Firestore)
  String? currentUserName;
  String? currentUserUid;

  bool isSaving = false;
  bool allowTie = false;

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

    // Default the guest's phone field to the creator's own country code —
    // most logged opponents share the same country. Only a starting
    // point: the field stays fully editable, and this never overwrites
    // anything the user may have already typed while this future ran.
    final data = doc.data();
    final ownCountryCode = data?['countryCode'] as String?;
    if (opponentPhoneController.text.trim().isEmpty) {
      final prefix = _phoneCodePrefix(ownCountryCode);
      if (prefix != null) {
        opponentPhoneController.text = prefix;
      }
    }
  }

  /// Returns "+<callingCode> " for the given ISO country code (e.g. "CO"
  /// -> "+57 "), or null if it can't be resolved.
  String? _phoneCodePrefix(String? isoCountryCode) {
    if (isoCountryCode == null || isoCountryCode.isEmpty) return null;
    try {
      final match = CountryService()
          .getAll()
          .firstWhere((c) => c.countryCode == isoCountryCode);
      return '+${match.phoneCode} ';
    } catch (_) {
      return null;
    }
  }

  void addSet() {
    if (_setKeys.length >= _maxEntriesForCurrentMode) return;
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
    opponentNameController.dispose();
    opponentPhoneController.dispose();
    durationController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  // Whether the user has meaningfully started filling this out — used to
  // decide whether an accidental back-press needs a confirm dialog.
  // Deliberately ignores the phone field, since it's now pre-filled with
  // a country-code default that would otherwise mark the form "dirty"
  // the instant the screen opens, before the user's touched anything.
  bool get _hasUnsavedData {
    if (opponentNameController.text.trim().isNotEmpty) return true;
    if (locationController.text.trim().isNotEmpty) return true;
    if (durationController.text.trim().isNotEmpty) return true;
    if (notesController.text.trim().isNotEmpty) return true;
    for (final key in _setKeys) {
      final data = key.currentState?.currentData;
      if (data != null && (data.p1 != null || data.p2 != null)) return true;
    }
    return false;
  }

  Future<bool> _confirmDiscard(AppLocalizations loc) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.discardMatchTitle),
        content: Text(loc.discardMatchMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.discardButton,
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
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

  /// Pro-set: single set to 8 games, win by 2, tiebreak at 7-7 (won 9-7 in the
  /// breaker, recorded as an 8-7 set score)
  bool isValidProSet(int p1, int p2) {
    if (p1 < 8 && p2 < 8) return false;
    if ((p1 == 8 && p2 <= 6) || (p2 == 8 && p1 <= 6)) return true;
    if ((p1 == 8 && p2 == 7) || (p2 == 8 && p1 == 7)) return true;
    if ((p1 >= 9 || p2 >= 9) && (p1 - p2).abs() >= 2) return true;
    return false;
  }

  /// Pro-set tiebreak: first to 7 (sudden death style breaker), win by 2
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
      'https://play.google.com/store/apps/details?id=com.tennismatch.app',
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
    // Normalise phone to E.164 with + prefix for consistent storage.
    // Strips spaces/dashes/parens first — the phone field is now
    // pre-filled with "+<code> " (see _loadCurrentUser), so the raw
    // input routinely contains a space the old code below never
    // accounted for; without stripping it here, the phoneIndex key
    // would silently mismatch CompleteProfileScreen's own normalised
    // (space-free) format and break the guest-match claim mechanic.
    final rawPhoneInput =
        opponentPhoneController.text.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final opponentPhone = rawPhoneInput.isNotEmpty && !rawPhoneInput.startsWith('+')
        ? '+$rawPhoneInput'
        : rawPhoneInput;

    // p1 = current user (always), p2 = guest opponent
    final bool isTie = allowTie && p1Wins == p2Wins;
    final bool currentUserWon = !isTie && p1Wins > p2Wins;
    final String? winnerUid = isTie ? null
        : (currentUserWon ? uid : 'guest');

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
      if (isTie) 'isTie': true,
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

    // NOTE: matchesPlayed/wins/losses/totalDuration are now updated
    // server-side by the onMatchCompleted Cloud Function, which triggers
    // when this match document is created with status 'completed'.

    await batch.commit();

    if (!mounted) return;

    // ── Pop first so we return to HomeScreen ──
    // Store what we need before popping (context will be gone after)
    final opponentPhoneCopy = opponentPhone;
    final opponentNameCopy = opponentName;
    final formattedSetsCopy = List<Map<String, dynamic>>.from(formattedSets);
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

    return PopScope(
      canPop: !_hasUnsavedData,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldDiscard = await _confirmDiscard(loc);
        if (shouldDiscard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                    label: loc.shortSetScoring,
                    mode: ScoringMode.shortSet,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _scoringModeChip(
                    label: loc.tiebreakOnlyScoring,
                    mode: ScoringMode.tiebreakOnly,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _scoringModeChip(
                    label: loc.openScoring,
                    mode: ScoringMode.open,
                  ),
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
                scoringMode: scoringMode,
                isSuperTiebreak: _isShortSetDecider(index),
                onRemove: () => removeSet(index),
                onChanged: (_) => setState(() {}),
              );
            }),

            if (scoringMode != ScoringMode.proSet &&
                _setKeys.length < _maxEntriesForCurrentMode)
              TextButton.icon(
                onPressed: isSaving ? null : addSet,
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
      ),
    );
  }
}