import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple, used on iPhone only.
///
/// App Store guideline 4.8 requires apps that offer a third-party login
/// (Google) to also offer an equivalent privacy-preserving one, so the
/// login screen shows an Apple button on iOS (hidden on Android). The flow
/// is the standard Firebase one: a random nonce is hashed for Apple and the
/// raw value is handed to Firebase to verify the identity token.
class AppleAuthService {
  /// Sign in with Apple is only offered on iPhone.
  static bool get isSupported => defaultTargetPlatform == TargetPlatform.iOS;

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Runs the Apple sign-in and signs the user into Firebase.
  ///
  /// Returns null if the user cancelled the Apple sheet. Apple only sends
  /// the person's name the FIRST time they authorize the app, so it is
  /// copied onto the Firebase user's displayName right away — the Complete
  /// Profile screen pre-fills the name field from it (and lets them edit it
  /// or type it in if Apple didn't send one).
  static Future<UserCredential?> signIn() async {
    final rawNonce = _generateNonce();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: _sha256(rawNonce),
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
        accessToken: apple.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      final fullName =
          '${apple.givenName ?? ''} ${apple.familyName ?? ''}'.trim();
      final user = userCredential.user;
      if (user != null &&
          fullName.isNotEmpty &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(fullName);
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }

  /// Apple requires revoking the Sign in with Apple token when an account
  /// is deleted. Call this BEFORE deleting the account (the user must still
  /// be signed in). It asks Apple for a fresh authorization code (the user
  /// sees the Apple sheet) and hands it to Firebase to revoke. Does nothing
  /// for non-Apple users. Never throws: a failure here must not block the
  /// deletion itself.
  static Future<void> revokeAppleTokenIfNeeded() async {
    if (!isSupported) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final isAppleUser =
        user.providerData.any((info) => info.providerId == 'apple.com');
    if (!isAppleUser) return;

    try {
      final rawNonce = _generateNonce();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
        nonce: _sha256(rawNonce),
      );
      // NOTE: called dynamically on purpose — written without being able to
      // compile it (no Mac/Flutter at that time). On the Mac, replace with
      // the typed call FirebaseAuth.instance.revokeTokenWithAuthorizationCode(
      // apple.authorizationCode) once `flutter analyze` confirms the name.
      await (FirebaseAuth.instance as dynamic)
          .revokeTokenWithAuthorizationCode(apple.authorizationCode);
    } catch (e) {
      debugPrint('Apple token revocation failed (non-fatal): $e');
    }
  }
}
