import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gen_l10n/app_localizations.dart';
import '../services/profile_photo_service.dart';

/// Home-screen reminder shown while the user has no profile photo. "Later"
/// hides it for [snoozeDays] days (stored on the phone), after which it
/// comes back; it disappears for good once a photo exists. Hidden
/// (SizedBox.shrink) otherwise, so it costs no space.
class ProfilePhotoReminder extends StatefulWidget {
  /// The current user's `photoUrl` from the live user doc.
  final Object? photoUrl;

  const ProfilePhotoReminder({super.key, required this.photoUrl});

  static const int snoozeDays = 3;

  @override
  State<ProfilePhotoReminder> createState() => _ProfilePhotoReminderState();
}

class _ProfilePhotoReminderState extends State<ProfilePhotoReminder> {
  bool _loaded = false;
  bool _snoozed = false;
  bool _dismissedForever = false;
  bool _uploading = false;

  String? get _key {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : 'photo_reminder_snooze_until_$uid';
  }

  String? get _foreverKey {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : 'photo_reminder_dismissed_$uid';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final key = _key;
    var snoozed = false;
    var forever = false;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(key) ?? 0;
      snoozed = DateTime.now().millisecondsSinceEpoch < until;
      final fk = _foreverKey;
      forever = fk != null && (prefs.getBool(fk) ?? false);
    }
    if (!mounted) return;
    setState(() {
      _dismissedForever = forever;
      _snoozed = snoozed;
      _loaded = true;
    });
  }

  Future<void> _snooze() async {
    final key = _key;
    if (key != null) {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now()
          .add(const Duration(days: ProfilePhotoReminder.snoozeDays))
          .millisecondsSinceEpoch;
      await prefs.setInt(key, until);
    }
    if (!mounted) return;
    setState(() => _snoozed = true);
  }

  /// "This is my photo": the user already has a real Google picture.
  Future<void> _dismissForever() async {
    final fk = _foreverKey;
    if (fk != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(fk, true);
    }
    if (!mounted) return;
    setState(() => _dismissedForever = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded ||
        _snoozed ||
        _dismissedForever ||
        !ProfilePhotoService.needsOwnPhoto(widget.photoUrl)) {
      return const SizedBox.shrink();
    }
    final loc = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.add_a_photo_outlined, color: Colors.amber[800]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.photoReminderTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.photoReminderBody,
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      FilledButton(
                        onPressed: _uploading
                            ? null
                            : () => ProfilePhotoService.pickAndUpload(
                                  context,
                                  onUploadingChanged: (u) {
                                    if (mounted) setState(() => _uploading = u);
                                  },
                                ),
                        child: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(loc.photoReminderAdd),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _uploading ? null : _snooze,
                        child: Text(loc.photoReminderLater),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: _uploading ? null : _dismissForever,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        loc.photoReminderHasPhoto,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
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
