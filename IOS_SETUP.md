# iOS setup runbook (Tennis Match)

Branch: `ios-support`. **Never build the Android `.aab` from this branch** — switch to
`main` first (`git switch main`, check `git branch --show-current`). Cloud Functions and
Firestore rules also deploy from whatever branch is checked out.

Everything below marked "code" was already prepared on Windows **without being compiled**
(no Mac/Xcode available). Expect small compile fixes on the Mac. Run `flutter analyze` first.

Bundle ID: `com.tennismatch.app` · iPhone only · minimum iOS 15.0 · Sign in with Apple +
Google · push via APNs/FCM.

---

## Part A — before the Mac (no Mac needed)

### A1. Apple Developer Program
Enroll at developer.apple.com/programs/enroll ($99 USD/year, individual). Use your legal
name exactly (it becomes the seller name on the App Store). Needs 2FA on the Apple Account.
Approval can take from hours to days.

### A2. Firebase: register the iOS app
Firebase console → Project settings → Your apps → Add app → iOS.
- Apple bundle ID: `com.tennismatch.app` (the old iOS app in `firebase_options.dart` used
  `com.example.tennismatch`; register a NEW app, don't reuse it).
- Download `GoogleService-Info.plist` and keep it (needed on the Mac, see B3).

### A3. Firebase Auth: enable Apple
Authentication → Sign-in method → Apple → Enable → Save. (Nothing else is needed for the
native iPhone flow; no Services ID.)

### A4. Firebase App Check (optional, do not enforce)
App Check → Apps → register the iOS app with **App Attest**. Leave enforcement OFF.

### A5. Apple Developer portal (after enrollment)
1. Identifiers → `+` → App IDs → App → bundle ID `com.tennismatch.app`; enable
   **Push Notifications** and **Sign in with Apple**. (Xcode's automatic signing can also
   do this later.)
2. Keys → `+` → check **Apple Push Notifications service (APNs)** → download the `.p8`
   (downloadable ONCE). Note the **Key ID** and your **Team ID**. Never commit the `.p8`.
3. Firebase → Project settings → Cloud Messaging → Apple app configuration → upload the
   APNs Authentication Key (`.p8`, Key ID, Team ID).

### A6. App Store Connect
My Apps → `+` → New App: platform iOS, name "Tennis Match" (if taken, pick a variant for
the store listing only), primary language, bundle ID `com.tennismatch.app`, any SKU.

---

## Part B — on the Mac

### B1. Tools
- Xcode (App Store; Apple requires Xcode 26+ for uploads). Open it once, accept the license,
  install the iOS platform/simulator when asked. Then `xcode-select --install`.
- Flutter SDK — same version as on Windows (`flutter --version` there).
- CocoaPods (`brew install cocoapods`), Git.
- `flutter doctor` must be green for iOS.

### B2. Get the code
```
git clone <your GitHub repo URL> tennismatch
cd tennismatch
git switch ios-support
flutter pub get
```

### B3. Firebase config
**Steps 2 and 3 are already done on Windows** (real values are in `Info.plist` and the `ios` block of `lib/firebase_options.dart`). Only step 1 (adding the plist through Xcode) remains on the Mac. Original instructions, for reference:
1. Copy `GoogleService-Info.plist` into `ios/Runner/` **through Xcode**: open
   `ios/Runner.xcworkspace`, File → Add Files to "Runner…", tick "Copy items if needed" and
   the Runner target.
2. `ios/Runner/Info.plist`: replace
   `com.googleusercontent.apps.REPLACE_WITH_REVERSED_CLIENT_ID` with the plist's
   `REVERSED_CLIENT_ID` value (the whole string).
3. `lib/firebase_options.dart`, `ios` block, from the new plist (hand-edit; don't let
   `flutterfire configure` rewrite the whole file):
   `apiKey` ← API_KEY, `appId` ← GOOGLE_APP_ID, `messagingSenderId` ← GCM_SENDER_ID,
   `projectId`, `storageBucket` ← STORAGE_BUCKET, `iosClientId` ← CLIENT_ID,
   `iosBundleId: 'com.tennismatch.app'`. (The `macos` block is unused; leave it.)

### B4. Pods
The repo has no `Podfile`; Flutter creates it on the first iOS build:
```
flutter build ios --no-codesign     # creates ios/Podfile (may fail later, that's ok)
```
Edit `ios/Podfile`: uncomment/set `platform :ios, '15.0'`. Then:
```
cd ios && pod install --repo-update && cd ..
```
Always open `ios/Runner.xcworkspace` (not `.xcodeproj`).

### B5. Xcode signing & capabilities
Runner target → Signing & Capabilities: Team = your paid team, "Automatically manage
signing", bundle ID `com.tennismatch.app`. Check these exist (add with `+ Capability` if
not): **Push Notifications**, **Sign in with Apple**, **Background Modes → Remote
notifications**. `Runner/Runner.entitlements` is already referenced by the project; if Xcode
can't see it, drag it into the Runner group.

### B6. Run
- Simulator: `flutter run` (pick an iPhone). No real push; Apple sign-in needs an Apple ID
  signed in under the simulator's Settings.
- Real iPhone: enable Developer Mode (Settings → Privacy & Security), connect by cable,
  trust the Mac, `flutter run -d <device>`.

### B7. Test checklist (real iPhone)
- Google sign-in; Sign in with Apple (try "Hide My Email" and a fresh Apple ID → name arrives
  only the first time; Complete Profile pre-fills it).
- Complete Profile, photo from library, WhatsApp share, monthly-recap share image.
- Push: send a match request from an Android phone → push arrives on the iPhone (sound,
  banner), tapping opens the right screen; also while the app is open and while terminated.
- Delete account with an Apple user (Apple sheet appears to revoke the token).
- Spanish and English; keyboard/safe-area problems on small and large iPhones.

### B8. Code fixes to expect
- `lib/services/apple_auth_service.dart`: `revokeTokenWithAuthorizationCode` is called
  dynamically on purpose (never compiled). Once `flutter analyze` is clean, replace it with
  `FirebaseAuth.instance.revokeTokenWithAuthorizationCode(apple.authorizationCode)` (if the
  name differs, check the firebase_auth docs).
- `SignInWithAppleButton` parameters, `AppleProvider.*` names (firebase_app_check) and the
  `sign_in_with_apple ^6.1.4` constraint were written from memory — fix on analyze errors.
- If Apple emails ITMS-90683 (missing purpose string), add the named key to Info.plist.

### B9. TestFlight / App Store
1. Increase the build number (`version: 1.x.y+N` in `pubspec.yaml`; N must grow every upload).
2. `flutter build ipa --release`, then Xcode → Window → Organizer → Distribute App → App
   Store Connect → Upload (or the Transporter app).
3. App Store Connect → TestFlight: internal testers (people with an App Store Connect role)
   get builds at once; external testers (public link) need a short Beta App Review.
   Encryption question is pre-answered (`ITSAppUsesNonExemptEncryption = NO`).
4. Store listing: screenshots (required iPhone sizes shown in App Store Connect), es/en
   description, keywords, support URL, privacy policy URL (existing), App Privacy answers
   (name, email, photo, user content, identifiers — linked to the user, app functionality,
   no tracking), age rating, category Sports, price Free, availability countries.
5. App Review notes: a demo Google account for the reviewer + a short description. Mention
   both Google and Apple sign-in; account deletion is in My Profile → Danger Zone.

---

## Part C — merging and deploying (back on Windows)
- Test the Android app on a phone from this branch before merging to `main`.
- `functions/index.js` got an additive `apns: {payload: {aps: {sound: "default"}}}` default
  in `sendPushToUser` (Android ignores it). Deploy only after merging:
  `firebase deploy --only functions`.
- Existing note, not changed: App Check on Android still uses `AndroidProvider.debug` even in
  release; it only works because enforcement is OFF. Moving to Play Integrity is a separate task.
- Do not run `flutter pub run flutter_launcher_icons`: the iOS icons are already generated
  (opaque, no transparency — Apple rejects icons with alpha) and its config points to a file
  that doesn't exist.
