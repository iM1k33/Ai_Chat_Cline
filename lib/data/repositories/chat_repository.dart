import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/database/database_tables.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:sqflite/sqflite.dart';

class ChatRepository {
  const ChatRepository({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<void> upsertConversation(Conversation conversation) async {
    final Database db = await _appDatabase.database;

    await db.insert(
      DatabaseTables.conversations,
      _conversationToMap(conversation),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Conversation>> getConversations() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.conversations,
      orderBy: 'updated_at DESC',
    );

    return rows.map(_conversationFromMap).toList();
  }

  Future<Conversation?> getConversationById(String id) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.conversations,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return _conversationFromMap(rows.first);
  }

  Future<void> deleteConversation(String id) async {
    final Database db = await _appDatabase.database;

    await db.transaction((txn) async {
      await txn.delete(
        DatabaseTables.messages,
        where: 'conversation_id = ?',
        whereArgs: <Object?>[id],
      );

      await txn.delete(
        DatabaseTables.conversations,
        where: 'id = ?',
        whereArgs: <Object?>[id],
      );
    });
  }

  Future<void> deleteAllConversations() async {
    final Database db = await _appDatabase.database;

    await db.transaction((txn) async {
      await txn.delete(DatabaseTables.messages);
      await txn.delete(DatabaseTables.conversations);
    });
  }

  Future<void> insertMessage(ChatMessage message) async {
    final Database db = await _appDatabase.database;

    await db.insert(
      DatabaseTables.messages,
      _messageToMap(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.messages,
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'created_at ASC',
    );

    return rows.map(_messageFromMap).toList();
  }

  Future<void> deleteMessagesForConversation(String conversationId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseTables.messages,
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final Database db = await _appDatabase.database;
    await db.delete(
      DatabaseTables.messages,
      where: 'id = ?',
      whereArgs: <Object?>[messageId],
    );
  }

  Map<String, Object?> _conversationToMap(Conversation conversation) {
    return <String, Object?>{
      'id': conversation.id,
      'title': conversation.title,
      'created_at': conversation.createdAt.toIso8601String(),
      'updated_at': conversation.updatedAt.toIso8601String(),
      'selected_model_id': conversation.selectedModelId,
      'provider_id': conversation.providerId,
      'system_prompt': conversation.systemPrompt,
      'is_pinned': conversation.isPinned ? 1 : 0,
    };
  }

  Conversation _conversationFromMap(Map<String, Object?> map) {
    return Conversation(
      id: map['id'] as String,
      title: map['title'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      selectedModelId: map['selected_model_id'] as String?,
      providerId: map['provider_id'] as String?,
      systemPrompt: map['system_prompt'] as String?,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
    );
  }

  Map<String, Object?> _messageToMap(ChatMessage message) {
    return <String, Object?>{
      'id': message.id,
      'conversation_id': message.conversationId,
      'role': ChatMessage.roleToString(message.role),
      'content': message.content,
      'created_at': message.createdAt.toIso8601String(),
      'model_id': message.modelId,
      'provider_id': message.providerId,
      'prompt_tokens': message.promptTokens,
      'completion_tokens': message.completionTokens,
      'total_tokens': message.totalTokens,
      'estimated_cost': message.estimatedCost,
      'error': message.error,
    };
  }

  ChatMessage _messageFromMap(Map<String, Object?> map) {
    return ChatMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      role: ChatMessage.roleFromString(map['role'] as String),
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      modelId: map['model_id'] as String?,
      providerId: map['provider_id'] as String?,
      promptTokens: map['prompt_tokens'] as int?,
      completionTokens: map['completion_tokens'] as int?,
      totalTokens: map['total_tokens'] as int?,
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble(),
      error: map['error'] as String?,
    );
  }
}
