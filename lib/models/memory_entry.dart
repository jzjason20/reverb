enum MemoryType { thought, todo, idea, reminder }

enum SyncStatus { localOnly, pendingUpload, synced, pendingDelete, conflict }

class MemoryEntry {
  static const int schemaVersion = 1;

  const MemoryEntry({
    required this.id,
    required this.transcript,
    required this.summary,
    required this.createdAt,
    required this.updatedAt,
    required this.type,
    required this.version,
    required this.syncStatus,
    required this.metadata,
    this.taskTitle,
    this.triggerTime,
    this.isComplete = false,
    this.lastSyncedAt,
    this.deletedAt,
  });

  final String id;
  final String transcript;
  final String summary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoryType type;
  final String? taskTitle;
  final DateTime? triggerTime;
  final bool isComplete;
  final int version;
  final SyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final DateTime? deletedAt;
  final Map<String, Object?> metadata;

  bool get isDeleted => deletedAt != null;

  MemoryEntry copyWith({
    String? id,
    String? transcript,
    String? summary,
    DateTime? createdAt,
    DateTime? updatedAt,
    MemoryType? type,
    Object? taskTitle = _unset,
    Object? triggerTime = _unset,
    bool? isComplete,
    int? version,
    SyncStatus? syncStatus,
    Object? lastSyncedAt = _unset,
    Object? deletedAt = _unset,
    Map<String, Object?>? metadata,
  }) {
    return MemoryEntry(
      id: id ?? this.id,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
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
      'task_title': taskTitle,
      'trigger_time': triggerTime?.toIso8601String(),
      'is_complete': isComplete ? 1 : 0,
      'version': version,
      'sync_status': syncStatus.name,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'schema_version': schemaVersion,
      'metadata': Map<String, Object?>.from(metadata),
    };
  }

  factory MemoryEntry.fromMap(Map<String, Object?> map) {
    final metadata = map['metadata'];
    return MemoryEntry(
      id: map['id']! as String,
      transcript: map['transcript']! as String,
      summary: map['summary']! as String,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
      type: MemoryType.values.byName(map['type']! as String),
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
      metadata: metadata is Map
          ? Map<String, Object?>.from(metadata)
          : const <String, Object?>{},
    );
  }
}

const Object _unset = Object();
