import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/database/database_tables.dart';
import 'package:aichatcline/features/statistics/models/usage_record.dart';
import 'package:sqflite/sqflite.dart';

class StatsRepository {
  const StatsRepository({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<void> insertUsageRecord(UsageRecord record) async {
    final Database db = await _appDatabase.database;

    await db.insert(
      DatabaseTables.usageRecords,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<UsageRecord>> getAllUsageRecords() async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.usageRecords,
      orderBy: 'created_at DESC',
    );

    return rows.map(UsageRecord.fromMap).toList();
  }

  Future<List<UsageRecord>> getUsageRecordsForConversation(
    String conversationId,
  ) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.usageRecords,
      where: 'conversation_id = ?',
      whereArgs: <Object?>[conversationId],
      orderBy: 'created_at ASC',
    );

    return rows.map(UsageRecord.fromMap).toList();
  }

  Future<void> deleteAllUsageRecords() async {
    final Database db = await _appDatabase.database;
    await db.delete(DatabaseTables.usageRecords);
  }
}
