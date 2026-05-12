# AI Chat

A personal cross-platform AI chat client built with Flutter.

The app is designed for macOS and iOS first, with support for OpenAI-compatible API providers through OpenRouter and VSEGPT.

## Features

- OpenRouter and VSEGPT support
- First-launch API key setup
- Automatic provider detection from API key prefix
- Editable `BASE_URL`
- API key validation
- 4-digit PIN lock
- API key reveal protected by PIN
- Multiple saved conversations
- Fixed model per conversation
- Default model for new chats
- Streaming responses
- Stop generation
- Regenerate last assistant response
- Edit last user message and resend
- Local SQLite chat history
- Markdown rendering
- Code block copy
- Whole-message copy
- Token/cost statistics
- Usage graphs
- Provider balance display
- Conversation export: TXT, Markdown, JSON
- Statistics export: TXT, Markdown, JSON
- Logs screen with safe logging
- macOS Save As dialog for exports
- iOS Share Sheet for exports
- Light/dark theme support

## Tested Platforms

- macOS
- iOS

Android/Windows support may require additional testing and platform setup.

## Providers

### OpenRouter

API key prefix:

```text
sk-or-v1-
```

Default base URL:

```text
https://openrouter.ai/api/v1
```

Default model after first setup:

```text
openrouter/free
```

### VSEGPT

API key prefix:

```text
sk-or-vv-
```

Default base URL:

```text
https://api.vsegpt.ru/v1
```

Default model after first setup:

```text
openai/gpt-3.5-turbo
```

VSEGPT behavior may depend on active balance/subscription status.

## Local Data

The app stores data locally:

- API key / PIN: secure storage where available, desktop fallback where configured
- Settings: local app storage
- Conversations/messages: SQLite
- Statistics: SQLite
- Logs: SQLite
- Exports: user-selected location on macOS, Share Sheet on iOS

No API keys or PIN codes should be committed to Git.

## macOS Entitlements

The macOS app needs these entitlements:

```xml
<key>com.apple.security.network.client</key>
<true/>

<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

`network.client` is required for outgoing API requests.

`files.user-selected.read-write` is required for macOS Save As export dialogs.

Do not add `keychain-access-groups` manually unless you fully configure signing/keychain sharing in Xcode. Incorrect keychain entitlements can cause Code Signature Invalid crashes.

## iOS Notes

iOS Keychain can preserve secure values after app uninstall/reinstall during development. If an old API key appears after reinstall, use the in-app reset flow or change the bundle identifier for a fresh test namespace.

Exports on iOS use the native Share Sheet.

## Quick Start

```bash
flutter pub get
flutter run -d macos
```

For iOS:

```bash
flutter devices
flutter run -d ios
```

## Build

macOS:

```bash
flutter build macos
```

iOS:

```bash
flutter build ios
```

See [BUILD.md](BUILD.md) for more detailed setup and troubleshooting.

## Troubleshooting

### macOS: Code Signature Invalid

If the app crashes with:

```text
Taskgated Invalid Signature
Code Signature Invalid
```

Check macOS entitlements. Remove incorrectly added `keychain-access-groups` unless properly configured.

### macOS: API request fails

Make sure this entitlement exists:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### macOS: export dialog does not open or cannot save

Make sure this entitlement exists:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### iOS: old API key appears after reinstall

iOS Keychain may preserve secure values after uninstall. Use in-app reset or change bundle identifier for clean testing.

### Shift+Enter behavior on macOS

Expected behavior:

- `Enter` sends message
- `Shift+Enter` inserts a new line

## Release TODO

- Final app icon
- Final app display name
- Bundle identifier cleanup
- Full VSEGPT production testing
- UI polish pass
- Localization
- Better release signing/notarization
