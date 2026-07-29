# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

TennisMatch is a Flutter mobile app (Android-focused; iOS/macOS/web/windows/linux scaffolding exists but is unused) backed entirely by Firebase: Firestore (data), Firebase Auth + Google Sign-In (auth), Cloud Messaging (push notifications), Cloud Storage, App Check, and Cloud Functions (server-side triggers/cron). There is no custom backend server — `functions/index.js` is the only server-side code.

The app lets players find opponents by tennis level/city, send/accept match requests, log singles/doubles/guest match results, chat per-match, and track win/loss stats and head-to-head records.

## Common commands

Run all commands from the repo root unless noted.

```bash
# Install Dart/Flutter deps
flutter pub get

# Run the app (Android is the primary target)
flutter run

# Static analysis (uses analysis_options.yaml / flutter_lints)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Regenerate localization classes (lib/gen_l10n) after editing lib/l10n/*.arb
flutter gen-l10n

# Regenerate launcher icons after changing assets/icon/
flutter pub run flutter_launcher_icons

# Build a release APK
flutter build apk --release
```

Cloud Functions (in `functions/`, Node 24, deployed via Firebase CLI):

```bash
cd functions
npm install
npm run lint            # eslint (eslint-config-google)
npm run serve            # firebase emulators:start --only functions
npm run shell            # interactive functions shell
npm run deploy            # firebase deploy --only functions
npm run logs            # firebase functions:log
```

Firestore rules/indexes are deployed separately, e.g. `firebase deploy --only firestore:rules,firestore:indexes`.

Note: `test/widget_test.dart` is still the default Flutter counter-app smoke test and does not exercise this app — there is no real automated test coverage yet. Don't treat it as a template for how the app behaves.

## Git workflow

This is a solo project with no CI/PR process — commit and push directly to `main` as you work so nothing is ever sitting only in the local working tree.

- Commit at natural checkpoints (a working feature, a fixed bug, a completed refactor step) rather than batching many unrelated changes into one commit. Don't leave a session with uncommitted work.
- Write clean, descriptive commit messages that explain *what* changed and *why*, matching the style of existing history (see `git log`) — e.g. "8 games set registration allowed. Matches played counter corrected." rather than generic messages like "update" or "fix".
- After committing, push to GitHub (`git push`) so work is backed up remotely, not just committed locally.
- Still follow standard git safety practices: review `git status`/`git diff` before committing, never force-push, and never commit files that look like secrets (though note `google-services.json`/`firebase_options.dart` are intentionally tracked here — see Firebase config below).

## Architecture

### Client structure (`lib/`)

- `main.dart` — app entry point and the root auth/routing gate. `AuthTest` (despite the name, this is the real root widget, not a test) listens to `FirebaseAuth.authStateChanges()` and drives the whole top-level flow:
  1. Not signed in → custom-painted Google Sign-In landing screen.
  2. Signed in → `ensureUserDocument()` creates/repairs the Firestore `users/{uid}` doc without ever overwriting fields already set by `CompleteProfileScreen` (only fills genuinely-missing fields; merge writes only).
  3. Streams the user doc; if profile fields (`tennisLevel`, `birthDate`, `city`, `country`) are incomplete → `CompleteProfileScreen`, else → `HomeScreen`.
  - Also owns FCM setup (`setupFCM`/`saveFcmToken`, storing tokens in `users/{uid}.fcmTokens` as a map of token→true so multiple devices are supported) and notification tap routing (`handleNotificationTap` dispatches by `data.type`: `match_reminder`, `match_request`, or default chat/match-accepted → chat screen).
  - Also owns the **presence heartbeat**: `_AuthTestState` mixes in `WidgetsBindingObserver` and writes `users/{uid}.lastActive` (server timestamp, merge write) every 45s while signed in and foregrounded, starting on login/resume and stopping on logout/pause/detached. Other screens derive "online now" from `now - lastActive < 2 minutes` — no separate online/offline boolean or extra listener needed, since it self-expires.
- `screens/` — one file per screen, all fairly large (300–1200 lines) StatefulWidgets that talk directly to `FirebaseFirestore.instance` / `FirebaseAuth.instance` inline (no repository/DAO layer, no state-management framework beyond `provider` for theme). Firestore reads are mostly `StreamBuilder`/`FutureBuilder` wired straight into `build()`.
  - `available_players_screen.dart` — also renders the online-presence dot (green, bottom-right of the avatar) from `lastActive`, and groups/filters players by city.
  - `complete_profile_screen.dart` / `edit_profile_screen.dart` — both save `city` via a display-safe formatter (trim + capitalize first letter only, preserving accents/rest of casing as typed) rather than destroying it. Both also independently render the tennis-level dropdown and availability-day chips through localized strings (`loc.levelBeginner`/etc., a local `_translateDay` helper) — these two screens duplicate this logic rather than sharing it, so a fix/feature added to one (e.g. localization, city formatting) needs to be mirrored in the other by hand.
  - `complete_profile_screen.dart` — also runs the **guest match claim mechanic** (`_claimGuestMatches`, via a `phoneIndex/{phone}/matches` lookup) before the profile write on first login: for each unclaimed guest match matching the new user's phone, it adds them to `players`, sets `guestOpponent.claimedBy`, writes a flipped `claimantResult`, credits their `matchesPlayed`/`wins`/`losses`/`totalDuration` directly (client-side, not via Cloud Function — the only place stats are written outside `applyMatchStats`), and refreshes head-to-head against each claimed match's creator via `H2HService`.
  - `match_history_screen.dart` — for `type: 'guest'` matches, winner/loss perspective (narrative text, trophy, win/loss filter) must be derived by comparing `winnerUid` against `createdBy`, never against the currently-viewing user's UID directly — `winnerUid` is the creator's real UID when the creator won, or `'guest'` when the guest opponent won (that placeholder is set at creation, before the guest has an account, and is never updated afterward). Comparing it to the *viewer's* UID instead of `createdBy` silently flips the result when the claimant views their own history.
- `services/` — small stateless helpers, not a full data layer:
  - `theme_service.dart` — `TennisTheme` (Grand Slam–inspired named color themes, e.g. `fr`/`eng` get bespoke button colors) + `ThemeNotifier` (`ChangeNotifier`, persisted via `shared_preferences`, provided at the app root via `provider`).
  - `h2h_service.dart` — recomputes a user's head-to-head record against one opponent by re-querying all completed matches and writing an aggregate to `users/{uid}/headToHead/{opponentId}`. Called after match completion flows and after the guest-match claim mechanic; it's a full recompute, not an incremental update. Same `winnerUid == 'guest'` placeholder handling as `match_history_screen.dart` applies here — attribute the win via `createdBy`, not a direct UID comparison.
- `widgets/` — small shared presentational widgets (`match_card`, `home_card`, `empty_state`, `error_state`, `set_score_row`).
- `l10n/` (source `.arb` files) and `gen_l10n/` (generated — do not hand-edit, run `flutter gen-l10n`). Supported locales: `en`, `es`. Screens use `AppLocalizations.of(context)!`. Cloud Functions duplicate a parallel set of localized notification strings (`functions/index.js`, the `strings` object) since functions can't import the Dart ARB files — when adding a new user-facing notification string, update both places.
- `utils/day_utils.dart` — day-of-week helpers for availability scheduling.
- `utils/city_utils.dart` — `formatCityDisplay()`, a display-time capitalize-first-letter formatter used everywhere a city name is shown (available players list/header, player profile, my profile). Safe no-op on already-correct values; exists mainly so legacy city values saved before the profile-save fix (lowercase/accent-stripped) still render correctly without requiring every user to re-save their profile.

### Data model (Firestore, see `firestore.rules` for authoritative shape)

- `users/{uid}` — profile (`name`, `tennisLevel`, `availability`, `birthDate`, `age`, `city`, `country`, `countryCode`, `photoUrl`, `phoneNumber`, `fcmTokens`, `locale`, `uid`, `email`, `createdAt`, `lastActive`) and stats (`matchesPlayed`, `wins`, `losses`, `totalDuration`) as two disjoint field groups — security rules only allow updating one group or the other in a single write, never mixed. Stats fields are written by Cloud Functions (`applyMatchStats`) for normal match completion, **and also directly by the client** in the guest-match claim mechanic (`complete_profile_screen.dart` — the claim isn't a `status` transition, so it can't rely on `applyMatchStats`' triggers, and the security rules do permit the owner to write these fields directly under the same "stats fields" case). `lastActive` is the presence-heartbeat timestamp (see `main.dart` above), grouped with the profile fields.
  - `users/{uid}/headToHead/{opponentId}` — per-opponent aggregate written by `H2HService`.
- `match_requests/{id}` — `fromUid`/`toUid`/`status` (`pending`→`accepted`|`rejected`|`cancelled`, auto-`expired` after 2 days via scheduled function). Only the recipient can accept/reject; only the sender can cancel.
- `phoneIndex/{phone}/matches/{matchId}` — lookup index keyed by phone number, used so a newly-registered user can find unclaimed guest matches logged against their number without needing broader query permissions on `matches`.
- `matches/{id}` — the central document, shape varies by `type`:
  - Regular 1v1: `players: [uid1, uid2]`, `player1Uid`/`player2Uid`, `status` (`pending`→`confirmed`→`completed`, or `cancelled`).
  - `type: 'guest'`: single registered player (`players.size() == 1`) logging a match against an unregistered opponent (`guestOpponent`, matched by phone number); can later be "claimed" by the guest if they sign up (rules allow updating `guestOpponent`/`players`/`claimantResult` while `guestOpponent.claimedBy == null`). `winnerUid` is the creator's real UID if they won, or the literal string `'guest'` if the (then-unregistered) opponent won — see the `match_history_screen.dart`/`h2h_service.dart` notes above for why this matters.
  - `type: 'doubles_guest'`: only the creator (`createdBy`) is a real account; partner/opponents are name strings, not UIDs.
  - `messages/{id}` subcollection — per-match chat; `activeChatUsers` map on the parent match suppresses push notifications while a user has the chat screen open; `deletionRequest` implements a mutual-consent delete flow (either participant proposes, both must have `seenBy` it, then the requester can delete once `status == 'accepted'`).
- Firestore composite indexes (`firestore.indexes.json`) are hand-maintained alongside the queries that need them — if you add a new compound `where`/`orderBy` query, add the matching index here.
- **`firestore.rules` can drift from what's actually live.** Rules have been hand-edited directly in the Firebase console at times, bypassing this file — before editing `firestore.rules` locally, diff it against the console's current rules (Firestore → Rules tab) rather than assuming the repo copy is authoritative, or a local edit + deploy can silently roll back console-only changes. Always deploy with `firebase deploy --only firestore:rules` after editing so the two stay in sync going forward.

### Cloud Functions (`functions/index.js`)

Single-file Node.js Cloud Functions v2 codebase, all Firestore-triggered or scheduled — no HTTP endpoints:

1. `onNewChatMessage` — push to the other match participant, suppressed if they're actively viewing the chat (`activeChatUsers`).
2. `onMatchRequestReceived` / `onMatchRequestAccepted` — push notifications on request lifecycle, localized via the recipient's stored `locale`.
3. `onMatchScheduleReminder` — runs every 30 min, pushes 24h and 1h reminders for `confirmed` matches with a `scheduledDate` in range.
4. `onMatchRequestExpiry` — runs daily, expires `pending` requests older than 2 days.
5. `onMatchCreatedCompleted` / `onMatchUpdatedCompleted` + shared `applyMatchStats()` — the *only* place stats fields (`matchesPlayed`/`wins`/`losses`/`totalDuration`) are written, symmetrically for both players, using the Admin SDK to bypass client security rules. Handles `regular`/`guest` (via `players` array + `winnerUid`) and `doubles_guest` (via `createdBy` + `winnerTeam`) differently.

All user-facing notification copy is duplicated per-locale in the `strings` object at the top of the file — follow that pattern (add a key to both `en` and `es`) rather than inlining new literal strings.

### Firebase config

- Single project: `tennismatch-3c79c` (see `firebase.json`, `.firebaserc`, `lib/firebase_options.dart`).
- `android/app/google-services.json` and `lib/firebase_options.dart` are environment/project config — despite being tracked in git in this repo, treat them as generated (via `flutterfire configure` / Firebase console) rather than hand-edited.
- Android `applicationId`/`namespace` is `com.tennismatch.app`; the Kotlin source lives under `android/app/src/main/kotlin/com/tennismatch/` (the app was migrated off the default `com.example.tennismatch` package — don't recreate files under the old `com/example/tennismatch` path).
