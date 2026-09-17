# TennisMatch — Google Play Release Guide

A repeatable checklist for pushing an update: beta (closed testing) first, then production. Keep this file updated if Google changes the Play Console UI.

---

## 0. Before you start

- [ ] All code changes committed and pushed to `main` (`git status` is clean).
- [ ] `flutter analyze` runs clean (no new warnings/errors).
- [ ] You've manually tested the changes on your phone and/or the emulator.
- [ ] Version bumped in `pubspec.yaml` — **both parts**:
  - `version: X.Y.Z+N` — bump `X.Y.Z` (semantic version, shown to users) and always increment `N` (the build number — Play Store rejects an upload whose build number isn't strictly higher than the last one, even if you didn't bump `X.Y.Z`).
  - Current version after this update: **1.3.5+10**.

## 1. Build the release App Bundle

From the repo root:

```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

The signed `.aab` file lands at:

```
build/app/outputs/bundle/release/app-release.aab
```

(`flutter build appbundle` automatically uses your configured signing key from `android/key.properties` / `android/app/build.gradle` — no separate Android Studio signing step needed.)

## 2. Upload to Closed Testing (beta) first

1. Go to [Google Play Console](https://play.google.com/console) → **TennisMatch** → **Testing** → **Closed testing** → your existing beta track.
2. Click **Create new release**.
3. Upload `app-release.aab`.
4. Under **Release notes**, paste the beta-facing notes (see § 4 below — can be the same as production, or more technical/detailed since it's just your testers).
5. Click **Next**, review the warnings/errors panel (Play Console flags things like missing permissions justifications — shouldn't come up for a routine update), then **Save** → **Review release** → **Start rollout to Closed testing**.
6. Let your beta testers know an update is available (they'll get it automatically if they've already opted in and have auto-update on, or they can check for updates manually in the Play Store app).

## 3. Let it sit in beta

- [ ] Give testers at least a day or two to actually open the app and hit the changed screens.
- [ ] Specifically re-test whatever this release fixed (see § 4 notes) — don't just check "it opens."
- [ ] Check **Play Console → Quality → Android vitals** for any new crashes/ANRs attributed to the new build number.

Only move to production once you're confident nothing regressed.

## 4. Promote to Production

1. In Play Console, go to **Testing → Closed testing**, open the release you just tested.
2. Click **Promote release → Production** (this carries over the same `.aab` — you don't re-upload anything).
   - Alternative: **Production → Create new release → Upload**, and pick the same `.aab` from your build output if you'd rather start a fresh production release instead of promoting.
3. Edit/confirm the **release notes** for production (see § 5 — usually simpler, user-facing language than the beta notes).
4. Choose a **rollout percentage**. For a small, mostly-Colombia user base, 100% immediately is reasonable — but a staged rollout (e.g. 20% → wait a day → 100%) costs nothing extra and gives you a cheap safety net if something slips through beta.
5. Click **Review release** → **Start rollout to Production**.
6. Status will show **"In review"** on the dashboard; Google's review is usually quick for an existing app with no policy-sensitive changes (a few hours to ~1 day).

## 5. After it's live

- [ ] Watch **Play Console → Quality → Android vitals** for the first few days.
- [ ] Watch the **Reviews** tab for any user-reported issues tied to the new version.
- [ ] Optional: tag the release in git for your own reference:
  ```bash
  git tag v1.3.5+10
  git push --tags
  ```

---

## Release notes — this update (v1.3.5+10)

Play Console lets you set release notes per language (matches the app's own `en`/`es` locales). Paste these into the **Release notes** field for both the closed-testing and production releases (500-character limit per language — both of these fit).

**English (en-US):**
```
Bug fixes and improvements:
• Fixed an issue where set scores could disappear while entering a match result with 3+ sets
• Clearer validation when completing your profile (date of birth / country)
• Country now defaults to Colombia when setting up your profile
• Player names now display with consistent capitalization
• Official match scoring is now limited to a maximum of 5 sets
• Phone number is no longer required to complete your profile
```

**Spanish (es-419 / es-CO):**
```
Correcciones y mejoras:
• Se corrigió un error que podía borrar los marcadores de los sets al registrar un resultado de 3 o más sets
• Mensajes más claros al completar tu perfil (fecha de nacimiento / país)
• El país ahora aparece como Colombia por defecto al configurar tu perfil
• Los nombres de los jugadores ahora se muestran con mayúsculas correctas
• El modo de puntuación Oficial ahora se limita a un máximo de 5 sets
• El número de teléfono ya no es obligatorio para completar tu perfil
```

---

## Template for next time

Copy this section, fill it in, and use it as your release notes source for the next update:

```
**English (en-US):**
[1-4 short bullet points, plain language, no internal file/function names]

**Spanish (es-419 / es-CO):**
[same content, translated]
```

Tips for writing these:
- Write for the *user*, not for future-you reading CLAUDE.md — no mentions of screen/file names, GlobalKeys, Firestore, etc.
- Lead with anything that fixes a real reported problem ("Fixed an issue where...") — users notice and appreciate that more than generic "improvements."
- Keep it to 3-5 bullets max; Play Store truncates long notes in some UI surfaces.
