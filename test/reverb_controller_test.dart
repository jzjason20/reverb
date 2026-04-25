import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/controllers/reverb_controller.dart';
import 'package:reverb/models/memory_entry.dart';
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

    final visible = controller.entries.where((entry) => !entry.isDeleted);
    expect(visible.any((entry) => entry.id == targetEntry.id), isFalse);

    final storedEntry = controller.entries.firstWhere(
      (entry) => entry.id == targetEntry.id,
    );
    expect(storedEntry.isDeleted, isTrue);
    expect(storedEntry.syncStatus.name, 'pendingDelete');
  });

  test(
    'splits one capture into multiple todos when AI returns many entries',
    () async {
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _StubSummaryService(
          results: const [
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              summary: 'Buy milk',
              taskTitle: 'Buy milk',
            ),
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              summary: 'Call mom',
              taskTitle: 'Call mom',
            ),
          ],
        ),
      );

      await controller.load();
      await controller.captureTranscript('buy milk and call mom');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final visibleEntries = controller.entries
          .where((entry) => !entry.isDeleted)
          .toList();
      expect(visibleEntries, hasLength(2));
      expect(
        visibleEntries.where((entry) => entry.type == MemoryType.todo),
        hasLength(2),
      );

      final primaryEntry = visibleEntries.firstWhere(
        (entry) => entry.metadata['derived_from_entry_id'] == null,
      );
      final derivedEntry = visibleEntries.firstWhere(
        (entry) => entry.metadata['derived_from_entry_id'] == primaryEntry.id,
      );

      expect(primaryEntry.taskTitle, 'Buy milk');
      expect(primaryEntry.transcript, 'Buy milk');
      expect(derivedEntry.taskTitle, 'Call mom');
      expect(derivedEntry.transcript, 'Call mom');
      expect(primaryEntry.metadata['capture_group_id'], isNotNull);
      expect(
        derivedEntry.metadata['capture_group_id'],
        primaryEntry.metadata['capture_group_id'],
      );

      final feedback = controller.latestCaptureFeedback;
      expect(feedback, isNotNull);
      expect(feedback!.entryCount, 2);
      expect(feedback.todoCount, 2);
      expect(feedback.message, 'Created 2 todos from your voice note!');
    },
  );

  test(
    'falls back to deterministic multi-todo extraction when AI is unavailable',
    () async {
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _NoopSummaryService(),
      );

      await controller.load();
      await controller.captureTranscript(
        'buy milk and call mom tomorrow at 6 pm',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final visibleEntries = controller.entries
          .where((entry) => !entry.isDeleted)
          .toList();
      expect(visibleEntries, hasLength(2));
      expect(visibleEntries[0].taskTitle, 'Buy milk');
      expect(visibleEntries[1].taskTitle, 'Call mom');

      final feedback = controller.latestCaptureFeedback;
      expect(feedback, isNotNull);
      expect(feedback!.todoCount, 2);
    },
  );

  test(
    'prefers deterministic split when AI under-extracts a multi-todo note',
    () async {
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _StubSummaryService(
          results: const [
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              summary: 'Buy milk and call mom',
              taskTitle: 'Buy milk and call mom',
            ),
          ],
        ),
      );

      await controller.load();
      await controller.captureTranscript('buy milk and call mom');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final visibleEntries = controller.entries
          .where((entry) => !entry.isDeleted)
          .toList();
      expect(visibleEntries, hasLength(2));
      expect(visibleEntries.map((entry) => entry.taskTitle), [
        'Buy milk',
        'Call mom',
      ]);
    },
  );
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

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    transcript,
    capturedAt,
  ) async => null;
}

class _StubSummaryService implements TranscriptSummaryService {
  _StubSummaryService({required this.results});

  final List<GeminiEnrichmentResult> results;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> summarize(entry) async => null;

  @override
  Future<GeminiEnrichmentResult?> enrich(transcript, capturedAt) async {
    return results.firstOrNull;
  }

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    transcript,
    capturedAt,
  ) async => results;
}
