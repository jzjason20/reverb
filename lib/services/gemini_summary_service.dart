import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/memory_entry.dart';

/// Result of an AI enrichment pass. Every field is nullable — a null value
/// means "use the deterministic fallback for this field".
class GeminiEnrichmentResult {
  const GeminiEnrichmentResult({
    this.type,
    this.summary,
    this.taskTitle,
    this.triggerTimeIso,
  });

  final MemoryType? type;
  final String? summary;
  final String? taskTitle;

  /// ISO 8601 datetime string resolved from natural language, e.g. "tomorrow
  /// at 3pm" → "2026-04-14T15:00:00". Null when no reminder time was found.
  final String? triggerTimeIso;
}

abstract class TranscriptSummaryService {
  bool get isConfigured;

  /// Legacy single-field summary. Kept for test compatibility.
  Future<String?> summarize(MemoryEntry entry);

  /// Single round-trip that returns classification + summary + task metadata.
  /// Returns null when offline, timed-out, or Gemini is not configured — the
  /// caller must fall back to deterministic results in that case.
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt,
  ) async => null;
}

class GeminiSummaryService implements TranscriptSummaryService {
  GeminiSummaryService({
    required AppEnvironment environment,
    http.Client? client,
  }) : _environment = environment,
       _client = client ?? http.Client();

  final AppEnvironment _environment;
  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  @override
  bool get isConfigured => _environment.hasGeminiKey;

  // ── Legacy method kept for existing tests ──────────────────────────────────
  @override
  Future<String?> summarize(MemoryEntry entry) async {
    final result = await enrich(entry.transcript, entry.createdAt);
    return result?.summary;
  }

  // ── Primary enrichment call ────────────────────────────────────────────────
  @override
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt,
  ) async {
    if (!isConfigured) return null;

    try {
      final apiKey = _environment.geminiApiKey!;
      final model = _environment.summaryModel;

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "system_instruction": {
                "parts": [
                  {
                    "text":
                        """You analyze voice notes for a personal memory app.
Return ONLY valid JSON matching this exact schema — no markdown, no explanation:
{
  "type": "thought" | "todo" | "idea" | "reminder",
  "summary": "<one crisp sentence, max 80 chars, no emoji, no quotes>",
  "taskTitle": "<cleaned task phrase if type is todo or reminder, otherwise null>",
  "triggerTimeIso": "<ISO 8601 datetime if type is reminder with a resolvable time, otherwise null>"
}

Classification guide:
- reminder: user explicitly wants to be notified at a future time
- todo: action or task with no specific time ("need to", "should", "pick up", "call", "buy")
- idea: creative, speculative, or invention-style thought ("what if", "idea:", "could build")
- thought: general observation, reflection, or note that fits none of the above""",
                  },
                ],
              },
              "contents": [
                {
                  "parts": [
                    {
                      "text":
                          "Captured at: ${capturedAt.toIso8601String()}\nTranscript: $transcript",
                    },
                  ],
                },
              ],
              "generationConfig": {
                "maxOutputTokens": 150,
                "responseMimeType": "application/json",
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = payload['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) return null;

      final raw = parts.first['text'] as String?;
      if (raw == null || raw.trim().isEmpty) return null;

      final json = jsonDecode(raw.trim()) as Map<String, dynamic>;

      final typeStr = json['type'] as String?;
      final MemoryType? parsedType = switch (typeStr) {
        'todo' => MemoryType.todo,
        'idea' => MemoryType.idea,
        'reminder' => MemoryType.reminder,
        'thought' => MemoryType.thought,
        _ => null,
      };

      final summary = (json['summary'] as String?)?.trim();
      final taskTitle = (json['taskTitle'] as String?)?.trim();
      final triggerTimeIso = (json['triggerTimeIso'] as String?)?.trim();

      return GeminiEnrichmentResult(
        type: parsedType,
        summary: (summary != null && summary.isNotEmpty) ? summary : null,
        taskTitle: (taskTitle != null && taskTitle.isNotEmpty)
            ? taskTitle
            : null,
        triggerTimeIso: (triggerTimeIso != null && triggerTimeIso.isNotEmpty)
            ? triggerTimeIso
            : null,
      );
    } catch (_) {
      // Network error, timeout, JSON parse failure, etc. — all safe to ignore.
      return null;
    }
  }
}
