import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_environment.dart';
import '../models/memory_entry.dart';

/// Result of an AI enrichment pass. Every field is nullable — a null value
/// means "use the deterministic fallback for this field".
class GeminiEnrichmentResult {
  const GeminiEnrichmentResult({
    this.type,
    this.transcript,
    this.summary,
    this.taskTitle,
    this.triggerTimeIso,
    this.tags = const [],
  });

  final MemoryType? type;
  final String? transcript;
  final String? summary;
  final String? taskTitle;

  /// ISO 8601 datetime string resolved from natural language, e.g. "tomorrow
  /// at 3pm" → "2026-04-14T15:00:00". Null when no reminder time was found.
  final String? triggerTimeIso;

  /// AI-suggested tags from predefined set (uni, lexy, lifexp, reverb, random)
  final List<String> tags;
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

  /// Multi-entry enrichment that can extract multiple todos from a single
  /// voice note. Returns a list of enrichment results (can be 1+ entries).
  /// Returns null when offline, timed-out, or not configured — the caller
  /// must fall back to deterministic results in that case.
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
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

  // ── Primary enrichment call (legacy, returns first entry only) ────────────
  @override
  Future<GeminiEnrichmentResult?> enrich(
    String transcript,
    DateTime capturedAt,
  ) async {
    final results = await enrichMulti(transcript, capturedAt);
    return results?.firstOrNull;
  }

  // ── Multi-entry enrichment (primary implementation) ─────────────────────────
  @override
  Future<List<GeminiEnrichmentResult>?> enrichMulti(
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

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entries = json['entries'] as List<dynamic>?;

      if (entries == null || entries.isEmpty) {
        return null;
      }

      return entries.map((entry) {
        final entryMap = entry as Map<String, dynamic>;

        final typeStr = entryMap['type'] as String?;
        final MemoryType? parsedType = switch (typeStr) {
          'todo' => MemoryType.todo,
          'idea' => MemoryType.idea,
          'reminder' => MemoryType.todo,
          'thought' => MemoryType.braindump,
          'braindump' => MemoryType.braindump,
          _ => null,
        };

        final transcript = (entryMap['transcript'] as String?)?.trim();
        final summary = (entryMap['summary'] as String?)?.trim();
        final taskTitle = (entryMap['taskTitle'] as String?)?.trim();
        final triggerTimeIso = (entryMap['triggerTimeIso'] as String?)?.trim();
        final tags =
            (entryMap['tags'] as List<dynamic>?)
                ?.map((tag) => tag.toString())
                .toList() ??
            <String>[];

        return GeminiEnrichmentResult(
          type: parsedType,
          transcript: (transcript != null && transcript.isNotEmpty)
              ? transcript
              : null,
          summary: (summary != null && summary.isNotEmpty) ? summary : null,
          taskTitle: (taskTitle != null && taskTitle.isNotEmpty)
              ? taskTitle
              : null,
          triggerTimeIso: (triggerTimeIso != null && triggerTimeIso.isNotEmpty)
              ? triggerTimeIso
              : null,
          tags: tags,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
