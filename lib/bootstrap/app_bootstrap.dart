import '../config/app_environment.dart';
import '../controllers/reverb_controller.dart';
import '../repositories/in_memory_memory_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/sqlite_memory_repository.dart';
import '../services/memory_processor.dart';
import '../services/gemini_summary_service.dart';
import '../services/reminder_scheduler.dart';
import '../services/speech_capture_service.dart';

class AppBootstrap {
  AppBootstrap({required this.controller, required this.speechCaptureService});

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;

  static Future<AppBootstrap> initialize() async {
    final environment = await AppEnvironment.load();
    final processor = MemoryProcessor();

    MemoryRepository repository;
    try {
      repository = SqliteMemoryRepository();
      final existingEntries = await repository.fetchEntries();
      if (existingEntries.isEmpty) {
        for (final entry in processor.buildSampleEntries()) {
          await repository.upsertEntry(entry);
        }
      }
    } catch (_) {
      repository = InMemoryMemoryRepository(
        seedEntries: processor.buildSampleEntries(),
      );
    }

    final reminderScheduler = LocalNotificationReminderScheduler();
    await reminderScheduler.initialize();

    final controller = ReverbController(
      repository: repository,
      processor: processor,
      reminderScheduler: reminderScheduler,
      summaryService: GeminiSummaryService(environment: environment),
    );
    await controller.load();

    return AppBootstrap(
      controller: controller,
      speechCaptureService: DeviceSpeechCaptureService(),
    );
  }
}
