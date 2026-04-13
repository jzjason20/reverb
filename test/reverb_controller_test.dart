import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/controllers/reverb_controller.dart';
import 'package:reverb/repositories/in_memory_memory_repository.dart';
import 'package:reverb/services/gemini_summary_service.dart';
import 'package:reverb/services/memory_processor.dart';
import 'package:reverb/services/reminder_scheduler.dart';

void main() {
  test('soft deletes an entry and removes it from visible feed', () async {
    final processor = MemoryProcessor();
    final seedEntries = processor.buildSampleEntries();
    final targetEntry = seedEntries.first;

    final controller = ReverbController(
      repository: InMemoryMemoryRepository(seedEntries: seedEntries),
      processor: processor,
      reminderScheduler: _NoopReminderScheduler(),
      summaryService: _NoopSummaryService(),
    );

    await controller.load();
    await controller.deleteEntry(targetEntry.id);

    expect(
      controller.visibleEntries.any((entry) => entry.id == targetEntry.id),
      isFalse,
    );

    final storedEntry = controller.entries.firstWhere(
      (entry) => entry.id == targetEntry.id,
    );
    expect(storedEntry.isDeleted, isTrue);
    expect(storedEntry.syncStatus.name, 'pendingDelete');
  });
}

class _NoopReminderScheduler implements ReminderScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelReminder(entry) async {}

  @override
  Future<void> scheduleReminder(entry) async {}
}

class _NoopSummaryService implements TranscriptSummaryService {
  @override
  bool get isConfigured => false;

  @override
  Future<String?> summarize(entry) async => null;

  @override
  Future<GeminiEnrichmentResult?> enrich(transcript, capturedAt) async => null;
}
