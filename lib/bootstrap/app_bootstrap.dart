import '../config/app_environment.dart';
import '../controllers/reverb_controller.dart';
import '../models/tag_definition.dart';
import '../repositories/in_memory_memory_repository.dart';
import '../repositories/memory_repository.dart';
import '../repositories/sqlite_memory_repository.dart';
import '../services/gemini_summary_service.dart';
import '../services/memory_processor.dart';
import '../services/reminder_scheduler.dart';
import '../services/speech_capture_service.dart';
import '../services/whisper_transcribe_service.dart';

class AppBootstrap {
  AppBootstrap({
    required this.controller,
    required this.speechCaptureService,
    this.whisperTranscribeService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;
  final WhisperTranscribeService? whisperTranscribeService;

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
        seedTags: [
          TagDefinition(
            id: TagDefinition.othersId,
            name: TagDefinition.othersName,
            colorValue: TagDefinition.othersColorValue,
            isProtected: true,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ],
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
      whisperTranscribeService: environment.hasProxy
          ? WhisperTranscribeService(proxyBaseUrl: environment.proxyUrl!)
          : null,
    );
  }
}
