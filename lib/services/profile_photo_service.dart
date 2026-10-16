import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../gen_l10n/app_localizations.dart';

/// Picks a photo from the gallery, uploads it to Storage
/// (`profile_photos/{uid}.jpg`, same path Home's avatar uses) and writes the
/// download URL to `users/{uid}.photoUrl`. Shared by the Complete Profile
/// avatar and the Home "add a photo" reminder.
class ProfilePhotoService {
  ProfilePhotoService._();

  /// True when the profile has no real photo: null/empty, or Google's
  /// auto-generated default avatar (the colored letter). Google accounts
  /// without a picture still return a `photoURL`, pointing at an image
  /// containing `default-user` in its path, so a plain null/empty check
  /// never sees them as missing.
  static bool isMissing(Object? photoUrl) {
    final s = photoUrl?.toString().trim() ?? '';
    return s.isEmpty || s.contains('default-user');
  }

  /// True unless the photo was uploaded from inside the app. Google's
  /// auto-generated letter avatar has an ordinary-looking `photoURL`
  /// (`lh3.googleusercontent.com/a/ACg8oc...`) that can't be told apart from
  /// a real Google profile picture, so the Home reminder can't know whether
  /// a Google photo is a face or a letter. Anything not under our own
  /// `profile_photos/` Storage path counts as "not chosen yet".
  static bool needsOwnPhoto(Object? photoUrl) =>
      isMissing(photoUrl) || !photoUrl.toString().contains('profile_photos');

  /// Returns the new download URL, or null if cancelled / failed (a snackbar
  /// is shown on failure). [onUploadingChanged] lets the caller show its own
  /// spinner instead of relying on the snackbar.
  static Future<String?> pickAndUpload(
    BuildContext context, {
    void Function(bool uploading)? onUploadingChanged,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final XFile? image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75, // compress to reduce upload size
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return null; // user cancelled

    onUploadingChanged?.call(true);
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');
      await ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': url});

      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.photoUpdated),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      return url;
    } catch (e) {
      debugPrint('❌ Photo upload error: $e');
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(loc.photoUploadError),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    } finally {
      onUploadingChanged?.call(false);
    }
  }
}
