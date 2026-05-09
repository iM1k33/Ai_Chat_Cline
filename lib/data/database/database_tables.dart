class DatabaseTables {
  const DatabaseTables._();

  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String usageRecords = 'usage_records';

  static const String createConversationsTable =
      '''
CREATE TABLE $conversations (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  selected_model_id TEXT,
  provider_id TEXT,
  system_prompt TEXT,
  is_pinned INTEGER NOT NULL DEFAULT 0
)
''';

  static const String createMessagesTable =
      '''
CREATE TABLE $messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  model_id TEXT,
  provider_id TEXT,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  total_tokens INTEGER,
  estimated_cost REAL,
  error TEXT
)
''';

  static const String createUsageRecordsTable =
      '''
CREATE TABLE $usageRecords (
  id TEXT PRIMARY KEY,
  conversation_id TEXT,
  message_id TEXT,
  provider_id TEXT NOT NULL,
  model_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  prompt_tokens INTEGER NOT NULL DEFAULT 0,
  completion_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,
  estimated_cost REAL NOT NULL DEFAULT 0,
  currency_code TEXT NOT NULL,
  response_time_ms INTEGER,
  error TEXT
)
''';

  static const String createMessagesConversationCreatedIndex =
      '''
CREATE INDEX messages_conversation_created_idx
ON $messages(conversation_id, created_at)
''';

  static const String createUsageProviderModelCreatedIndex =
      '''
CREATE INDEX usage_provider_model_created_idx
ON $usageRecords(provider_id, model_id, created_at)
''';

  static const String createUsageConversationCreatedIndex =
      '''
CREATE INDEX usage_conversation_created_idx
ON $usageRecords(conversation_id, created_at)
''';
}
