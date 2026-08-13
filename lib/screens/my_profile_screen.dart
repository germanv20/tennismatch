import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'dart:io';
import '../utils/day_utils.dart';
import '../utils/city_utils.dart';
import '../utils/ranking_utils.dart';
import 'edit_profile_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  bool _isUploading = false;

  String translateLevel(String level, AppLocalizations loc) {
    switch (level) {
      case 'Beginner':    return loc.levelBeginner;
      case 'Intermediate': return loc.levelIntermediate;
      case 'Advanced':    return loc.levelAdvanced;
      default:            return level;
    }
  }

  String translateDay(String day, AppLocalizations loc) {
    switch (day) {
      case 'Mon': return loc.mon;
      case 'Tue': return loc.tue;
      case 'Wed': return loc.wed;
      case 'Thu': return loc.thu;
      case 'Fri': return loc.fri;
      case 'Sat': return loc.sat;
      case 'Sun': return loc.sun;
      default:    return day;
    }
  }

  String formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String getFlagEmoji(String countryName) {
    try {
      final countryObj = Country.tryParse(countryName);
      return countryObj?.flagEmoji ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _pickAndUploadPhoto(AppLocalizations loc) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (image == null) return;
    if (!mounted) return;

    setState(() => _isUploading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': downloadUrl});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.photoUpdated),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Photo upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.photoUploadError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Shows the type-to-confirm delete dialog and, on confirmation, calls
  /// the deleteMyAccount Cloud Function — which does all Firestore/
  /// Storage cleanup and the actual Firebase Auth deletion server-side
  /// (see functions/index.js for why this is a callable function rather
  /// than an auth onDelete trigger, and why it doesn't need the client
  /// to re-authenticate first). All state (typed confirmation text,
  /// in-progress spinner, error message) lives inside this dialog's own
  /// StatefulBuilder rather than the screen's State, since a dialog
  /// route doesn't rebuild automatically when the screen behind it
  /// calls setState. On success it signs out locally (so main.dart's
  /// auth listener routes back to the sign-in screen immediately rather
  /// than waiting on a stale token) and closes the dialog; the app-level
  /// screen switch that follows is the confirmation the user sees, so no
  /// separate success snackbar is needed here. On failure the dialog
  /// stays open with an inline error and the account is left untouched,
  /// so the user can simply retry.
  Future<void> _confirmDeleteAccount(AppLocalizations loc) async {
    final confirmController = TextEditingController();
    final requiredWord = loc.deleteAccountConfirmWord;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        bool isDeleting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final canConfirm = confirmController.text.trim().toUpperCase() ==
                requiredWord.toUpperCase();

            Future<void> handleConfirm() async {
              setDialogState(() {
                isDeleting = true;
                errorMessage = null;
              });
              try {
                await FirebaseFunctions.instance
                    .httpsCallable('deleteMyAccount')
                    .call();
                await FirebaseAuth.instance.signOut();
                // My Profile (and this dialog) were reached via
                // Navigator.push on top of the app's root screen, which
                // silently swaps to the sign-in landing screen underneath
                // as soon as we sign out — but a plain Navigator.pop()
                // here would only close the dialog, leaving My Profile's
                // now-permission-denied screen stuck on top of it. Pop
                // the whole stack back to the root in one go so that
                // already-updated sign-in screen is actually revealed.
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx)
                      .popUntil((route) => route.isFirst);
                }
              } catch (e) {
                debugPrint('❌ Account deletion error: $e');
                setDialogState(() {
                  isDeleting = false;
                  errorMessage = loc.deleteAccountError;
                });
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(loc.deleteAccountDialogTitle)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loc.deleteAccountWarning),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    autocorrect: false,
                    enabled: !isDeleting,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: loc.deleteAccountConfirmHint(requiredWord),
                    ),
                  ),
                  if (isDeleting) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text(loc.deleteAccountInProgress),
                      ],
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isDeleting ? null : () => Navigator.pop(dialogCtx),
                  child: Text(loc.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed:
                      (canConfirm && !isDeleting) ? handleConfirm : null,
                  child: Text(loc.deleteAccountButton),
                ),
              ],
            );
          },
        );
      },
    );

    confirmController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myProfile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .get();
              final data = doc.data() as Map<String, dynamic>;
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(userData: data),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // The account can disappear mid-stream if it's just been
          // deleted via the Danger Zone below — deleteMyAccount()
          // removes this document server-side before the client's own
          // sign-out/navigation-away has necessarily happened yet, so
          // this listener can briefly see "document no longer exists"
          // while that transition is still in flight. Show a spinner
          // rather than crashing on a null cast; the screen is about to
          // be torn down by the auth-state change anyway.
          final rawData = snapshot.data!.data();
          if (rawData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = rawData as Map<String, dynamic>;

          final String name = userData['name'] ?? loc.unknown;
          final String email = userData['email'] ?? '';
          final String rawLevel = userData['tennisLevel'] ?? '';
          final String tennisLevel = rawLevel.isEmpty
              ? loc.notSet
              : translateLevel(rawLevel, loc);
          final List<String> availability =
              sortDays(userData['availability'] ?? []);
          final String? photoUrl = userData['photoUrl'];
          final Timestamp? birthTimestamp = userData['birthDate'];
          final int? age = userData['age'];
          final String rawCity = (userData['city'] as String? ?? '');
          final String city =
              rawCity.isNotEmpty ? formatCityDisplay(rawCity) : loc.notSet;
          final String country = userData['country'] ?? loc.notSet;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [

                    // ── Profile photo — tappable ──
                    GestureDetector(
                      onTap: _isUploading
                          ? null
                          : () => _pickAndUploadPhoto(loc),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl == null
                                ? const Icon(Icons.person, size: 50)
                                : null,
                          ),
                          // Uploading spinner overlay
                          if (_isUploading)
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          // Camera badge (hidden while uploading)
                          if (!_isUploading)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tap hint
                    if (!_isUploading)
                      Text(
                        loc.tapToChangePhoto,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                    if (_isUploading)
                      Text(
                        loc.uploadingPhoto,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                    const SizedBox(height: 20),

                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(email),
                    const SizedBox(height: 24),

                    if (age != null) ...[
                      Text('🎂 ${loc.age}: $age',
                          style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 12),
                    ],

                    Text('📍 ${loc.city}: $city',
                        style: const TextStyle(fontSize: 15)),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (country != loc.notSet)
                          Text(getFlagEmoji(country),
                              style: const TextStyle(fontSize: 18)),
                        if (country != loc.notSet)
                          const SizedBox(width: 6),
                        Text('${loc.country}: $country',
                            style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (birthTimestamp != null) ...[
                      Text(
                        '📅 ${loc.birthDate}: ${formatDate(birthTimestamp.toDate())}',
                        style: const TextStyle(fontSize: 15),
                      ),
                      const SizedBox(height: 24),
                    ],

                    Text(
                      '🎾 ${loc.level}: $tennisLevel',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Elo rating badge — Phase 2, regular matches only.
                    // eloRating/eloMatchesPlayed are only ever written by
                    // applyEloRatings() in functions/index.js (Admin SDK),
                    // never by the client. Hidden until this user has at
                    // least one rated regular match, so a brand-new
                    // player doesn't see a meaningless flat 1200.
                    Builder(
                      builder: (context) {
                        final eloMatchesPlayed =
                            (userData['eloMatchesPlayed'] as int?) ?? 0;
                        if (eloMatchesPlayed == 0) {
                          return const SizedBox.shrink();
                        }
                        final eloRating =
                            (userData['eloRating'] as int?) ?? 1200;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.indigo.shade200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.trending_up,
                                  size: 16, color: Colors.indigo.shade700),
                              const SizedBox(width: 6),
                              Text(
                                '${loc.eloRatingLabel}: $eloRating',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // ── Ranking position — Phase 3. Only meaningful once
                    // this user has cleared the same eloRankingMinMatches
                    // threshold the Ranking screen itself uses, and only
                    // once they have a city set. Computed client-side via
                    // the same buildCityRanking() helper the full Ranking
                    // screen uses, over a fresh users snapshot, so the two
                    // screens can never disagree about someone's position.
                    if ((userData['eloMatchesPlayed'] as int? ?? 0) >=
                            eloRankingMinMatches &&
                        rawCity.isNotEmpty)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final ranking = buildCityRanking(
                              snapshot.data!.docs, rawCity);
                          final myIndex = ranking.indexWhere(
                              (doc) => doc.id == FirebaseAuth.instance
                                  .currentUser?.uid);
                          if (myIndex == -1) return const SizedBox.shrink();

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              loc.rankingPositionLabel(
                                  myIndex + 1, city),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    availability.isEmpty
                        ? Text(loc.noAvailability,
                            style: const TextStyle(color: Colors.grey))
                        : Wrap(
                            spacing: 8,
                            children: availability.map<Widget>((day) {
                              return Chip(
                                label: Text(
                                    translateDay(day.toString(), loc)),
                              );
                            }).toList(),
                          ),

                    const SizedBox(height: 32),

                    // ── Privacy Policy link ──
                    TextButton.icon(
                      icon: Icon(Icons.privacy_tip_outlined,
                          size: 16, color: Colors.grey[600]),
                      label: Text(
                        loc.privacyPolicyLink,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(
                            'https://sites.google.com/view/tennismatch-privacy');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),

                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 8),

                    // ── Danger Zone — permanent account deletion ──
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        loc.dangerZoneTitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: Text(loc.deleteAccountButton),
                        onPressed: () => _confirmDeleteAccount(loc),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}