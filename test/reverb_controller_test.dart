import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/controllers/reverb_controller.dart';
import 'package:reverb/models/memory_entry.dart';
import 'package:reverb/models/tag_definition.dart';
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

  test('passes available tags to AI and applies returned tags', () async {
    final now = DateTime(2026, 4, 25, 10);
    final summaryService = _TaggingSummaryService();
    final controller = ReverbController(
      repository: InMemoryMemoryRepository(
        seedTags: [
          TagDefinition.defaultOthers(),
          TagDefinition(
            id: 'tag_uni',
            name: 'uni',
            colorValue: 0xFF2196F3,
            createdAt: now,
            updatedAt: now,
          ),
          TagDefinition(
            id: 'tag_work',
            name: 'work',
            colorValue: 0xFF4CAF50,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      processor: MemoryProcessor(),
      reminderScheduler: _NoopReminderScheduler(),
      summaryService: summaryService,
    );

    await controller.load();
    await controller.captureTranscript(
      'email my professor about the assignment',
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(summaryService.lastAvailableTags, ['uni', 'work']);

    final visibleEntries = controller.entries
        .where((entry) => !entry.isDeleted)
        .toList();
    expect(visibleEntries, hasLength(1));
    expect(visibleEntries.single.tags, ['uni']);
  });

  test(
    'falls back to transcript tag matching when AI returns no tags',
    () async {
      final now = DateTime(2026, 4, 25, 10);
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(
          seedTags: [
            TagDefinition.defaultOthers(),
            TagDefinition(
              id: 'tag_reverb',
              name: 'reverb',
              colorValue: 0xFF2196F3,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _StubSummaryService(
          results: const [
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              transcript: 'finish the reverb landing page copy',
              summary: 'Finish landing page copy',
              taskTitle: 'Finish landing page copy',
              tags: [],
            ),
          ],
        ),
      );

      await controller.load();
      await controller.captureTranscript('finish the reverb landing page copy');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final visibleEntries = controller.entries
          .where((entry) => !entry.isDeleted)
          .toList();
      expect(visibleEntries, hasLength(1));
      expect(visibleEntries.single.tags, ['reverb']);
    },
  );

  test(
    'inherits capture-level tags across split entries when AI returns none',
    () async {
      final now = DateTime(2026, 4, 25, 10);
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(
          seedTags: [
            TagDefinition.defaultOthers(),
            TagDefinition(
              id: 'tag_asklexy',
              name: 'asklexy',
              colorValue: 0xFF2196F3,
              createdAt: now,
              updatedAt: now,
            ),
            TagDefinition(
              id: 'tag_reverb',
              name: 'reverb',
              colorValue: 0xFF4CAF50,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _StubSummaryService(
          results: const [
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              transcript: 'Check the payment flow for the mobile app by today.',
              summary: 'Check the payment flow',
              taskTitle: 'Check the payment flow',
              tags: [],
            ),
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              transcript:
                  'Submit the mobile app to Google Play for review by today.',
              summary: 'Submit to Google Play',
              taskTitle: 'Submit to Google Play',
              tags: [],
            ),
            GeminiEnrichmentResult(
              type: MemoryType.todo,
              transcript:
                  'Ensure the UI is aligned in all mobile screens by today.',
              summary: 'Align the UI',
              taskTitle: 'Align the UI',
              tags: [],
            ),
          ],
        ),
      );

      await controller.load();
      await controller.captureTranscript(
        'I have to do these things for AskLexy by today. Check the payment flow for the mobile app and submit it to Google Play for review and ensure the UI is aligned in all mobile screens.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final visibleEntries = controller.entries
          .where((entry) => !entry.isDeleted)
          .toList();
      expect(visibleEntries, hasLength(3));
      expect(
        visibleEntries.map((entry) => entry.tags),
        everyElement(['asklexy']),
      );
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
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async => null;

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async => null;
}

class _StubSummaryService implements TranscriptSummaryService {
  _StubSummaryService({required this.results});

  final List<GeminiEnrichmentResult> results;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> summarize(entry) async => null;

  @override
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async {
    return results.firstOrNull;
  }

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async => results;
}

class _TaggingSummaryService implements TranscriptSummaryService {
  List<String>? lastAvailableTags;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> summarize(entry) async => null;

  @override
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async {
    return (await enrichMulti(
      transcript,
      capturedAt,
      availableTags: availableTags,
    ))?.firstOrNull;
  }

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async {
    lastAvailableTags = availableTags;
    return const [
      GeminiEnrichmentResult(
        type: MemoryType.todo,
        transcript: 'email my professor about the assignment',
        summary: 'Email professor about assignment',
        taskTitle: 'Email professor about assignment',
        tags: ['uni'],
      ),
    ];
  }
}
