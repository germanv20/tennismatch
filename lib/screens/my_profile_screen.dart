import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/theme_service.dart';
import '../utils/day_utils.dart';
import '../utils/city_utils.dart';
import '../utils/ranking_utils.dart';
import '../widgets/profile_stat_grid.dart';
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

  /// Builds the Duolingo-style stat grid (Sept 2026 redesign, see
  /// CLAUDE.md). Cell order is fixed by explicit user request: age, level /
  /// matches played, rating / ranking position, ranking score / country
  /// (flag + name), city — built up sequentially below so the list order
  /// *is* the grid order (row-major, 2 columns), rather than inserting at
  /// a hard-coded index. Age/rating/ranking are hidden individually when
  /// absent/zero (same "hide if not meaningful yet" convention as before);
  /// level, matches, country and city are always shown. Ranking position
  /// needs its own live `users` query (same `buildCityRanking()` helper
  /// the full Ranking screen uses), so only that part of the grid is built
  /// inside a conditional `StreamBuilder`.
  Widget _buildStatGrid(
    BuildContext context,
    Map<String, dynamic> userData,
    AppLocalizations loc,
    String rawCity,
    String city,
    String tennisLevel,
    String country,
    int? age,
  ) {
    final matchesPlayed = (userData['matchesPlayed'] as int?) ?? 0;
    final eloMatchesPlayed = (userData['eloMatchesPlayed'] as int?) ?? 0;
    final eloRating = (userData['eloRating'] as int?) ?? 1200;
    final ratingCount = (userData['reputationRatingCount'] as int?) ?? 0;
    final ratingSum = (userData['reputationRatingSum'] as int?) ?? 0;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final flagEmoji = getFlagEmoji(country);

    final headCells = <ProfileStatCell>[
      if (age != null)
        ProfileStatCell(
          icon: Icons.cake_outlined,
          value: '$age',
          label: loc.age,
          color: Colors.pink.shade400,
        ),
      ProfileStatCell(
        icon: Icons.military_tech,
        value: tennisLevel,
        label: loc.level,
        color: Colors.teal.shade700,
      ),
      ProfileStatCell(
        icon: Icons.sports_tennis,
        value: '$matchesPlayed',
        label: loc.matchesPlayed,
        color: Colors.green.shade700,
      ),
      if (ratingCount > 0)
        ProfileStatCell(
          icon: Icons.star,
          value: (ratingSum / ratingCount).toStringAsFixed(1),
          label: loc.ratingLabel,
          color: Colors.amber.shade800,
        ),
    ];

    // Ranking score, country (flag + name), city — appended after ranking
    // position (if any), so the final order is always ...rating, position,
    // score, country, city.
    List<ProfileStatCell> withTail(List<ProfileStatCell> cells) {
      if (eloMatchesPlayed > 0) {
        cells.add(ProfileStatCell(
          icon: Icons.trending_up,
          value: '$eloRating',
          label: loc.eloRatingLabel,
          color: Colors.indigo.shade700,
        ));
      }
      cells.add(ProfileStatCell(value: flagEmoji, label: country));
      cells.add(ProfileStatCell(
        icon: Icons.location_on,
        value: city,
        label: loc.city,
        color: Colors.blueGrey.shade600,
      ));
      return cells;
    }

    final showRanking =
        eloMatchesPlayed >= eloRankingMinMatches && rawCity.isNotEmpty;
    if (!showRanking) {
      return ProfileStatGrid(
          cells: withTail(List<ProfileStatCell>.from(headCells)));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final cells = List<ProfileStatCell>.from(headCells);
        if (snapshot.hasData) {
          final ranking = buildCityRanking(snapshot.data!.docs, rawCity);
          final myIndex = ranking.indexWhere((doc) => doc.id == uid);
          if (myIndex != -1) {
            cells.add(ProfileStatCell(
              icon: Icons.emoji_events,
              value: '#${myIndex + 1}',
              label: loc.rankingCityHeader(city),
              color: Colors.orange.shade700,
            ));
          }
        }
        return ProfileStatGrid(cells: withTail(cells));
      },
    );
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

                    if (birthTimestamp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '📅 ${loc.birthDate}: ${formatDate(birthTimestamp.toDate())}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Stat grid (Sept 2026 redesign, see CLAUDE.md) ──
                    // Fixed cell order per explicit request: age, level /
                    // matches, rating / ranking position, ranking score /
                    // country, city. Replaces the old separate city/country/
                    // level text lines below, which are now grid cells.
                    _buildStatGrid(context, userData, loc, rawCity, city,
                        tennisLevel, country, age),

                    const SizedBox(height: 24),

                    // ── Availability chips — colored with the user's
                    // selected theme (same selectionColor Home screen's own
                    // Level/Availability chips use), with a small caption
                    // underneath matching the stat grid's icon+label
                    // convention above.
                    Builder(
                      builder: (context) {
                        final selectionColor = context
                            .watch<ThemeNotifier>()
                            .current
                            .selectionColor;
                        return Column(
                          children: [
                            availability.isEmpty
                                ? Text(loc.noAvailability,
                                    style:
                                        const TextStyle(color: Colors.grey))
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: availability.map<Widget>((day) {
                                      return Chip(
                                        label: Text(
                                          translateDay(day.toString(), loc),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        backgroundColor: selectionColor,
                                      );
                                    }).toList(),
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              loc.availability,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        );
                      },
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