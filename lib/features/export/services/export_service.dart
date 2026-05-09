import 'dart:convert';

import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/models/conversation.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:intl/intl.dart';

enum ExportFormat { txt, markdown, json }

class ExportService {
  const ExportService();

  String buildConversationExport({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required ExportFormat format,
    List<UsageRecord> usageRecords = const <UsageRecord>[],
    bool includeMetadata = false,
  }) {
    return switch (format) {
      ExportFormat.txt => _buildTxt(
          conversation: conversation,
          messages: messages,
          includeMetadata: includeMetadata,
        ),
      ExportFormat.markdown => _buildMarkdown(
          conversation: conversation,
          messages: messages,
          includeMetadata: includeMetadata,
        ),
      ExportFormat.json => _buildJson(
          conversation: conversation,
          messages: messages,
          usageRecords: usageRecords,
          includeMetadata: includeMetadata,
        ),
    };
  }

  String suggestedFileName(Conversation conversation, ExportFormat format) {
    final String normalized = conversation.title.toLowerCase().trim();
    final String underscored = normalized.replaceAll(RegExp(r'\s+'), '_');
    final String safe = underscored
        .replaceAll(RegExp(r'[^a-z0-9_\-]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    final String titlePart = safe.isEmpty ? 'conversation' : safe;
    final String trimmedTitlePart = titlePart.length > 40
        ? titlePart.substring(0, 40)
        : titlePart;

    final String extension = switch (format) {
      ExportFormat.txt => 'txt',
      ExportFormat.markdown => 'md',
      ExportFormat.json => 'json',
    };

    return '$trimmedTitlePart.$extension';
  }

  String _buildTxt({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required bool includeMetadata,
  }) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final StringBuffer buffer = StringBuffer()
      ..writeln('Title: ${conversation.title}')
      ..writeln('Created: ${dateFormat.format(conversation.createdAt)}')
      ..writeln('Updated: ${dateFormat.format(conversation.updatedAt)}')
      ..writeln('')
      ..writeln('Messages:')
      ..writeln('');

    for (final ChatMessage message in messages) {
      final String role = _roleTitle(message.role).toUpperCase();
      final String createdAt = dateFormat.format(message.createdAt);
      buffer.writeln('[$createdAt] $role: ${message.content}');

      if (includeMetadata) {
        final List<String> parts = <String>[];
        if (message.providerId != null && message.providerId!.isNotEmpty) {
          parts.add('provider=${message.providerId}');
        }
        if (message.modelId != null && message.modelId!.isNotEmpty) {
          parts.add('model=${message.modelId}');
        }
        if (message.promptTokens != null) {
          parts.add('promptTokens=${message.promptTokens}');
        }
        if (message.completionTokens != null) {
          parts.add('completionTokens=${message.completionTokens}');
        }
        if (message.totalTokens != null) {
          parts.add('totalTokens=${message.totalTokens}');
        }
        if (message.estimatedCost != null) {
          parts.add('estimatedCost=${message.estimatedCost}');
        }

        if (parts.isNotEmpty) {
          buffer.writeln('  metadata: ${parts.join(', ')}');
        }
      }

      buffer.writeln('');
    }

    return buffer.toString().trimRight();
  }

  String _buildMarkdown({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required bool includeMetadata,
  }) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final StringBuffer buffer = StringBuffer()
      ..writeln('# ${conversation.title}')
      ..writeln('')
      ..writeln('- Created: ${dateFormat.format(conversation.createdAt)}')
      ..writeln('- Updated: ${dateFormat.format(conversation.updatedAt)}')
      ..writeln('');

    for (final ChatMessage message in messages) {
      buffer
        ..writeln('## ${_roleTitle(message.role)}')
        ..writeln('')
        ..writeln(message.content)
        ..writeln('');

      if (includeMetadata) {
        final List<String> lines = <String>[];
        if (message.providerId != null && message.providerId!.isNotEmpty) {
          lines.add('- Provider: ${message.providerId}');
        }
        if (message.modelId != null && message.modelId!.isNotEmpty) {
          lines.add('- Model: ${message.modelId}');
        }
        if (message.promptTokens != null) {
          lines.add('- Prompt tokens: ${message.promptTokens}');
        }
        if (message.completionTokens != null) {
          lines.add('- Completion tokens: ${message.completionTokens}');
        }
        if (message.totalTokens != null) {
          lines.add('- Total tokens: ${message.totalTokens}');
        }
        if (message.estimatedCost != null) {
          lines.add('- Estimated cost: ${message.estimatedCost}');
        }

        if (lines.isNotEmpty) {
          buffer
            ..writeln('### Metadata')
            ..writeln('')
            ..writeln(lines.join('\n'))
            ..writeln('');
        }
      }
    }

    return buffer.toString().trimRight();
  }

  String _buildJson({
    required Conversation conversation,
    required List<ChatMessage> messages,
    required List<UsageRecord> usageRecords,
    required bool includeMetadata,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'conversation': conversation.toJson(),
      'messages': messages.map((ChatMessage message) => message.toJson()).toList(),
      'usageRecords': usageRecords
          .map((UsageRecord usageRecord) => usageRecord.toJson())
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'includeMetadata': includeMetadata,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _roleTitle(ChatMessageRole role) {
    return switch (role) {
      ChatMessageRole.user => 'User',
      ChatMessageRole.assistant => 'Assistant',
      ChatMessageRole.system => 'System',
    };
  }
}