import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen_l10n/app_localizations.dart';
import '../utils/skill_level.dart';
import 'skill_level_picker.dart';

/// Home-screen card asking existing users (who only have the old Beginner /
/// Intermediate / Advanced level) to choose their new-style level —
/// categories in Colombia, NTRP elsewhere. Soft prompt: "Later" hides it for
/// [snoozeDays] days (stored on the phone) and it comes back; it disappears
/// for good once a level of the country's system is saved. Hidden
/// (SizedBox.shrink) otherwise.
class SkillLevelPrompt extends StatefulWidget {
  /// The current user's live `users/{uid}` data.
  final Map<String, dynamic> userData;

  const SkillLevelPrompt({super.key, required this.userData});

  static const int snoozeDays = 3;

  /// True when the user still has to choose a level for their country's system.
  static bool needsChoice(Map<String, dynamic> d) {
    final system = SkillLevel.systemForCountryCode(d['countryCode'] as String?);
    final stored = SkillLevel.fromUserData(d);
    return stored == null || stored.system != system;
  }

  @override
  State<SkillLevelPrompt> createState() => _SkillLevelPromptState();
}

class _SkillLevelPromptState extends State<SkillLevelPrompt> {
  bool _loaded = false;
  bool _snoozed = false;

  String? get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : 'skill_level_prompt_snooze_until_$uid';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var snoozed = false;
    final key = _key;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      snoozed =
          DateTime.now().millisecondsSinceEpoch < (prefs.getInt(key) ?? 0);
    }
    if (!mounted) return;
    setState(() {
      _snoozed = snoozed;
      _loaded = true;
    });
  }

  Future<void> _snooze() async {
    final key = _key;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        key,
        DateTime.now()
            .add(const Duration(days: SkillLevelPrompt.snoozeDays))
            .millisecondsSinceEpoch,
      );
    }
    if (!mounted) return;
    setState(() => _snoozed = true);
  }

  Future<void> _choose() async {
    final d = widget.userData;
    final system = SkillLevel.systemForCountryCode(d['countryCode'] as String?);
    final picked = await showSkillLevelSheet(
      context,
      system: system,
      suggested: SkillLevel.suggestionFromLegacy(
          system, d['tennisLevel'] as String?),
    );
    if (picked == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // The Home screen streams this doc, so the card disappears on its own.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(SkillLevel.toFirestore(system, picked));
    } catch (_) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.somethingWentWrong)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _snoozed || !SkillLevelPrompt.needsChoice(widget.userData)) {
      return const SizedBox.shrink();
    }
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.military_tech, color: Colors.blue[800]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.levelPromptTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.levelPromptBody,
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _choose,
                        child: Text(loc.levelPromptChoose),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _snooze,
                        child: Text(loc.photoReminderLater),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
