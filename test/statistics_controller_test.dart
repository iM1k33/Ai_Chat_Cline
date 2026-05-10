import 'package:aichatcline/features/statistics/models/usage_record.dart';
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
          estimatedCost: 0,
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
          estimatedCost: 0,
          currencyCode: 'USD',
          responseTimeMs: 120,
        ),
      ],
    );

    final StatisticsController controller = StatisticsController(
      statsRepository: statsRepository,
    );

    await controller.load();

    expect(controller.totalRequests, 2);
    expect(controller.requestCountByModel['model-a'], 2);
    expect(controller.totalTokens, 70);
    expect(controller.totalTokensByModel['model-a'], 70);
  });
}
