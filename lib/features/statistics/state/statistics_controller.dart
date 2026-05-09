import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:flutter/foundation.dart';

class StatisticsController extends ChangeNotifier {
  StatisticsController({required StatsRepository statsRepository})
    : _statsRepository = statsRepository;

  final StatsRepository _statsRepository;

  List<UsageRecord> records = <UsageRecord>[];
  bool isLoading = false;
  String? error;

  int get totalRequests => records.length;

  int get totalPromptTokens => records.fold<int>(
    0,
    (int sum, UsageRecord record) => sum + record.promptTokens,
  );

  int get totalCompletionTokens => records.fold<int>(
    0,
    (int sum, UsageRecord record) => sum + record.completionTokens,
  );

  int get totalTokens =>
      records.fold<int>(0, (int sum, UsageRecord record) => sum + record.totalTokens);

  double get totalEstimatedCostUsd => records.fold<double>(
    0,
    (double sum, UsageRecord record) =>
        record.currencyCode == 'USD' ? sum + record.estimatedCost : sum,
  );

  double get totalEstimatedCostRub => records.fold<double>(
    0,
    (double sum, UsageRecord record) =>
        record.currencyCode == 'RUB' ? sum + record.estimatedCost : sum,
  );

  int get errorCount => records.where((UsageRecord record) {
    final String? errorValue = record.error;
    return errorValue != null && errorValue.trim().isNotEmpty;
  }).length;

  double get averageResponseTimeMs {
    final List<int> values = records
        .map((UsageRecord record) => record.responseTimeMs)
        .whereType<int>()
        .toList();

    if (values.isEmpty) {
      return 0;
    }

    final int total = values.fold<int>(0, (int sum, int value) => sum + value);
    return total / values.length;
  }

  Map<String, int> get totalTokensByModel {
    final Map<String, int> result = <String, int>{};
    for (final UsageRecord record in records) {
      result.update(
        record.modelId,
        (int value) => value + record.totalTokens,
        ifAbsent: () => record.totalTokens,
      );
    }
    return result;
  }

  Map<String, double> get estimatedCostByModel {
    final Map<String, double> result = <String, double>{};
    for (final UsageRecord record in records) {
      result.update(
        record.modelId,
        (double value) => value + record.estimatedCost,
        ifAbsent: () => record.estimatedCost,
      );
    }
    return result;
  }

  Map<String, int> get requestCountByModel {
    final Map<String, int> result = <String, int>{};
    for (final UsageRecord record in records) {
      result.update(record.modelId, (int value) => value + 1, ifAbsent: () => 1);
    }
    return result;
  }

  Map<String, int> get totalTokensByProvider {
    final Map<String, int> result = <String, int>{};
    for (final UsageRecord record in records) {
      result.update(
        record.providerId,
        (int value) => value + record.totalTokens,
        ifAbsent: () => record.totalTokens,
      );
    }
    return result;
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      records = await _statsRepository.getAllUsageRecords();
    } catch (_) {
      error = 'Failed to load statistics';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> deleteAllStatistics() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      await _statsRepository.deleteAllUsageRecords();
      records = <UsageRecord>[];
    } catch (_) {
      error = 'Failed to delete statistics';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}