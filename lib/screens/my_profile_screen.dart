import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennismatch/gen_l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'dart:io';
import '../utils/day_utils.dart';
import '../utils/city_utils.dart';
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

          final userData =
              snapshot.data!.data() as Map<String, dynamic>;

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