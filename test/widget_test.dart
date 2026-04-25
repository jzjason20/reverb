import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/app/reverb_app.dart';
import 'package:reverb/controllers/reverb_controller.dart';
import 'package:reverb/models/memory_entry.dart';
import 'package:reverb/repositories/in_memory_memory_repository.dart';
import 'package:reverb/services/gemini_summary_service.dart';
import 'package:reverb/services/memory_processor.dart';
import 'package:reverb/services/reminder_scheduler.dart';
import 'package:reverb/services/speech_capture_service.dart';
import 'package:reverb/widgets/memory_card.dart';

void main() {
  testWidgets('renders Reverb home shell', (tester) async {
    final processor = MemoryProcessor();
    final controller = ReverbController(
      repository: InMemoryMemoryRepository(
        seedEntries: processor.buildSampleEntries(),
      ),
      processor: processor,
      reminderScheduler: _NoopReminderScheduler(),
      summaryService: _NoopSummaryService(),
    );
    await controller.load();

    await tester.pumpWidget(
      ReverbApp(
        controller: controller,
        speechCaptureService: DisabledSpeechCaptureService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reverb'), findsOneWidget);
    expect(find.text('Capture'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
  });

  testWidgets('tapping a card opens the entry editor sheet', (tester) async {
    final processor = MemoryProcessor();
    final controller = ReverbController(
      repository: InMemoryMemoryRepository(
        seedEntries: processor.buildSampleEntries(),
      ),
      processor: processor,
      reminderScheduler: _NoopReminderScheduler(),
      summaryService: _NoopSummaryService(),
    );
    await controller.load();

    await tester.pumpWidget(
      ReverbApp(
        controller: controller,
        speechCaptureService: DisabledSpeechCaptureService(),
      ),
    );
    await tester.pumpAndSettle();

    final firstCard = find.byType(MemoryCard).first;
    await tester.ensureVisible(firstCard);
    await tester.tap(firstCard);
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('Edit'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets(
    'shows capture feedback when AI splits one note into many todos',
    (tester) async {
      final controller = ReverbController(
        repository: InMemoryMemoryRepository(),
        processor: MemoryProcessor(),
        reminderScheduler: _NoopReminderScheduler(),
        summaryService: _SplitSummaryService(),
      );
      await controller.load();

      await tester.pumpWidget(
        ReverbApp(
          controller: controller,
          speechCaptureService: DisabledSpeechCaptureService(),
        ),
      );
      await tester.pumpAndSettle();

      await controller.captureTranscript('buy milk and call mom');
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('Created 2 todos from your voice note!'),
        findsOneWidget,
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

class _SplitSummaryService implements TranscriptSummaryService {
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
    return const GeminiEnrichmentResult(
      type: MemoryType.todo,
      summary: 'Buy milk',
      taskTitle: 'Buy milk',
    );
  }

  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
    String transcript,
    DateTime capturedAt, {
    List<String> availableTags = const <String>[],
  }) async => const [
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
  ];
}
