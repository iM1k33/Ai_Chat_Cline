import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/database/database_tables.dart';
import 'package:aichatcline/features/logs/models/app_log_entry.dart';
import 'package:sqflite/sqflite.dart';

class LogsRepository {
  const LogsRepository({required AppDatabase appDatabase})
    : _appDatabase = appDatabase;

  final AppDatabase _appDatabase;

  Future<void> insertLog(AppLogEntry entry) async {
    final Database db = await _appDatabase.database;
    await db.insert(
      DatabaseTables.logs,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<AppLogEntry>> getLogs({int limit = 500}) async {
    final Database db = await _appDatabase.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.logs,
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(AppLogEntry.fromMap).toList();
  }

  Future<void> deleteAllLogs() async {
    final Database db = await _appDatabase.database;
    await db.delete(DatabaseTables.logs);
  }
}
