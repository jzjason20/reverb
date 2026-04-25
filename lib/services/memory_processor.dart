import '../models/memory_entry.dart';

class MemoryProcessor {
  static final RegExp _splitPattern = RegExp(
    r'\s*(?:,|;|\band\b|\balso\b|\bthen\b)\s*',
    caseSensitive: false,
  );

  static final RegExp _todoLeadPattern = RegExp(
    r"^(?:remind me(?: to)?|don't forget to|todo[:\s-]*|i need to|i should|i have to|need to|should|have to|gotta|i gotta|must|remember to)\b",
    caseSensitive: false,
  );

  static final RegExp _todoVerbPattern = RegExp(
    r'^(?:call|buy|email|text|message|send|pay|schedule|book|submit|review|follow up|follow-up|fix|update|renew|order|clean|plan|write|finish|pick up|pick-up|reply|check|cancel|confirm|reschedule|ship|make|draft|file)\b',
    caseSensitive: false,
  );

  static final RegExp _reflectivePattern = RegExp(
    r'^(?:need to remember that|remember that|remember when|i noticed|i realized|i learned|i have learned)\b',
    caseSensitive: false,
  );

  MemoryEntry processTranscript(String transcript, {DateTime? now}) {
    return processTranscriptEntries(transcript, now: now).first;
  }

  List<MemoryEntry> processTranscriptEntries(String transcript, {DateTime? now}) {
    final capturedAt = now ?? DateTime.now();
    final normalized = transcript.trim();
    final segments = _splitTranscript(normalized);
    final sharedDueTime = _extractDueTime(normalized, capturedAt);

    return [
      for (var index = 0; index < segments.length; index++)
        _buildEntry(
          segments[index],
          capturedAt.add(Duration(microseconds: index)),
          inheritedTriggerTime: sharedDueTime,
        ),
    ];
  }

  MemoryEntry _buildEntry(
    String transcript,
    DateTime capturedAt, {
    DateTime? inheritedTriggerTime,
  }) {
    final normalized = transcript.trim();
    var type = _classify(normalized);
    final triggerTime = type == MemoryType.todo
        ? (_extractDueTime(normalized, capturedAt) ?? inheritedTriggerTime)
        : null;

    final taskTitle = type == MemoryType.todo
        ? _extractTaskTitle(normalized)
        : null;

    return MemoryEntry(
      id: _buildId(capturedAt),
      transcript: normalized,
      summary: _summarize(
        transcript: normalized,
        type: type,
        taskTitle: taskTitle,
      ),
      createdAt: capturedAt,
      updatedAt: capturedAt,
      type: type,
      taskTitle: taskTitle,
      triggerTime: triggerTime,
      priority: MemoryPriority.none,
      version: 1,
      syncStatus: SyncStatus.localOnly,
      tags: const ['others'],
      metadata: <String, Object?>{
        'schema_version': MemoryEntry.schemaVersion,
        'storage_strategy': 'local_first',
        'cloud_sync_enabled': false,
        'origin': 'local_capture',
        'summary_provider': 'deterministic',
      },
    );
  }

  List<MemoryEntry> buildSampleEntries() {
    final now = DateTime.now();
    return [
      processTranscript(
        'idea: a voice memory graph that surfaces repeated patterns before a weekly review',
        now: now.subtract(const Duration(hours: 2)),
      ),
      processTranscript(
        'i need to tighten the onboarding copy for reverb before tonight',
        now: now.subtract(const Duration(hours: 6)),
      ),
      processTranscript(
        'call mom tomorrow at 6 pm',
        now: now.subtract(const Duration(days: 1)),
      ),
      processTranscript(
        'Need to remember that the best moments to capture are usually right before context switches',
        now: now.subtract(const Duration(days: 2)),
      ),
    ];
  }

  MemoryType _classify(String transcript) {
    final lower = transcript.toLowerCase();

    if (_containsAny(lower, const [
      'idea:',
      'what if',
      'i could build',
      'this might be useful',
    ])) {
      return MemoryType.idea;
    }

    if (_reflectivePattern.hasMatch(lower)) {
      return MemoryType.braindump;
    }

    if (_todoLeadPattern.hasMatch(lower) || _todoVerbPattern.hasMatch(lower)) {
      return MemoryType.todo;
    }

    return MemoryType.braindump;
  }

  List<String> _splitTranscript(String transcript) {
    if (_classify(transcript) != MemoryType.todo) {
      return [transcript.trim()];
    }

    if (!_splitPattern.hasMatch(transcript)) {
      return [transcript.trim()];
    }

    final parts = transcript
        .split(_splitPattern)
        .map(_normalizeSegment)
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (parts.length < 2) {
      return [transcript.trim()];
    }

    final todoCount = parts.where((part) => _classify(part) == MemoryType.todo).length;
    if (todoCount < 2) {
      return [transcript.trim()];
    }

    return parts;
  }

  String _normalizeSegment(String segment) {
    return segment
        .replaceFirst(RegExp(r'^(?:and|also|then)\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _containsAny(String value, List<String> triggers) {
    return triggers.any(value.contains);
  }

  String _summarize({
    required String transcript,
    required MemoryType type,
    required String? taskTitle,
  }) {
    if (taskTitle != null && taskTitle.isNotEmpty) {
      if (type == MemoryType.todo) {
        return taskTitle;
      }
    }

    final compact = transcript.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 72) {
      return _sentenceCase(compact);
    }
    return '${_sentenceCase(compact.substring(0, 69))}...';
  }

  String _extractTaskTitle(String transcript) {
    var task = transcript.toLowerCase().trim();
    final patterns = <RegExp>[
      RegExp(r'^remind me to\s+'),
      RegExp(r'^remind me\s+'),
      RegExp(r"^don't forget to\s+"),
      RegExp(r'^i need to\s+'),
      RegExp(r'^i should\s+'),
      RegExp(r'^i have to\s+'),
      RegExp(r'^need to\s+'),
      RegExp(r'^should\s+'),
      RegExp(r'^have to\s+'),
      RegExp(r'^gotta\s+'),
      RegExp(r'^i gotta\s+'),
      RegExp(r'^must\s+'),
      RegExp(r'^remember to\s+'),
      RegExp(r'^todo[:\s-]*'),
    ];

    for (final pattern in patterns) {
      task = task.replaceFirst(pattern, '');
    }

    task = task
        .replaceAll(
          RegExp(
            r'\b(tomorrow|today|tonight|this evening|next week)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\bin\s+\d+\s+(minute|minutes|hour|hours|day|days)\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'\bat\s+\d{1,2}(:\d{2})?\s*(am|pm)?\b.*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[.!?]+$'), '')
        .trim();

    if (task.isEmpty) {
      return _sentenceCase(transcript);
    }

    return _sentenceCase(task);
  }

  DateTime? _extractDueTime(String transcript, DateTime now) {
    final lower = transcript.toLowerCase();

    final relativeMatch = RegExp(
      r'\bin\s+(\d+)\s+(minute|minutes|hour|hours|day|days)\b',
    ).firstMatch(lower);
    if (relativeMatch != null) {
      final amount = int.parse(relativeMatch.group(1)!);
      final unit = relativeMatch.group(2)!;
      if (unit.startsWith('minute')) {
        return now.add(Duration(minutes: amount));
      }
      if (unit.startsWith('hour')) {
        return now.add(Duration(hours: amount));
      }
      return now.add(Duration(days: amount));
    }

    if (lower.contains('tomorrow')) {
      final time = _extractClockTime(lower);
      final base = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(const Duration(days: 1));
      if (time == null) {
        return base.add(const Duration(hours: 9));
      }
      return DateTime(base.year, base.month, base.day, time.hour, time.minute);
    }

    if (lower.contains('today') || lower.contains('tonight')) {
      final time = _extractClockTime(lower) ?? const _ClockTime(18, 0);
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    final time = _extractClockTime(lower);
    if (time != null) {
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!candidate.isAfter(now)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    return null;
  }

  _ClockTime? _extractClockTime(String text) {
    final match = RegExp(
      r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    ).firstMatch(text);
    if (match == null) {
      return null;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final suffix = match.group(3);

    if (suffix == 'pm' && hour != 12) {
      hour += 12;
    } else if (suffix == 'am' && hour == 12) {
      hour = 0;
    }

    return _ClockTime(hour, minute);
  }

  String _buildId(DateTime now) {
    final micros = now.microsecondsSinceEpoch;
    return 'mem_$micros';
  }

  String _sentenceCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class _ClockTime {
  const _ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;
}
