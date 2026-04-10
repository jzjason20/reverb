import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/models/memory_entry.dart';
import 'package:reverb/services/memory_processor.dart';

void main() {
  final processor = MemoryProcessor();

  test('classifies todo transcripts and extracts task titles', () {
    final entry = processor.processTranscript(
      'i need to fix the onboarding flow tonight',
      now: DateTime(2026, 4, 10, 9),
    );

    expect(entry.type, MemoryType.todo);
    expect(entry.taskTitle, 'Fix the onboarding flow');
    expect(entry.syncStatus, SyncStatus.localOnly);
  });

  test('parses reminders with relative time', () {
    final entry = processor.processTranscript(
      'remind me to stretch in 45 minutes',
      now: DateTime(2026, 4, 10, 9),
    );

    expect(entry.type, MemoryType.reminder);
    expect(entry.triggerTime, DateTime(2026, 4, 10, 9, 45));
  });

  test('keeps thoughts as default', () {
    final entry = processor.processTranscript(
      'Need to remember that energy drops after lunch unless I walk first',
      now: DateTime(2026, 4, 10, 9),
    );

    expect(entry.type, MemoryType.thought);
    expect(entry.taskTitle, isNull);
  });

  test('round-trips sync-safe schema through map serialization', () {
    final entry = processor.processTranscript(
      'idea: sync should feel instant when it ships later',
      now: DateTime(2026, 4, 10, 9),
    );

    final restored = MemoryEntry.fromMap(entry.toMap());

    expect(restored.id, entry.id);
    expect(restored.type, MemoryType.idea);
    expect(restored.metadata['storage_strategy'], 'local_first');
    expect(restored.deletedAt, isNull);
  });
}
