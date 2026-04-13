import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  static const _timeout = Duration(seconds: 25);

  @override
  bool get isConfigured => _environment.hasProxy;

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
      final base = _environment.proxyUrl!.replaceAll(RegExp(r'/$'), '');
      final url = Uri.parse('$base/api/enrich');

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'transcript': transcript,
              'capturedAt': capturedAt.toIso8601String(),
            }),
          )
          .timeout(_timeout);

      debugPrint('[Enrich] status=${response.statusCode}');
      debugPrint('[Enrich] body=${response.body}');

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

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
    } catch (e, st) {
      debugPrint('[Enrich] error: $e\n$st');
      return null;
    }
  }
}
