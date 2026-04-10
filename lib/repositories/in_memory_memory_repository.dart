import '../models/memory_entry.dart';
import 'memory_repository.dart';

class InMemoryMemoryRepository implements MemoryRepository {
  InMemoryMemoryRepository({List<MemoryEntry>? seedEntries})
    : _entries = [...?seedEntries];

  final List<MemoryEntry> _entries;

  @override
  Future<List<MemoryEntry>> fetchEntries() async {
    return List.unmodifiable(_entries);
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
}
