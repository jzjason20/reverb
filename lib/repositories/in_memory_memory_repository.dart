import '../models/memory_entry.dart';
import '../models/tag_definition.dart';
import 'memory_repository.dart';

class InMemoryMemoryRepository implements MemoryRepository {
  InMemoryMemoryRepository({
    List<MemoryEntry>? seedEntries,
    List<TagDefinition>? seedTags,
  }) : _entries = [...?seedEntries],
       _tags = [...?seedTags];

  final List<MemoryEntry> _entries;
  final List<TagDefinition> _tags;

  void _ensureDefaultTags() {
    if (_tags.any((tag) => tag.name == TagDefinition.othersName)) {
      return;
    }
    _tags.add(TagDefinition.defaultOthers());
  }

  @override
  Future<List<MemoryEntry>> fetchEntries() async {
    return List.unmodifiable(_entries);
  }

  @override
  Future<List<TagDefinition>> fetchTags() async {
    _ensureDefaultTags();
    final sorted = [..._tags]
      ..sort((left, right) => left.name.compareTo(right.name));
    return List.unmodifiable(sorted);
  }

  @override
  Future<void> upsertEntry(MemoryEntry entry) async {
    final index = _entries.indexWhere((stored) => stored.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
      return;
    }

    _entries[index] = entry;
  }

  @override
  Future<void> upsertTag(TagDefinition tag) async {
    _ensureDefaultTags();
    final index = _tags.indexWhere((stored) => stored.id == tag.id);
    if (index == -1) {
      _tags.add(tag);
      return;
    }

    _tags[index] = tag;
  }

  @override
  Future<void> deleteTag(String tagId) async {
    _tags.removeWhere((tag) => tag.id == tagId && !tag.isProtected);
    _ensureDefaultTags();
  }
}
