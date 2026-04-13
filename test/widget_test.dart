import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reverb/app/reverb_app.dart';
import 'package:reverb/controllers/reverb_controller.dart';
import 'package:reverb/repositories/in_memory_memory_repository.dart';
import 'package:reverb/services/memory_processor.dart';
import 'package:reverb/services/gemini_summary_service.dart';
import 'package:reverb/services/reminder_scheduler.dart';
import 'package:reverb/services/speech_capture_service.dart';

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
    expect(
      find.text('Dump your brain here. Future you will deal with it.'),
      findsOneWidget,
    );
    expect(find.text('Stuff to do'), findsOneWidget);
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

    await tester.tap(find.text('Lightbulb Moment').first);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
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
}
