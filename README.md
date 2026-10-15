# Euro Football Manager

Offline European football manager (Flutter + Drift/SQLite). All gameplay runs on-device.

## Get the APK (GitHub Actions, recommended)
1. Push to `main` (or Actions → *Build APK* → *Run workflow*).
2. Download from the run's **euro-manager-apk** artifact, or from the repo's **Releases** page (`build-N`, file `app-release.apk`).
3. Send the APK to friends. They enable *Install unknown apps* for their browser/file manager and open it.

### Keep updates installable over the old version (stable signing key)
Android only updates an app if every build is signed with the same key.
1. Generate once:
   ```
   keytool -genkey -v -keystore debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
   base64 -w0 debug.keystore
   ```
   (macOS: `base64 -i debug.keystore`)
2. Repo → Settings → Secrets and variables → Actions → new secret `DEBUG_KEYSTORE_B64` = the base64 output.
3. Keep `debug.keystore` backed up. Never commit it.

Each build gets a higher version code (`--build-number=<run number>`), so updates install over the top and saves are kept (the database migrates automatically).

## Build locally
```
flutter create --platforms=android --project-name euro_manager --org com.gad .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release --target-platform android-arm64
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. (`android/` is generated and git-ignored.)
For older 32-bit phones drop `--target-platform`, or add `--split-per-abi`.

## iOS
Needs a Mac/Apple developer account. Run `flutter create --platforms=ios .` then build with Xcode, or use Codemagic with the same pub get / build_runner steps and `flutter build ipa`.

## Web build
*Deploy Web* workflow publishes to GitHub Pages (Settings → Pages → Source: GitHub Actions).

## Notes
- Save data is a local SQLite database; uninstalling the app deletes it.
- Railway is not needed for play.
