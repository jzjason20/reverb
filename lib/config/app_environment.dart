import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.geminiApiKey,
    required this.summaryModel,
  });

  final String? geminiApiKey;
  final String summaryModel;

  bool get hasGeminiKey => (geminiApiKey ?? '').trim().isNotEmpty;

  static Future<AppEnvironment> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    return AppEnvironment(
      geminiApiKey: dotenv.maybeGet('GEMINI_API_KEY')?.trim(),
      summaryModel: dotenv.maybeGet(
        'GEMINI_SUMMARY_MODEL',
        fallback: 'gemini-2.5-flash',
      )!,
    );
  }
}
