import 'dart:convert';

import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
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
    final String txtName = exportService.suggestedFileName(
      conversation,
      ExportFormat.txt,
    );
    final String mdName = exportService.suggestedFileName(
      conversation,
      ExportFormat.markdown,
    );
    final String jsonName = exportService.suggestedFileName(
      conversation,
      ExportFormat.json,
    );

    expect(txtName, endsWith('.txt'));
    expect(mdName, endsWith('.md'));
    expect(jsonName, endsWith('.json'));

    expect(txtName, isNot(contains(' ')));
    expect(txtName, isNot(contains('/')));
    expect(txtName, isNot(contains('?')));
    expect(txtName, isNot(contains('*')));
  });

  test(
    'statistics export contains summary/by-model/recent records in JSON',
    () {
      final DateTime generatedAt = DateTime.parse('2026-01-01T12:00:00Z');
      final List<UsageRecord> records = <UsageRecord>[
        UsageRecord(
          id: 'u1',
          conversationId: 'c1',
          messageId: 'm2',
          providerId: 'openrouter',
          modelId: 'openrouter/free',
          createdAt: DateTime.parse('2026-01-01T11:59:00Z'),
          promptTokens: 10,
          completionTokens: 5,
          totalTokens: 15,
          estimatedCost: 0.01,
          currencyCode: 'USD',
          responseTimeMs: 1200,
        ),
      ];

      final String jsonExport = exportService.buildStatisticsExport(
        format: ExportFormat.json,
        generatedAt: generatedAt,
        totalRequests: 1,
        totalPromptTokens: 10,
        totalCompletionTokens: 5,
        totalTokens: 15,
        errorCount: 0,
        averageResponseTimeMs: 1200,
        estimatedCostUsd: 0.01,
        estimatedCostRub: 0,
        requestCountByModel: <String, int>{'openrouter/free': 1},
        totalTokensByModel: <String, int>{'openrouter/free': 15},
        estimatedCostByModel: <String, double>{'openrouter/free': 0.01},
        totalTokensByProvider: <String, int>{'openrouter': 15},
        recentRecords: records,
      );

      final Map<String, dynamic> decoded =
          jsonDecode(jsonExport) as Map<String, dynamic>;

      expect(decoded['summary'], isA<Map<String, dynamic>>());
      expect(decoded['byModel'], isA<List<dynamic>>());
      expect(decoded['tokensByProvider'], isA<Map<String, dynamic>>());
      expect(decoded['recentUsageRecords'], isA<List<dynamic>>());
      expect(
        (decoded['summary'] as Map<String, dynamic>)['totalRequests'],
        equals(1),
      );
    },
  );
}
