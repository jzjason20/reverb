import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.geminiApiKey,
    required this.summaryModel,
    this.proxyUrl,
  });

  final String? geminiApiKey;
  final String summaryModel;

  /// Base URL of the Reverb proxy server, e.g. https://reverb.vercel.app
  final String? proxyUrl;

  bool get hasGeminiKey => (geminiApiKey ?? '').trim().isNotEmpty;
  bool get hasProxy => (proxyUrl ?? '').trim().isNotEmpty;

  static Future<AppEnvironment> load() async {
    await dotenv.load(fileName: '.env', isOptional: true);

    return AppEnvironment(
      geminiApiKey: dotenv.maybeGet('GEMINI_API_KEY')?.trim(),
      summaryModel: dotenv.maybeGet(
        'GEMINI_SUMMARY_MODEL',
        fallback: 'gemini-2.5-flash',
      )!,
      proxyUrl: dotenv.maybeGet('REVERB_PROXY_URL')?.trim(),
    );
  }
}
