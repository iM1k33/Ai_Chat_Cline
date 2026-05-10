import 'dart:io';

import 'package:aichatcline/data/database/database_tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase();

  static const String _databaseName = 'ai_chat.db';
  static const int _databaseVersion = 2;

  sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    if (_database != null) {
      return _database!;
    }

    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      sqflite.databaseFactory = databaseFactoryFfi;
    }

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(appDir.path, _databaseName);

    _database = await sqflite.openDatabase(
      dbPath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _upgradeSchema(db, oldVersion, newVersion);
      },
    );

    return _database!;
  }

  Future<void> _createSchema(sqflite.Database db) async {
    await db.execute(DatabaseTables.createConversationsTable);
    await db.execute(DatabaseTables.createMessagesTable);
    await db.execute(DatabaseTables.createUsageRecordsTable);
    await db.execute(DatabaseTables.createLogsTable);

    await db.execute(DatabaseTables.createMessagesConversationCreatedIndex);
    await db.execute(DatabaseTables.createUsageProviderModelCreatedIndex);
    await db.execute(DatabaseTables.createUsageConversationCreatedIndex);
    await db.execute(DatabaseTables.createLogsCreatedIndex);
  }

  Future<void> _upgradeSchema(
    sqflite.Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await db.execute(DatabaseTables.createLogsTable);
      await db.execute(DatabaseTables.createLogsCreatedIndex);
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<void> deleteDatabaseFile() async {
    await close();

    final Directory appDir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(appDir.path, _databaseName);
    await sqflite.deleteDatabase(dbPath);
  }
}
