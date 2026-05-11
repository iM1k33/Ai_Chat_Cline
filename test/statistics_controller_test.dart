import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/statistics/state/statistics_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/fake_stats_repository.dart';

void main() {
  test('statistics aggregates cumulative usage records correctly', () async {
    final FakeStatsRepository statsRepository = FakeStatsRepository(
      initialRecords: <UsageRecord>[
        UsageRecord(
          id: 'u1',
          conversationId: 'c1',
          messageId: 'm1',
          providerId: 'openrouter',
          modelId: 'model-a',
          createdAt: DateTime.parse('2026-05-10T09:00:00Z'),
          promptTokens: 10,
          completionTokens: 20,
          totalTokens: 30,
          estimatedCost: 0.000030,
          currencyCode: 'USD',
          responseTimeMs: 100,
        ),
        UsageRecord(
          id: 'u2',
          conversationId: 'c1',
          messageId: 'm2',
          providerId: 'openrouter',
          modelId: 'model-a',
          createdAt: DateTime.parse('2026-05-10T09:01:00Z'),
          promptTokens: 15,
          completionTokens: 25,
          totalTokens: 40,
          estimatedCost: 0.000040,
          currencyCode: 'USD',
          responseTimeMs: 120,
        ),
        UsageRecord(
          id: 'u3',
          conversationId: 'c2',
          messageId: 'm3',
          providerId: 'vsegpt',
          modelId: 'model-b',
          createdAt: DateTime.parse('2026-05-10T09:02:00Z'),
          promptTokens: 5,
          completionTokens: 5,
          totalTokens: 10,
          estimatedCost: 0.25,
          currencyCode: 'RUB',
          responseTimeMs: 80,
        ),
      ],
    );

    final StatisticsController controller = StatisticsController(
      statsRepository: statsRepository,
      settingsController: SettingsController(
        settingsStorage: const SettingsStorageService(),
        secureStorage: SecureStorageService(),
        aiClient: OpenAICompatibleClient(),
      ),
      aiClient: OpenAICompatibleClient(),
    );

    await controller.load();

    expect(controller.totalRequests, 3);
    expect(controller.requestCountByModel['model-a'], 2);
    expect(controller.totalTokens, 80);
    expect(controller.totalTokensByModel['model-a'], 70);
    expect(controller.totalEstimatedCostUsd, closeTo(0.000070, 1e-12));
    expect(controller.totalEstimatedCostRub, closeTo(0.25, 1e-12));
  });
}
