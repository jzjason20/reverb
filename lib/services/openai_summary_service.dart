import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/memory_entry.dart';

abstract class TranscriptSummaryService {
  bool get isConfigured;
  Future<String?> summarize(MemoryEntry entry);
}

class OpenAiSummaryService implements TranscriptSummaryService {
  OpenAiSummaryService({
    required AppEnvironment environment,
    http.Client? client,
  }) : _environment = environment,
       _client = client ?? http.Client();

  final AppEnvironment _environment;
  final http.Client _client;

  @override
  bool get isConfigured => _environment.hasOpenAiKey;

  @override
  Future<String?> summarize(MemoryEntry entry) async {
    if (!isConfigured) {
      return null;
    }

    try {
      final response = await _client.post(
        Uri.https('api.openai.com', '/v1/responses'),
        headers: <String, String>{
          'Authorization': 'Bearer ${_environment.openAiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, Object?>{
          'model': _environment.summaryModel,
          'instructions':
              'Summarize the transcript into one concise line for a memory feed. Return plain text only.',
          'input':
              'Category: ${entry.type.name}\nTranscript: ${entry.transcript}',
          'max_output_tokens': 60,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return _extractOutputText(payload);
    } catch (_) {
      return null;
    }
  }

  Future<String?> transcribeAudioFile(
    String filePath, {
    String? language,
  }) async {
    if (!isConfigured) {
      return null;
    }

    try {
      final request =
          http.MultipartRequest(
              'POST',
              Uri.https('api.openai.com', '/v1/audio/transcriptions'),
            )
            ..headers['Authorization'] = 'Bearer ${_environment.openAiApiKey}'
            ..fields['model'] = _environment.transcriptionModel;

      if (language != null && language.trim().isNotEmpty) {
        request.fields['language'] = language.trim();
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final text = payload['text'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _extractOutputText(Map<String, dynamic> payload) {
    final direct = payload['output_text'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final output = payload['output'];
    if (output is! List) {
      return null;
    }

    for (final item in output) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is! Map<String, dynamic>) {
          continue;
        }
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }

    return null;
  }
}
