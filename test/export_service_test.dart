import 'dart:convert';

import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Conversation conversation = Conversation(
    id: 'c1',
    title: 'My Export Chat / Unsafe?* Title',
    createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
    updatedAt: DateTime.parse('2026-01-01T11:00:00Z'),
  );

  final List<ChatMessage> messages = <ChatMessage>[
    ChatMessage(
      id: 'm1',
      conversationId: 'c1',
      role: ChatMessageRole.user,
      content: 'Hello there',
      createdAt: DateTime.parse('2026-01-01T10:01:00Z'),
    ),
    ChatMessage(
      id: 'm2',
      conversationId: 'c1',
      role: ChatMessageRole.assistant,
      content: 'Hi! How can I help?',
      createdAt: DateTime.parse('2026-01-01T10:01:05Z'),
    ),
  ];

  const ExportService exportService = ExportService();

  test('TXT export contains title and message content', () {
    final String txt = exportService.buildConversationExport(
      conversation: conversation,
      messages: messages,
      format: ExportFormat.txt,
    );

    expect(txt, contains('Title: ${conversation.title}'));
    expect(txt, contains('USER: Hello there'));
    expect(txt, contains('ASSISTANT: Hi! How can I help?'));
  });

  test('Markdown export contains title and role headings', () {
    final String markdown = exportService.buildConversationExport(
      conversation: conversation,
      messages: messages,
      format: ExportFormat.markdown,
    );

    expect(markdown, contains('# ${conversation.title}'));
    expect(markdown, contains('## User'));
    expect(markdown, contains('## Assistant'));
    expect(markdown, contains('Hello there'));
  });

  test('JSON export is valid JSON with expected keys', () {
    final String jsonExport = exportService.buildConversationExport(
      conversation: conversation,
      messages: messages,
      format: ExportFormat.json,
      includeMetadata: true,
    );

    final Map<String, dynamic> decoded =
        jsonDecode(jsonExport) as Map<String, dynamic>;

    expect(decoded['conversation'], isA<Map<String, dynamic>>());
    expect(decoded['messages'], isA<List<dynamic>>());
    expect(decoded['usageRecords'], isA<List<dynamic>>());
    expect(decoded['exportedAt'], isA<String>());
    expect(decoded['includeMetadata'], true);
  });

  test('suggested filename sanitizes and applies extension', () {
    final String txtName =
        exportService.suggestedFileName(conversation, ExportFormat.txt);
    final String mdName =
        exportService.suggestedFileName(conversation, ExportFormat.markdown);
    final String jsonName =
        exportService.suggestedFileName(conversation, ExportFormat.json);

    expect(txtName, endsWith('.txt'));
    expect(mdName, endsWith('.md'));
    expect(jsonName, endsWith('.json'));

    expect(txtName, isNot(contains(' ')));
    expect(txtName, isNot(contains('/')));
    expect(txtName, isNot(contains('?')));
    expect(txtName, isNot(contains('*')));
  });
}