import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.openAiApiKey,
    required this.summaryModel,
    required this.transcriptionModel,
  });

  final String? openAiApiKey;
  final String summaryModel;
  final String transcriptionModel;

  bool get hasOpenAiKey => (openAiApiKey ?? '').trim().isNotEmpty;

  static Future<AppEnvironment> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    return AppEnvironment(
      openAiApiKey: dotenv.maybeGet('OPENAI_API_KEY')?.trim(),
      summaryModel: dotenv.maybeGet(
        'OPENAI_SUMMARY_MODEL',
        fallback: 'gpt-4o-mini',
      )!,
      transcriptionModel: dotenv.maybeGet(
        'OPENAI_TRANSCRIPTION_MODEL',
        fallback: 'gpt-4o-mini-transcribe',
      )!,
    );
  }
}
