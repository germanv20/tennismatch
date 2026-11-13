import 'package:flutter/foundation.dart';

/// Store listing links for the app.
///
/// The App Store link has no country code on purpose: Apple redirects it to
/// the viewer's own storefront (the app is currently only published in
/// Colombia and The Bahamas).
class StoreLinks {
  static const String playStore =
      'https://play.google.com/store/apps/details?id=com.tennismatch.app';
  static const String appStore = 'https://apps.apple.com/app/id6831438177';

  /// Opens the App Store's "write a review" sheet for the app.
  static const String appStoreReview = '$appStore?action=write-review';

  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// The store this phone's own app came from — used for "Rate us".
  static String get ownStore => isIOS ? appStoreReview : playStore;

  /// Text for invite messages (WhatsApp, recap sharing). The receiver may
  /// have a different kind of phone than the sender, so both links are
  /// included.
  static const String inviteLinks =
      'Android: $playStore\niPhone: $appStore';
}
