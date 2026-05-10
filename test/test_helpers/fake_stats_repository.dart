import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';

class FakeStatsRepository extends StatsRepository {
  FakeStatsRepository({List<UsageRecord>? initialRecords})
    : _records = List<UsageRecord>.from(initialRecords ?? <UsageRecord>[]),
      super(appDatabase: AppDatabase());

  final List<UsageRecord> _records;

  @override
  Future<void> insertUsageRecord(UsageRecord record) async {
    _records.add(record);
  }

  @override
  Future<List<UsageRecord>> getAllUsageRecords() async {
    return List<UsageRecord>.from(_records);
  }

  @override
  Future<List<UsageRecord>> getUsageRecordsForConversation(
    String conversationId,
  ) async {
    return _records
        .where((UsageRecord record) => record.conversationId == conversationId)
        .toList();
  }

  @override
  Future<void> deleteAllUsageRecords() async {
    _records.clear();
  }
}
