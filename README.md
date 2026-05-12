# AI Chat

AI Chat is a Flutter client for chatting with OpenAI-compatible providers (currently OpenRouter and VSEGPT), with local conversation history, usage statistics, export, and PIN-protected API-key controls.

## Features

- Provider detection from API key prefix
- Initial setup flow with API key validation
- PIN setup/unlock gate
- Multi-chat conversations with fixed per-conversation model/provider
- Message editing and regenerate flows
- Usage statistics (totals, by-model, by-provider, recent records)
- Account balance checks
- Export:
  - Conversations: TXT / Markdown / JSON
  - Statistics: TXT / Markdown / JSON
  - Logs: JSON
- Full reset app data flow (PIN + strong confirmation)

## Supported providers

- **OpenRouter**
  - Default model for new chats: `openrouter/free`
- **VSEGPT**
  - Default model for new chats: `openai/gpt-3.5-turbo`

## Project setup

```bash
flutter pub get
```

## Run

### macOS

```bash
flutter run -d macos
```

### iOS (simulator)

```bash
flutter run -d ios
```

## Build

### macOS release

```bash
flutter build macos --release
```

### iOS release

```bash
flutter build ios --release
```

## Validation / CI-style checks

```bash
dart format .
flutter analyze
flutter test
```

## macOS / iOS notes

### Secure storage behavior

- iOS uses `flutter_secure_storage`.
- macOS/Linux/Windows use `shared_preferences` fallback in this project.

### Entitlements

- `macos/Runner/DebugProfile.entitlements`:
  - app sandbox
  - network client
  - user-selected file read/write
- `macos/Runner/Release.entitlements`:
  - app sandbox
  - user-selected file read/write

> If release builds need remote API calls on macOS sandbox, ensure the release entitlements include the required network client capability for your distribution model.

## Export behavior

- Desktop: system Save As flow (`file_selector`)
- iOS: native share sheet (`share_plus`)

No API key or PIN values are included in statistics export payloads.

## Troubleshooting

- **Provider not detected**
  - Check API key prefix format.
- **Validation failed**
  - Verify key and provider availability.
- **Balance unavailable**
  - Check provider endpoint/credits API and network access.
- **No file created on desktop export**
  - Confirm Save As dialog was completed (not canceled).
- **PIN lock issues**
  - Use reset flows in unlock/settings screens as intended.

## Release prep notes

- Visible app name is configured as **AI Chat** in Flutter and Apple platform metadata.
- `.gitignore` includes Flutter build/ephemeral and CocoaPods user-data paths.
- **TODO (manual, if required by release process):** update bundle identifiers and signing metadata for your organization before store/distribution submission.
