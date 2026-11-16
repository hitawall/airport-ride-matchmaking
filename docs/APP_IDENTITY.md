# App identity: name, package id and icon

Current state (everything below is a working draft until the owner decides):

| Thing | Current value | Where it lives |
|---|---|---|
| Launcher label (under the icon) | `Airport Rides` | `apps/mobile/android/app/src/main/res/values/strings.xml`, `ios/Runner/Info.plist` (`CFBundleDisplayName`, `CFBundleName`) |
| Name inside the app and legal pages | `Airport Ride Matchmaking` | `APP_NAME` build setting (GitHub repo variable), default in `lib/core/app_config.dart` |
| Play Store title (30 chars max) | not set | Play Console listing |
| Android package id | `com.airportridematchmaking.mobile` | `android/app/build.gradle.kts` (`applicationId` and `namespace`) |
| iOS bundle id | not chosen yet | `ios/Runner.xcodeproj` (later) |
| Launcher icon | draft drawn from the in-app road, sun and plane scene | `assets/icon/` |
| Splash | brand cream background (plus launcher icon on Android 12+) | `res/values/colors.xml`, `res/values-v31/styles.xml` |

## Owner decisions

1. **Final app name** (and a short launcher label, about 12 characters).
2. **Package id** - **permanent after the first Play upload**. Ideally the reverse of the domain from issue #46, e.g. `com.yourdomain.airportrides`. If you keep the current one, nothing to do. To change it before publishing: edit `applicationId` and `namespace` in `build.gradle.kts`, move `android/app/src/main/kotlin/<old path>/MainActivity.kt` to the matching folder and update its `package` line.
3. **Icon**: keep the draft or supply designer artwork.

## Changing the icon

- Keep the draft but tweak it: edit `apps/mobile/tool/generate_icons_test.dart`, then
  ```bash
  cd apps/mobile
  flutter test tool/generate_icons_test.dart
  dart run flutter_launcher_icons
  ```
  (If `git status` then shows a changed `ios/Runner.xcodeproj/project.pbxproj`, revert that file: the tool wrongly edits it.)
- Use designer artwork: replace `assets/icon/icon.png` (1024x1024, square, no transparency),
  `icon_background.png` and `icon_foreground.png` (1024x1024; the foreground is shown 16% inset), then run the second command only.

## Store graphics (still to make)

- `assets/icon/store_icon_512.png` is ready (512x512 Play Store icon, regenerate from the same script).
- **Feature graphic 1024x500** and **2-8 phone screenshots**: needed for the Play listing. Screenshots are best taken from the real app on a phone once the final name and data are in; the feature graphic can reuse the scene art.
