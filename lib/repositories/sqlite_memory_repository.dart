import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/memory_entry.dart';
import 'memory_repository.dart';

class SqliteMemoryRepository implements MemoryRepository {
  SqliteMemoryRepository();

  static const _databaseName = 'reverb_v1.db';
  static const _tableName = 'memory_entries';

  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = p.join(await getDatabasesPath(), _databaseName);
    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            transcript TEXT NOT NULL,
            summary TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            type TEXT NOT NULL,
            task_title TEXT,
            trigger_time TEXT,
            is_complete INTEGER NOT NULL,
            version INTEGER NOT NULL,
            sync_status TEXT NOT NULL,
            last_synced_at TEXT,
            deleted_at TEXT,
            schema_version INTEGER NOT NULL,
            metadata TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  @override
  Future<List<MemoryEntry>> fetchEntries() async {
    final database = await _db;
    final rows = await database.query(_tableName, orderBy: 'created_at DESC');

    return rows.map(_mapRowToEntry).toList(growable: false);
  }

  @override
  Future<void> upsertEntry(MemoryEntry entry) async {
    final database = await _db;
    final record = entry.toMap();
    await database.insert(_tableName, <String, Object?>{
      ...record,
      'metadata': jsonEncode(record['metadata']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  MemoryEntry _mapRowToEntry(Map<String, Object?> row) {
    return MemoryEntry.fromMap(<String, Object?>{
      ...row,
      'metadata':
          jsonDecode(row['metadata']! as String) as Map<String, dynamic>,
    });
  }
}
