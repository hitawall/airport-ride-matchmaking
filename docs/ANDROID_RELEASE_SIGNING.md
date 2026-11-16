# Android release signing

Google Play wants an app bundle signed with an **upload key** that only you hold (Play App Signing then re-signs it with Google's key). This is a one-time setup you do yourself; the repo is ready for it.

## 1. Create the upload keystore (once)

Run this on your PC (needs a JDK; Android Studio ships one). Pick strong passwords and keep them.

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Back the `.jks` file and both passwords up in a password manager **and** an offline copy. If you lose the upload key you must ask Google Play support to reset it. Never commit it (`*.jks` and `key.properties` are git-ignored).

## 2. Local release builds

Create `apps/mobile/android/key.properties` (git-ignored):

```properties
storeFile=../upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

and put `upload-keystore.jks` in `apps/mobile/android/`. Then:

```bash
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.airpool.online --dart-define=PUSHER_KEY=b7a8d59d5416afc1e718 --dart-define=PUSHER_CLUSTER=ap2
```

Without `key.properties` the build falls back to the **debug** key and prints a warning. That is fine for `flutter run --release` on your own phone, but such a bundle must never be uploaded to Play.

## 3. CI builds (optional, recommended)

Add four repository secrets (GitHub, Settings, Secrets and variables, Actions):

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the `.jks` file encoded as base64 (`base64 -w0 upload-keystore.jks`, or PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))`) |
| `ANDROID_KEYSTORE_PASSWORD` | the store password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password |

With the secrets set, every push to `main` builds a bundle signed with your upload key and keeps it as the `app-release-aab` workflow artifact for 14 days. Without them, CI still builds the bundle (signed with a throwaway key to exercise the signing path) and fails if it ever ends up debug-signed.

## 4. Play Console

Create the app, choose **Play App Signing** when uploading the first bundle, and upload `app-release.aab`. Increase the number after `+` in `pubspec.yaml` (`version: 1.0.0+N`) for every upload.
