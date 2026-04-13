import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/app/reverb_app.dart';
import 'package:reverb/controllers/reverb_controller.dart';
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
    expect(find.text('Yell at your phone'), findsOneWidget);
    expect(find.textContaining('Need to do'), findsOneWidget);
  });

  testWidgets('tapping a card shows the full entry dialog', (tester) async {
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

    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Transcript'), findsOneWidget);
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
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt,
  ) async => null;
}
