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

  String buildStatisticsExport({
    required ExportFormat format,
    required DateTime generatedAt,
    required int totalRequests,
    required int totalPromptTokens,
    required int totalCompletionTokens,
    required int totalTokens,
    required int errorCount,
    required double averageResponseTimeMs,
    required double estimatedCostUsd,
    required double estimatedCostRub,
    required Map<String, int> requestCountByModel,
    required Map<String, int> totalTokensByModel,
    required Map<String, double> estimatedCostByModel,
    required Map<String, int> totalTokensByProvider,
    required List<UsageRecord> recentRecords,
  }) {
    return switch (format) {
      ExportFormat.txt => _buildStatisticsTxt(
        generatedAt: generatedAt,
        totalRequests: totalRequests,
        totalPromptTokens: totalPromptTokens,
        totalCompletionTokens: totalCompletionTokens,
        totalTokens: totalTokens,
        errorCount: errorCount,
        averageResponseTimeMs: averageResponseTimeMs,
        estimatedCostUsd: estimatedCostUsd,
        estimatedCostRub: estimatedCostRub,
        requestCountByModel: requestCountByModel,
        totalTokensByModel: totalTokensByModel,
        estimatedCostByModel: estimatedCostByModel,
        totalTokensByProvider: totalTokensByProvider,
        recentRecords: recentRecords,
      ),
      ExportFormat.markdown => _buildStatisticsMarkdown(
        generatedAt: generatedAt,
        totalRequests: totalRequests,
        totalPromptTokens: totalPromptTokens,
        totalCompletionTokens: totalCompletionTokens,
        totalTokens: totalTokens,
        errorCount: errorCount,
        averageResponseTimeMs: averageResponseTimeMs,
        estimatedCostUsd: estimatedCostUsd,
        estimatedCostRub: estimatedCostRub,
        requestCountByModel: requestCountByModel,
        totalTokensByModel: totalTokensByModel,
        estimatedCostByModel: estimatedCostByModel,
        totalTokensByProvider: totalTokensByProvider,
        recentRecords: recentRecords,
      ),
      ExportFormat.json => _buildStatisticsJson(
        generatedAt: generatedAt,
        totalRequests: totalRequests,
        totalPromptTokens: totalPromptTokens,
        totalCompletionTokens: totalCompletionTokens,
        totalTokens: totalTokens,
        errorCount: errorCount,
        averageResponseTimeMs: averageResponseTimeMs,
        estimatedCostUsd: estimatedCostUsd,
        estimatedCostRub: estimatedCostRub,
        requestCountByModel: requestCountByModel,
        totalTokensByModel: totalTokensByModel,
        estimatedCostByModel: estimatedCostByModel,
        totalTokensByProvider: totalTokensByProvider,
        recentRecords: recentRecords,
      ),
    };
  }

  String suggestedStatisticsFileName(
    ExportFormat format,
    DateTime generatedAt,
  ) {
    final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(generatedAt);
    final String extension = switch (format) {
      ExportFormat.txt => 'txt',
      ExportFormat.markdown => 'md',
      ExportFormat.json => 'json',
    };
    return 'statistics_$timestamp.$extension';
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
      'messages': messages
          .map((ChatMessage message) => message.toJson())
          .toList(),
      'usageRecords': usageRecords
          .map((UsageRecord usageRecord) => usageRecord.toJson())
          .toList(),
      'exportedAt': DateTime.now().toIso8601String(),
      'includeMetadata': includeMetadata,
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String _buildStatisticsTxt({
    required DateTime generatedAt,
    required int totalRequests,
    required int totalPromptTokens,
    required int totalCompletionTokens,
    required int totalTokens,
    required int errorCount,
    required double averageResponseTimeMs,
    required double estimatedCostUsd,
    required double estimatedCostRub,
    required Map<String, int> requestCountByModel,
    required Map<String, int> totalTokensByModel,
    required Map<String, double> estimatedCostByModel,
    required Map<String, int> totalTokensByProvider,
    required List<UsageRecord> recentRecords,
  }) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final StringBuffer buffer = StringBuffer()
      ..writeln('Statistics export')
      ..writeln('Generated: ${dateFormat.format(generatedAt)}')
      ..writeln('')
      ..writeln('Summary')
      ..writeln('Total requests: $totalRequests')
      ..writeln('Total tokens: $totalTokens')
      ..writeln('Prompt tokens: $totalPromptTokens')
      ..writeln('Completion tokens: $totalCompletionTokens')
      ..writeln('Error count: $errorCount')
      ..writeln(
        'Average response time (ms): ${averageResponseTimeMs.toStringAsFixed(1)}',
      )
      ..writeln('Estimated cost USD: ${estimatedCostUsd.toStringAsFixed(6)}')
      ..writeln('Estimated cost RUB: ${estimatedCostRub.toStringAsFixed(6)}')
      ..writeln('')
      ..writeln('By model');

    if (requestCountByModel.isEmpty) {
      buffer.writeln('No model statistics');
    } else {
      for (final String modelId in requestCountByModel.keys) {
        buffer.writeln('- $modelId');
        buffer.writeln('  Requests: ${requestCountByModel[modelId] ?? 0}');
        buffer.writeln('  Total tokens: ${totalTokensByModel[modelId] ?? 0}');
        buffer.writeln(
          '  Estimated cost: ${(estimatedCostByModel[modelId] ?? 0).toStringAsFixed(6)}',
        );
      }
    }

    buffer.writeln('');
    buffer.writeln('Tokens by provider');
    if (totalTokensByProvider.isEmpty) {
      buffer.writeln('No provider statistics');
    } else {
      for (final entry in totalTokensByProvider.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
    }

    buffer.writeln('');
    buffer.writeln('Recent usage records');
    if (recentRecords.isEmpty) {
      buffer.writeln('No usage records');
    } else {
      for (final UsageRecord record in recentRecords) {
        buffer.writeln('- ${dateFormat.format(record.createdAt)}');
        buffer.writeln('  Provider: ${record.providerId}');
        buffer.writeln('  Model: ${record.modelId}');
        buffer.writeln('  Total tokens: ${record.totalTokens}');
        buffer.writeln(
          '  Estimated cost: ${record.estimatedCost.toStringAsFixed(6)} ${record.currencyCode}',
        );
        buffer.writeln('  Response time (ms): ${record.responseTimeMs ?? '-'}');
        buffer.writeln('  Error: ${record.error ?? '-'}');
      }
    }

    return buffer.toString().trimRight();
  }

  String _buildStatisticsMarkdown({
    required DateTime generatedAt,
    required int totalRequests,
    required int totalPromptTokens,
    required int totalCompletionTokens,
    required int totalTokens,
    required int errorCount,
    required double averageResponseTimeMs,
    required double estimatedCostUsd,
    required double estimatedCostRub,
    required Map<String, int> requestCountByModel,
    required Map<String, int> totalTokensByModel,
    required Map<String, double> estimatedCostByModel,
    required Map<String, int> totalTokensByProvider,
    required List<UsageRecord> recentRecords,
  }) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final StringBuffer buffer = StringBuffer()
      ..writeln('# Statistics export')
      ..writeln('')
      ..writeln('- Generated: ${dateFormat.format(generatedAt)}')
      ..writeln('')
      ..writeln('## Summary')
      ..writeln('')
      ..writeln('- Total requests: $totalRequests')
      ..writeln('- Total tokens: $totalTokens')
      ..writeln('- Prompt tokens: $totalPromptTokens')
      ..writeln('- Completion tokens: $totalCompletionTokens')
      ..writeln('- Error count: $errorCount')
      ..writeln(
        '- Average response time (ms): ${averageResponseTimeMs.toStringAsFixed(1)}',
      )
      ..writeln('- Estimated cost USD: ${estimatedCostUsd.toStringAsFixed(6)}')
      ..writeln('- Estimated cost RUB: ${estimatedCostRub.toStringAsFixed(6)}')
      ..writeln('')
      ..writeln('## By model')
      ..writeln('');

    if (requestCountByModel.isEmpty) {
      buffer.writeln('No model statistics');
    } else {
      for (final String modelId in requestCountByModel.keys) {
        buffer.writeln('### $modelId');
        buffer.writeln('');
        buffer.writeln('- Requests: ${requestCountByModel[modelId] ?? 0}');
        buffer.writeln('- Total tokens: ${totalTokensByModel[modelId] ?? 0}');
        buffer.writeln(
          '- Estimated cost: ${(estimatedCostByModel[modelId] ?? 0).toStringAsFixed(6)}',
        );
        buffer.writeln('');
      }
    }

    buffer.writeln('## Tokens by provider');
    buffer.writeln('');
    if (totalTokensByProvider.isEmpty) {
      buffer.writeln('No provider statistics');
    } else {
      for (final entry in totalTokensByProvider.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value}');
      }
    }

    buffer.writeln('');
    buffer.writeln('## Recent usage records');
    buffer.writeln('');
    if (recentRecords.isEmpty) {
      buffer.writeln('No usage records');
    } else {
      for (final UsageRecord record in recentRecords) {
        buffer.writeln('### ${dateFormat.format(record.createdAt)}');
        buffer.writeln('');
        buffer.writeln('- Provider: ${record.providerId}');
        buffer.writeln('- Model: ${record.modelId}');
        buffer.writeln('- Total tokens: ${record.totalTokens}');
        buffer.writeln(
          '- Estimated cost: ${record.estimatedCost.toStringAsFixed(6)} ${record.currencyCode}',
        );
        buffer.writeln('- Response time (ms): ${record.responseTimeMs ?? '-'}');
        buffer.writeln('- Error: ${record.error ?? '-'}');
        buffer.writeln('');
      }
    }

    return buffer.toString().trimRight();
  }

  String _buildStatisticsJson({
    required DateTime generatedAt,
    required int totalRequests,
    required int totalPromptTokens,
    required int totalCompletionTokens,
    required int totalTokens,
    required int errorCount,
    required double averageResponseTimeMs,
    required double estimatedCostUsd,
    required double estimatedCostRub,
    required Map<String, int> requestCountByModel,
    required Map<String, int> totalTokensByModel,
    required Map<String, double> estimatedCostByModel,
    required Map<String, int> totalTokensByProvider,
    required List<UsageRecord> recentRecords,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      'generatedAt': generatedAt.toIso8601String(),
      'summary': <String, dynamic>{
        'totalRequests': totalRequests,
        'totalTokens': totalTokens,
        'totalPromptTokens': totalPromptTokens,
        'totalCompletionTokens': totalCompletionTokens,
        'errorCount': errorCount,
        'averageResponseTimeMs': averageResponseTimeMs,
        'estimatedCostUsd': estimatedCostUsd,
        'estimatedCostRub': estimatedCostRub,
      },
      'byModel': requestCountByModel.keys.map((String modelId) {
        return <String, dynamic>{
          'modelId': modelId,
          'requests': requestCountByModel[modelId] ?? 0,
          'totalTokens': totalTokensByModel[modelId] ?? 0,
          'estimatedCost': estimatedCostByModel[modelId] ?? 0,
        };
      }).toList(),
      'tokensByProvider': totalTokensByProvider,
      'recentUsageRecords': recentRecords
          .map((UsageRecord usageRecord) => usageRecord.toJson())
          .toList(),
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
