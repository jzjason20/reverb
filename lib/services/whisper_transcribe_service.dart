import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Sends a recorded audio file to the Reverb proxy (/api/transcribe), which
/// forwards it to OpenAI Whisper and returns a plain-text transcript.
///
/// Returns null on any failure so the caller can fall back to device STT.
class WhisperTranscribeService {
  WhisperTranscribeService({
    required String proxyBaseUrl,
    http.Client? client,
  }) : _base = proxyBaseUrl.replaceAll(RegExp(r'/$'), ''),
       _client = client ?? http.Client();

  final String _base;
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  Future<String?> transcribe(String audioFilePath) async {
    try {
      final file = File(audioFilePath);
      if (!file.existsSync()) return null;

      final bytes = await file.readAsBytes();
      final rawName = audioFilePath.split('/').last;
      final fileName = rawName.contains('.') ? rawName : '$rawName.m4a';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/api/transcribe'),
      )
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName,
            contentType: MediaType('audio', 'm4a'),
          ),
        )
        ..fields['model'] = 'whisper-1';

      final streamed = await _client.send(request).timeout(_timeout);
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final text = (json['text'] as String?)?.trim();
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (_) {
      return null;
    }
  }
}
