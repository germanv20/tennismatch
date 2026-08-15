import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';

/// A single set score row with automatic tiebreak detection.
///
/// When the set score is 7-6 or 6-7, tiebreak point fields appear
/// automatically below the main score row.
///
/// The [onChanged] callback fires whenever any score value changes,
/// passing a [SetScoreData] with the current values.
/// Scoring mode determines at what score a tiebreak is triggered and shown.
enum ScoringMode {
  official,     // best of 6 games, tiebreak at 6-6 (score 7-6)
  proSet,       // single set to 8 games, tiebreak at 7-7 (score 8-7)
  open,         // no validation, no automatic tiebreak detection
  tiebreakOnly, // each entry is a standalone tiebreak, not a full set
}

/// Hard cap on how many sets/tiebreak entries a single match can have.
/// Sets were previously uncapped (only pro-set was ever locked to one) —
/// this guards against a stray tap (or a joke entry) producing a garbage,
/// oversized match document rather than reflecting any realistic match.
const int kMaxMatchEntries = 9;

class SetScoreRow extends StatefulWidget {
  final int index;
  final String player1Name;
  final String player2Name;
  final bool canRemove;
  final bool isSaving;
  final ScoringMode scoringMode;
  final VoidCallback onRemove;
  final ValueChanged<SetScoreData> onChanged;

  const SetScoreRow({
    super.key,
    required this.index,
    required this.player1Name,
    required this.player2Name,
    required this.canRemove,
    required this.isSaving,
    required this.onRemove,
    required this.onChanged,
    this.scoringMode = ScoringMode.official,
  });

  @override
  State<SetScoreRow> createState() => SetScoreRowState();
}

class SetScoreRowState extends State<SetScoreRow> {
  final TextEditingController p1Controller = TextEditingController();
  final TextEditingController p2Controller = TextEditingController();
  final TextEditingController tb1Controller = TextEditingController();
  final TextEditingController tb2Controller = TextEditingController();

  bool _showTiebreak = false;

  @override
  void initState() {
    super.initState();
    p1Controller.addListener(_onScoreChanged);
    p2Controller.addListener(_onScoreChanged);
    tb1Controller.addListener(_onScoreChanged);
    tb2Controller.addListener(_onScoreChanged);
  }

  @override
  void dispose() {
    p1Controller.dispose();
    p2Controller.dispose();
    tb1Controller.dispose();
    tb2Controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SetScoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scoringMode != widget.scoringMode) {
      // Re-evaluate tiebreak visibility under the new scoring mode
      _onScoreChanged();
    }
  }

  void _onScoreChanged() {
    final p1 = int.tryParse(p1Controller.text);
    final p2 = int.tryParse(p2Controller.text);

    // Detect tiebreak based on scoring mode:
    // - official: set score 7-6 or 6-7 (tiebreak at 6-6)
    // - proSet: set score 8-7 or 7-8 (tiebreak at 7-7)
    // - open: never auto-detect — user enters whatever they want
    // - tiebreakOnly: the entry *is* a tiebreak already — no nested
    //   breaker-within-a-set field makes sense here
    bool isTiebreak;
    switch (widget.scoringMode) {
      case ScoringMode.official:
        isTiebreak = (p1 == 7 && p2 == 6) || (p1 == 6 && p2 == 7);
        break;
      case ScoringMode.proSet:
        isTiebreak = (p1 == 8 && p2 == 7) || (p1 == 7 && p2 == 8);
        break;
      case ScoringMode.open:
      case ScoringMode.tiebreakOnly:
        isTiebreak = false;
        break;
    }

    if (isTiebreak != _showTiebreak) {
      setState(() {
        _showTiebreak = isTiebreak;
        // Clear tiebreak fields when hiding them
        if (!isTiebreak) {
          tb1Controller.clear();
          tb2Controller.clear();
        }
      });
    }

    // Notify parent of current values
    widget.onChanged(SetScoreData(
      p1: p1,
      p2: p2,
      tb1: _showTiebreak ? int.tryParse(tb1Controller.text) : null,
      tb2: _showTiebreak ? int.tryParse(tb2Controller.text) : null,
      isTiebreak: _showTiebreak,
    ));
  }

  /// Returns the current score data for validation
  SetScoreData get currentData => SetScoreData(
    p1: int.tryParse(p1Controller.text),
    p2: int.tryParse(p2Controller.text),
    tb1: _showTiebreak ? int.tryParse(tb1Controller.text) : null,
    tb2: _showTiebreak ? int.tryParse(tb2Controller.text) : null,
    isTiebreak: _showTiebreak,
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final entryLabel = widget.scoringMode == ScoringMode.tiebreakOnly
        ? loc.tiebreakEntryLabel(widget.index + 1)
        : loc.setLabel(widget.index + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Main set score row ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: p1Controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  // Free/open scoring has no built-in range validation, so
                  // cap entry at 2 digits — a real set score is never that
                  // long, this just guards against fat-fingered input.
                  inputFormatters: widget.scoringMode == ScoringMode.open
                      ? [LengthLimitingTextInputFormatter(2)]
                      : null,
                  decoration: InputDecoration(
                    labelText: entryLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '–',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: p2Controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: widget.scoringMode == ScoringMode.open
                      ? [LengthLimitingTextInputFormatter(2)]
                      : null,
                  decoration: InputDecoration(
                    labelText: entryLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: (widget.canRemove && !widget.isSaving)
                    ? widget.onRemove
                    : null,
              ),
            ],
          ),

          // ── Tiebreak row — appears automatically when score is 7-6 ──
          if (_showTiebreak) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const SizedBox(width: 8),
                const Icon(Icons.sports_tennis, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  loc.tiebreakLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tb1Controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.tiebreakPointsLabel,
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey.shade400,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '–',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: tb2Controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: loc.tiebreakPointsLabel,
                      labelStyle: const TextStyle(fontSize: 12),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.grey.shade400,
                        ),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
                // Spacer to align with remove button above
                const SizedBox(width: 48),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Data class holding all score values for a single set
class SetScoreData {
  final int? p1;
  final int? p2;
  final int? tb1;
  final int? tb2;
  final bool isTiebreak;

  const SetScoreData({
    required this.p1,
    required this.p2,
    this.tb1,
    this.tb2,
    required this.isTiebreak,
  });

  bool get isComplete {
    if (p1 == null || p2 == null) return false;
    if (isTiebreak && (tb1 == null || tb2 == null)) return false;
    return true;
  }

  /// Returns the Firestore map for this set
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'p1': p1,
      'p2': p2,
    };
    if (isTiebreak && tb1 != null && tb2 != null) {
      map['tb1'] = tb1;
      map['tb2'] = tb2;
    }
    return map;
  }
}