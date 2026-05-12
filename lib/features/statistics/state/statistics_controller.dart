import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/statistics/models/account_balance.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:flutter/foundation.dart';

class StatisticsController extends ChangeNotifier {
  StatisticsController({
    required StatsRepository statsRepository,
    required SettingsController settingsController,
    required OpenAICompatibleClient aiClient,
    AppLogger? appLogger,
  }) : _statsRepository = statsRepository,
       _settingsController = settingsController,
       _aiClient = aiClient,
       _appLogger = appLogger;

  final StatsRepository _statsRepository;
  final SettingsController _settingsController;
  final OpenAICompatibleClient _aiClient;
  final AppLogger? _appLogger;

  List<UsageRecord> records = <UsageRecord>[];
  AccountBalance? accountBalance;
  bool isLoading = false;
  bool isLoadingBalance = false;
  String? error;
  String? balanceError;

  static String formatBalanceBadgeText(AccountBalance? balance) {
    if (balance == null) {
      return 'Balance';
    }

    final double? value = balance.balance;
    final String currency = (balance.currencyCode ?? '').toUpperCase().trim();
    if (value != null) {
      final String amount = value.toStringAsFixed(2);
      if (currency == 'RUB') {
        return '₽$amount';
      }
      return '\$$amount';
    }

    if (balance.rawSummary.trim().isNotEmpty ||
        (balance.subscriptionStatus?.trim().isNotEmpty ?? false)) {
      return 'Balance';
    }

    return 'Balance';
  }

  int get totalRequests => records.length;

  int get totalPromptTokens => records.fold<int>(
    0,
    (int sum, UsageRecord record) => sum + record.promptTokens,
  );

  int get totalCompletionTokens => records.fold<int>(
    0,
    (int sum, UsageRecord record) => sum + record.completionTokens,
  );

  int get totalTokens => records.fold<int>(
    0,
    (int sum, UsageRecord record) => sum + record.totalTokens,
  );

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
      result.update(
        record.modelId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
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

  Future<void> loadAccountBalance() async {
    isLoadingBalance = true;
    balanceError = null;
    notifyListeners();

    try {
      await _appLogger?.logInfo(
        category: 'balance',
        message: 'Balance check started',
      );

      final String apiKey = _settingsController.apiKey.trim();
      if (apiKey.isEmpty || !_settingsController.isApiKeyValidated) {
        throw Exception('Validated API key is required');
      }

      final provider = _settingsController.effectiveProvider();
      if (provider == null) {
        throw Exception('Provider is not configured');
      }

      accountBalance = await _aiClient.fetchAccountBalance(
        provider: provider,
        apiKey: apiKey,
      );

      await _appLogger?.logInfo(
        category: 'balance',
        message: 'Balance check succeeded',
        metadata: <String, dynamic>{'providerId': provider.id},
      );
    } catch (e) {
      accountBalance = null;
      balanceError = e.toString().replaceFirst('Exception: ', '').trim();
      if (balanceError == null || balanceError!.isEmpty) {
        balanceError = 'Failed to load account balance';
      }
      await _appLogger?.logWarning(
        category: 'balance',
        message: 'Balance check failed',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    } finally {
      isLoadingBalance = false;
      notifyListeners();
    }
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

  void resetLocalState() {
    records = <UsageRecord>[];
    accountBalance = null;
    error = null;
    balanceError = null;
    isLoading = false;
    isLoadingBalance = false;
    notifyListeners();
  }
}
