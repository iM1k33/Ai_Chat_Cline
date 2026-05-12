# Build Guide

This document describes how to run and build the Flutter AI Chat app.

## Requirements

Install Flutter and Xcode before building.

Check Flutter:

```bash
flutter doctor
```

Recommended workflow:

```bash
flutter clean
flutter create .
flutter pub get
flutter analyze
flutter test
```

## Run on macOS

```bash
flutter run -d macos
```

## Run on iOS

List devices:

```bash
flutter devices
```

Run:

```bash
flutter run -d ios
```

If using a physical iPhone, make sure Xcode signing is configured.

## Build macOS

```bash
flutter build macos
```

Output is usually under:

```text
build/macos/Build/Products/Release/
```

## Build iOS

```bash
flutter build ios
```

For App Store/TestFlight distribution, archive from Xcode after configuring signing.

Open workspace:

```bash
open ios/Runner.xcworkspace
```

## macOS Entitlements

Check:

```text
macos/Runner/DebugProfile.entitlements
macos/Runner/Release.entitlements
```

Required for network requests:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Required for Save As export:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Typical debug entitlements:

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

Typical release entitlements:

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
</dict>
```

## Launcher Icons

If using `flutter_launcher_icons`, keep only enabled platforms that exist in the project.

Example for iOS + macOS only:

```yaml
flutter_launcher_icons:
  android: false
  ios: true
  macos:
    generate: true
  image_path: "assets/icon/app_icon.png"
  remove_alpha_ios: true
```

Generate icons:

```bash
dart run flutter_launcher_icons
```

If the project has no Android folder, keep `android: false`.

## Clean Local App Data During Development

macOS sandbox container may be under:

```text
~/Library/Containers/<bundle-id>/
```

For example:

```bash
rm -rf ~/Library/Containers/com.sunr1s3.ai-chat
```

iOS secure values may remain in Keychain after uninstall. Prefer the in-app reset flow for clean testing.

## Common Errors

### `Code Signature Invalid`

Usually caused by invalid macOS entitlements/signing. Remove incorrect `keychain-access-groups` unless fully configured in Xcode.

### API requests fail on macOS

Add:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Export save dialog fails on macOS

Add:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### `PathNotFoundException: AndroidManifest.xml`

If generating launcher icons and the project has no Android platform folder, set:

```yaml
android: false
```

### iOS old API key after reinstall

This can happen because Keychain persists across reinstall. Use in-app reset or change bundle identifier during testing.
