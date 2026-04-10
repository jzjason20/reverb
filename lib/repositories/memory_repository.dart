import '../models/memory_entry.dart';

abstract class MemoryRepository {
  Future<List<MemoryEntry>> fetchEntries();
  Future<void> upsertEntry(MemoryEntry entry);
}
