# AI Chat (Flutter)

Pretty, local-first AI chat client for **macOS** and **iOS** with OpenAI-compatible providers.

It supports provider detection, validated API setup, streaming replies, persistent conversations, usage analytics, exports, and safe internal logging.

---

## ✨ Highlights

- 🔌 OpenRouter + VSEGPT support (OpenAI-compatible API)
- 🔎 Automatic provider detection from API key prefix
- ✅ API key validation during onboarding
- 🔐 4-digit PIN lock with inactivity re-lock
- 💬 Multi-conversation local chat history (SQLite)
- ⚡ Streaming responses + stop generation
- 🔁 Regenerate assistant answer / edit last user message and resend
- 🧮 Token + cost statistics, response timings, provider/model breakdowns
- 📈 Statistics screens + graphs
- 💰 Account balance check
- 📤 Exports (conversation + statistics) in TXT / Markdown / JSON
- 🧾 Built-in app logs with metadata sanitization
- 🎨 Light/Dark/System theme mode

---

## 🧱 Tech Stack

- **Framework:** Flutter (Dart)
- **HTTP:** `http`
- **Storage:** `sqflite` / `sqflite_common_ffi` (desktop), `shared_preferences`, `flutter_secure_storage`
- **Charts:** `fl_chart`
- **Markdown UI:** `flutter_markdown`
- **Export/Share:** `file_selector`, `share_plus`

---

## 🗂 Project Structure

```text
lib/
  app/
    app.dart                 # App composition root (wiring controllers/services/screens)
    app_theme.dart           # Light/Dark themes

  core/
    errors/app_exception.dart
    utils/app_logger.dart    # Safe structured logging with redaction

  data/
    database/
      app_database.dart      # SQLite init, schema creation, migrations
      database_tables.dart   # Table + index SQL definitions
    repositories/
      chat_repository.dart
      stats_repository.dart
      logs_repository.dart
    services/
      secure_storage_service.dart
      settings_storage_service.dart

  features/
    chat/
      models/
      state/chat_controller.dart
      ui/
    providers/
      models/
      services/
        openai_compatible_client.dart
        provider_detector.dart
      state/model_catalog_controller.dart
    settings/
      state/
      ui/
    statistics/
      models/
      state/statistics_controller.dart
      ui/
    export/
      services/
        export_service.dart
        share_service.dart
    logs/
      models/
      ui/

main.dart                    # Entry point
```

---

## 🏛 Architecture Overview

The app follows a simple layered architecture with feature modules:

1. **UI Layer** (`features/**/ui`)
   - Screens/widgets render state and call controller actions.

2. **State/Controller Layer** (`features/**/state`)
   - `ChangeNotifier` controllers contain app logic and orchestrate workflows.
   - Examples: chat send/regenerate, settings validation, statistics loading.

3. **Data Layer** (`data/repositories`, `data/services`)
   - Repositories encapsulate SQLite operations.
   - Services handle secure/local settings and platform export behaviors.

4. **Integration Layer** (`features/providers/services`)
   - OpenAI-compatible HTTP client for models, chat completions, streaming, and balance.

5. **Cross-cutting Core** (`core/`)
   - Shared exceptions + sanitized logging.

### Composition Root

`lib/app/app.dart` wires everything together:

- `AppDatabase`
- `ChatRepository`, `StatsRepository`, `LogsRepository`
- `OpenAICompatibleClient`
- `SettingsController`, `ModelCatalogController`, `ChatController`, `StatisticsController`
- `ExportService`, `ShareService`, `AppLogger`

This keeps dependency creation centralized and explicit.

---

## 🧠 Core Components & Functions

### `SettingsController`

- Loads/saves `AppSettings`
- Saves API key and detects provider by prefix
- Validates API key via provider-specific checks
- Manages PIN setup/unlock/reset and lock state
- Updates model parameters, theme, locale, system prompt, logging options
- Provides effective provider config (including custom base URL overrides)

### `ChatController`

- Loads and selects conversations
- Creates new conversations (with default provider/model when available)
- Sends user messages and requests assistant completions
- Supports streaming responses and manual stop
- Supports:
  - regenerate last assistant message
  - edit last user message + resend
- Persists messages + usage records
- Tracks UI state (`isLoading`, `isSending`, `isStreaming`, errors)

### `ModelCatalogController`

- Loads available models from the current provider
- Sorts/searches model catalog
- Handles selected model persistence via settings

### `StatisticsController`

- Loads usage records and computes aggregates:
  - total requests/tokens/cost
  - model/provider breakdown
  - average response time
  - error count
- Fetches account balance from active provider

### `OpenAICompatibleClient`

- Fetch models (`/models`)
- Create chat completion (`/chat/completions`)
- Create streaming completion (SSE)
- Validate API key (provider-specific flow)
- Fetch account balance (`/credits` or `/balance`)
- Normalizes provider differences and throws `AppException` on failures

### `AppLogger`

- Writes logs to SQLite
- Supports `info` / `warning` / `error`
- Redacts sensitive fields (tokens, auth, API keys)
- Optionally includes message snippets based on settings

---

## 🗃 Data Model (SQLite)

Defined in `lib/data/database/database_tables.dart`:

- `conversations`
- `messages`
- `usage_records`
- `logs`

Indexes are included for message order, usage analytics, and log retrieval.

---

## 🔌 Supported Providers

| Provider | API key prefix | Default base URL | Default model |
|---|---|---|---|
| OpenRouter | `sk-or-v1-` | `https://openrouter.ai/api/v1` | `openrouter/free` |
| VSEGPT | `sk-or-vv-` | `https://api.vsegpt.ru/v1` | `openai/gpt-3.5-turbo` |

> VSEGPT behavior can depend on account balance/subscription state.

---

## 🔐 Security & Local Data

- API key and PIN:
  - iOS/Android → `flutter_secure_storage`
  - Desktop fallback → `shared_preferences`
- Settings: `shared_preferences`
- Chats/statistics/logs: local SQLite database
- Logs are sanitized to avoid leaking sensitive auth data

---

## 🚀 Quick Start

```bash
flutter doctor
flutter create .
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

Run on iOS:

```bash
flutter devices
flutter run -d ios
```

---

## 🏗 Build

```bash
flutter build macos
flutter build ios
```

For full setup/troubleshooting, see **[BUILD.md](BUILD.md)**.

---

## 🍎 Platform Notes

### macOS entitlements

Required for API/network calls:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

Required for Save As export dialog:

```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

Do **not** add `keychain-access-groups` unless fully configured in Xcode signing setup.

### iOS keychain behavior

iOS may retain secure values across reinstall during development. If old credentials reappear, use in-app reset flow or change bundle identifier for clean testing.

---

## 🧪 Testing

Project includes unit/widget tests for controllers, provider detection, API client behavior, export services, logging, and UI interactions.

```bash
flutter test
```

---

## ✅ Current Status

- Primary targets: **macOS** and **iOS**
- Other platforms may need extra testing and platform-specific setup

## 🔜 AI Chat v2 - Roadmap
- Add localization infrastructure
- Start new conversation with context from other chat
- In-bubble message edit
- Search across conversations
- Pin favorite conversations
- Rename conversations
- Bluk delete/export
- Prompt preset library
- Token estimate before send
- Files and attachments
- Improved statistics
- Improved graphs
- Improved security
- Pretty UI
