import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/memory_entry.dart';
import '../models/tag_definition.dart';
import 'memory_repository.dart';

class SqliteMemoryRepository implements MemoryRepository {
  SqliteMemoryRepository();

  static const _databaseName = 'reverb_v2.db';
  static const _entriesTableName = 'memory_entries';
  static const _tagsTableName = 'tags';

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
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_entriesTableName (
            id TEXT PRIMARY KEY,
            transcript TEXT NOT NULL,
            summary TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            type TEXT NOT NULL,
            priority TEXT NOT NULL,
            task_title TEXT,
            trigger_time TEXT,
            is_complete INTEGER NOT NULL,
            version INTEGER NOT NULL,
            sync_status TEXT NOT NULL,
            last_synced_at TEXT,
            deleted_at TEXT,
            tags TEXT NOT NULL DEFAULT '[]',
            schema_version INTEGER NOT NULL,
            metadata TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE $_tagsTableName (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color_value INTEGER NOT NULL,
            is_protected INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.insert(
          _tagsTableName,
          TagDefinition.defaultOthers().toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      },
    );
    return _database!;
  }

  @override
  Future<List<MemoryEntry>> fetchEntries() async {
    final database = await _db;
    final rows = await database.query(
      _entriesTableName,
      orderBy: 'created_at DESC',
    );

    return rows.map(_mapRowToEntry).toList(growable: false);
  }

  @override
  Future<List<TagDefinition>> fetchTags() async {
    final database = await _db;
    final rows = await database.query(_tagsTableName, orderBy: 'name ASC');
    if (rows.isEmpty) {
      await database.insert(
        _tagsTableName,
        TagDefinition.defaultOthers().toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return [TagDefinition.defaultOthers()];
    }

    return rows
        .map((row) => TagDefinition.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<void> upsertEntry(MemoryEntry entry) async {
    final database = await _db;
    final record = entry.toMap();
    await database.insert(_entriesTableName, <String, Object?>{
      ...record,
      'tags': jsonEncode(record['tags']),
      'metadata': jsonEncode(record['metadata']),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> upsertTag(TagDefinition tag) async {
    final database = await _db;
    await database.insert(
      _tagsTableName,
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteTag(String tagId) async {
    final database = await _db;
    await database.delete(
      _tagsTableName,
      where: 'id = ? AND is_protected = 0',
      whereArgs: [tagId],
    );
  }

  MemoryEntry _mapRowToEntry(Map<String, Object?> row) {
    return MemoryEntry.fromMap(<String, Object?>{
      ...row,
      'tags': jsonDecode(row['tags']! as String) as List<dynamic>,
      'metadata':
          jsonDecode(row['metadata']! as String) as Map<String, dynamic>,
    });
  }
}
