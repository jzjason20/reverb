class TagDefinition {
  const TagDefinition({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.isProtected = false,
  });

  static const String othersId = 'tag_others';
  static const String othersName = 'others';
  static const int othersColorValue = 0xFF6B7280;

  final String id;
  final String name;
  final int colorValue;
  final bool isProtected;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TagDefinition.defaultOthers() {
    final now = DateTime.now();
    return TagDefinition(
      id: othersId,
      name: othersName,
      colorValue: othersColorValue,
      isProtected: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  TagDefinition copyWith({
    String? id,
    String? name,
    int? colorValue,
    bool? isProtected,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TagDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isProtected: isProtected ?? this.isProtected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'color_value': colorValue,
      'is_protected': isProtected ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory TagDefinition.fromMap(Map<String, Object?> map) {
    return TagDefinition(
      id: map['id']! as String,
      name: map['name']! as String,
      colorValue: (map['color_value']! as num).toInt(),
      isProtected: (map['is_protected']! as num) == 1,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }
}
