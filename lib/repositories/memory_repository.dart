import '../models/memory_entry.dart';
import '../models/tag_definition.dart';

abstract class MemoryRepository {
  Future<List<MemoryEntry>> fetchEntries();
  Future<void> upsertEntry(MemoryEntry entry);
  Future<List<TagDefinition>> fetchTags();
  Future<void> upsertTag(TagDefinition tag);
  Future<void> deleteTag(String tagId);
}
