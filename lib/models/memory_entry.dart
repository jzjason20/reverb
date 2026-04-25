enum MemoryType { braindump, todo, idea }

enum MemoryPriority { none, low, medium, high }

enum SyncStatus { localOnly, pendingUpload, synced, pendingDelete, conflict }

class MemoryEntry {
  static const int schemaVersion = 2;

  const MemoryEntry({
    required this.id,
    required this.transcript,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    this.priority = MemoryPriority.none,
    required this.version,
    required this.syncStatus,
    required this.metadata,
    this.taskTitle,
    this.triggerTime,
    this.isComplete = false,
    this.lastSyncedAt,
    this.deletedAt,
    this.tags = const [],
  });

  final String id;
  final String transcript;
  final String summary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoryType type;
  final MemoryPriority priority;
  final String? taskTitle;
  final DateTime? triggerTime;
  final bool isComplete;
  final int version;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  final List<String> tags;
  final Map<String, Object?> metadata;

  bool get isDeleted => deletedAt != null;

  MemoryEntry copyWith({
    String? id,
    String? transcript,
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
    MemoryType? type,
    MemoryPriority? priority,
    Object? taskTitle = _unset,
    Object? triggerTime = _unset,
    bool? isComplete,
    int? version,
    SyncStatus? syncStatus,
    Object? lastSyncedAt = _unset,
    Object? deletedAt = _unset,
    List<String>? tags,
    Map<String, Object?>? metadata,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      taskTitle: identical(taskTitle, _unset)
          ? this.taskTitle
          : taskTitle as String?,
      triggerTime: identical(triggerTime, _unset)
          ? this.triggerTime
          : triggerTime as DateTime?,
      isComplete: isComplete ?? this.isComplete,
      version: version ?? this.version,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncedAt: identical(lastSyncedAt, _unset)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'transcript': transcript,
      'summary': summary,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'type': type.name,
      'priority': priority.name,
      'task_title': taskTitle,
      'trigger_time': triggerTime?.toIso8601String(),
      'is_complete': isComplete ? 1 : 0,
      'version': version,
      'sync_status': syncStatus.name,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'tags': List<String>.from(tags),
      'schema_version': schemaVersion,
      'metadata': Map<String, Object?>.from(metadata),
    };
  }

  factory MemoryEntry.fromMap(Map<String, Object?> map) {
    final metadata = map['metadata'];
    final tags = map['tags'];
    return MemoryEntry(
      id: map['id']! as String,
      transcript: map['transcript']! as String,
      summary: map['summary']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      type: _parseMemoryType(map['type'] as String?),
      priority: _parsePriority(map['priority'] as String?),
      taskTitle: map['task_title'] as String?,
      triggerTime: map['trigger_time'] == null
          ? null
          : DateTime.parse(map['trigger_time']! as String),
      isComplete: (map['is_complete']! as num) == 1,
      version: (map['version']! as num).toInt(),
      syncStatus: SyncStatus.values.byName(map['sync_status']! as String),
      lastSyncedAt: map['last_synced_at'] == null
          ? null
          : DateTime.parse(map['last_synced_at']! as String),
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at']! as String),
      tags: tags is List
          ? List<String>.from(tags.map((e) => e.toString()))
          : const <String>[],
      metadata: metadata is Map
          ? Map<String, Object?>.from(metadata)
          : const <String, Object?>{},
    );
  }
}

const Object _unset = Object();

MemoryType _parseMemoryType(String? rawType) {
  return switch (rawType) {
    'braindump' => MemoryType.braindump,
    'todo' => MemoryType.todo,
    'idea' => MemoryType.idea,
    'thought' => MemoryType.braindump,
    'reminder' => MemoryType.todo,
    _ => MemoryType.braindump,
  };
}

MemoryPriority _parsePriority(String? rawPriority) {
  return switch (rawPriority) {
    'low' => MemoryPriority.low,
    'medium' => MemoryPriority.medium,
    'high' => MemoryPriority.high,
    _ => MemoryPriority.none,
  };
}
