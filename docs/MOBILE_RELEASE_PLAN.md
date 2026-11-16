# Plan: ship Airport Ride Matchmaking as a real Android app (iOS later)

Status: planned, not started. Implement after the current bug-hunting is done. Last updated 2026-11-16.

Decisions: **Android first, iOS later** (deferred by choice; the owner has a Mac); **individual** developer accounts to start, with a possible later switch to a company (see Part 5).

The same Flutter code builds for Android and iOS, so this is mostly packaging, release setup and store compliance, not a rewrite.

## What the repo and the dev PC already have

| Area | Finding |
|---|---|
| Native projects | `apps/mobile/android` and `apps/mobile/ios` already exist (Flutter scaffolds). |
| Android ID | `applicationId = "com.airportridematchmaking.mobile"` in `android/app/build.gradle.kts`. It can **never change after publishing**, so decide the final one first. |
| Release signing | Release builds are signed with the **debug key** (a TODO in the same file). Play rejects that. |
| App name / icon | Label is still `mobile` (`AndroidManifest.xml`), iOS name `Mobile`; icons are the Flutter defaults. |
| Permissions | **`INTERNET` is only in the debug and profile manifests.** A release build from the current main manifest would have no network. Camera (scanner) and photo access need declaring and verifying. |
| iOS strings | `Info.plist` has no camera or photo-library usage descriptions (scanning would crash). No `Podfile` yet (generated on the first Mac build). |
| Build-time config | `apiBaseUrl`, `PUSHER_KEY`, `PUSHER_CLUSTER` come from `--dart-define`. CI already passes the production values for web (`.github/workflows/ci.yml`). |
| Login | OTP email through Resend; `OTP_TEST_MODE` turns on the fixed code `000000`. Production needs real email delivery and test mode off. |
| Account deletion | **Does not exist.** Both stores require it for apps with sign-up. |
| Safety / UGC | Report, block and unmatch exist (helps with both stores' user-generated-content rules). |
| Dev PC | Flutter 3.50.0 stable at `C:\flutter` (not on PATH). **No Android SDK**, no Java, no Visual Studio, no Mac. |
| CI | Runs web build and deploy; no Android build job yet. |

## Part 1: things to start now (no code, run in parallel)

Longest first.

1. **Create a Google Play Developer account** (Play Console). Identity verification can take days. Usually a one-time $25; confirm on sign-up.
2. **Line up 12+ closed testers** (people with Gmail accounts and Android phones). Google's help page says personal accounts created after Nov 2023 must run a closed test with at least 12 testers opted in continuously for 14 days before production access. This is the longest wait, and the clock only starts once the app is in closed testing, so collect the addresses now.
3. **Pick the final app identity**: display name, store name, and the reverse-domain application ID. If the custom domain (issue #46) is bought, choose an ID that matches it, because the ID is permanent.
4. **Install Android Studio** (bundles the SDK and a JDK), add `C:\flutter\bin` to PATH, and run `flutter doctor` until the Android toolchain is green. Side benefit: run the app on a real phone or emulator now and find mobile-only bugs during bug-hunting.
5. **Write a privacy policy and terms of service**, and choose a support email. Both stores need a public privacy policy URL. The app collects: email, phone number, name, gender, profile photo, bio, chat messages, flight and destination details. No location, no ads, no payments.
6. **Prepare store listing assets**: 512x512 icon, 1024x500 feature graphic, 2 to 8 phone screenshots, short (80 chars) and full description.
7. **Production email**: verify a sending domain in Resend and confirm in Vercel that the production API has `RESEND_API_KEY` set and `OTP_TEST_MODE` is not `true`. Without this nobody outside testing can log in.
8. **(Optional, for later iOS)** Start Apple Developer Program enrollment early; individual enrollment can take days. Typically $99 per year; confirm on enrollment.

## Part 2: code and config work (later, one issue, branch and PR each)

1. **App identity**: display name in `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`; finalize `applicationId` / `namespace` in `android/app/build.gradle.kts`; app icons (adaptive on Android) and a native splash, likely `flutter_launcher_icons` and `flutter_native_splash` as dev dependencies, reusing the coral, plum and cream palette and the road and plane motif from `core/ui/horizon_scene.dart`.
2. **Android release manifest fixes**: add `<uses-permission android:name="android.permission.INTERNET"/>` to the **main** manifest; confirm `CAMERA` is merged from `mobile_scanner` and add `<uses-feature android:name="android.hardware.camera" android:required="false"/>`; set `android:allowBackup="false"` (or backup rules) so restored backups do not corrupt `flutter_secure_storage` tokens.
3. **Release signing**: generate an **upload keystore** and keep it and its passwords safe (password manager plus offline copy); add a git-ignored `android/key.properties` and a `signingConfigs.release` block replacing the debug signing; enrol in **Play App Signing**.
4. **Account deletion (required by both stores)**: an authenticated delete-account API endpoint that removes or anonymizes the user's data (deletion order: chat messages, reports, ratings, feedback, blocks, matches, ride requests, profile, OTP rows, user; recommended to keep the other person's chat copy and show the deleted user as "Deleted user"); a "Delete account" row in `features/settings/settings_screen.dart` using `confirmAction(... destructive: true)` from `core/ui/dialogs.dart`; and a public web page explaining how to request deletion without installing the app (Google asks for this URL in the Data safety form).
5. **Legal pages**: privacy policy and terms pages (web app routes), linked from Settings and the welcome screen (`features/onboarding/legal_interstitial_screen.dart`).
6. **Reviewer / demo login**: reviewers cannot read email, so add a tightly gated review account to the API (fixed code from a secret env var, one specific email only) and document it in the Play "App access" section. Off everywhere else.
7. **Build pipeline**: local `flutter build appbundle --release --dart-define=API_BASE_URL=https://airport-ride-matchmaking-api.vercel.app --dart-define=PUSHER_KEY=<key> --dart-define=PUSHER_CLUSTER=ap2` (same values as `ci.yml`); a CI Android job producing the signed AAB (keystore and passwords as GitHub secrets), optionally publishing to the Play internal track later; bump `version: 1.0.0+N` in `pubspec.yaml` on every upload (the number after `+` must increase).
8. **Real-device hardening pass**: scanner on a real camera, gallery photo upload, OTP email delivery, Pusher realtime versus polling fallback, keyboard and safe areas, rotation (consider locking to portrait), back-button behaviour with go_router, slow or offline network messages.
9. **After launch (not required for approval)**: push notifications for matches and messages (FCM), crash reporting (Crashlytics or Sentry), analytics.

## Part 3: Google Play path

1. Play Console: create the app; fill the store listing, category (Travel and Local suggested), contact email, privacy policy URL.
2. Policy forms: Content rating questionnaire; Data safety (collected data listed above, encrypted in transit, deletion supported, account deletion URL); Target audience (18+); Ads (none); App access (the review account); government, financial and health declarations (none).
3. Upload the AAB to **Internal testing** first (instant, up to 100 testers) to smoke-test a real install.
4. Promote to **Closed testing** with 12+ testers opted in for **14 continuous days**.
5. Apply for **production access**, then a **staged rollout** (for example 10 percent, 50, 100).
6. Target API: Google requires new apps and updates to target Android 16 (API 36) or higher (deadline was Aug 31, 2026). A current Flutter template should satisfy this; verify at the first build.

Rough timeline (estimate): account setup 1 to 7 days (parallel); code and config PRs about 1 to 2 weeks; closed test at least 14 days; Google review a few days. Earliest realistic production date is about 4 to 6 weeks after starting the account and tester steps.

## Part 4: iOS later (prerequisites)

- **Apple Developer Program** account (about $99 per year, confirm) and an App Store Connect app record.
- **A Mac is available**, so build locally with Xcode (no cloud CI needed). Builds must use **Xcode 26 or later with the iOS 26 SDK** (Apple requirement since Apr 28, 2026), so check the Mac's macOS version can run it. If the Mac is ever unavailable, cloud CI is the fallback: Codemagic's docs say a personal account gets 500 free macOS minutes per month (about $0.095 per extra minute).
- Signing: let Xcode manage signing with the Apple Developer account; keep an App Store Connect API key for any future CI upload.
- `Info.plist`: add `NSCameraUsageDescription` (scanner) and `NSPhotoLibraryUsageDescription`; run the first Mac build to generate the `Podfile`; confirm the iOS deployment target satisfies `mobile_scanner`.
- App Review: in-app **account deletion** (guideline 5.1.1(v), covered by Part 2.4), **user-generated-content** rules (report and block exist; also publish contact info and be ready to describe moderation), privacy "nutrition labels", a reviewer demo login (same as Part 2.6).
- **Sign in with Apple** becomes mandatory on iOS if Google sign-in (issue #43) is ever added.
- Flow: TestFlight internal, then external beta review, then App Review.

## Part 5: switching to a company account (optional, assumes India)

Figures come mostly from consultant blogs and Apple's help pages, not official MCA or Google sources. Re-check before acting.

| Step | Time | Cost |
|---|---|---|
| Incorporate a Private Limited (or LLP) via the MCA SPICe+ form | About 5 to 10 working days with clean paperwork | Roughly Rs 7,000 to Rs 25,000 all-in, mostly state stamp duty and digital signatures |
| Get a **D-U-N-S number** (both stores use it to verify a company) | Apple says up to 5 business days plus about 2 for it to reach Apple; one Indian studio reported weeks of silence, so allow up to a month | Free on the standard route |
| Developer accounts as an organization | Days after the D-U-N-S number exists | Same fees as individual (about $25 Google, about $99 per year Apple; not verified) |

- Realistic total: **3 to 6 weeks**, can run in parallel with bug-hunting. Add ongoing yearly company filing and accounting costs (no figures found).
- Apple does not accept sole proprietorships, DBAs or trade names as organizations; it needs a legal entity, a D-U-N-S number, a website, and someone with legal authority to sign.
- **Not locked in by starting as an individual.** Apple documents converting an individual account to an organization. For Google, sources conflict on converting the account versus creating a new organization account and transferring the app; confirm in Google's docs. The package ID stays the same either way.
- Trade-offs: an individual account shows your legal name as the seller and (per Google's help page) needs the 12-tester, 14-day closed test. Organization accounts reportedly skip that test (secondary sources only), but the D-U-N-S wait could easily exceed the 14 days saved.
- Suggested approach: if a company is genuinely planned, start incorporation now in parallel, and begin Play testing as an individual in the meantime.

## Verification (when implementing)

1. `flutter doctor` shows the Android toolchain green; `flutter run` works on a physical phone.
2. `flutter build apk --release` with the production dart-defines on a real device: network works (the INTERNET fix), OTP email arrives, login, photo upload, boarding-pass scan, swipe, chat, settings, delete account.
3. `flutter build appbundle --release` is signed with the upload key (check the Play Console upload result or `keytool -printcert -jarfile`).
4. Play Console internal-testing install on at least two device sizes; review the automatic pre-launch report for crashes and accessibility warnings.
5. After each store review step, check policy emails (Data safety mismatches and a missing deletion URL are common rejections).

## Open uncertainties

- Store fees ($25 Google, about $99 Apple) come from general knowledge, not checked in the planning session.
- Secondary sources say company accounts avoid Google's 12-tester rule; Google's own page states the rule for personal accounts. Not relevant while publishing as an individual.
- The first Android build on Flutter 3.50 may need Gradle or plugin version fixes; budget a little time.
