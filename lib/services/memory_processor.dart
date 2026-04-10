import '../models/memory_entry.dart';

class MemoryProcessor {
  MemoryEntry processTranscript(String transcript, {DateTime? now}) {
    final capturedAt = now ?? DateTime.now();
    final normalized = transcript.trim();
    var type = _classify(normalized);
    var triggerTime = type == MemoryType.reminder
        ? _extractReminderTime(normalized, capturedAt)
        : null;

    if (type == MemoryType.reminder && triggerTime == null) {
      type = MemoryType.todo;
    }

    final taskTitle = type == MemoryType.todo || type == MemoryType.reminder
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
      version: 1,
      syncStatus: SyncStatus.localOnly,
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
        'remind me to call mom tomorrow at 6 pm',
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
      'remind me',
      'remind me to',
      'remind me at',
      'remind me in',
    ])) {
      return MemoryType.reminder;
    }

    if (_containsAny(lower, const [
      'i need to',
      'i should',
      'todo',
      "don't forget to",
    ])) {
      return MemoryType.todo;
    }

    if (_containsAny(lower, const [
      'idea:',
      'what if',
      'i could build',
      'this might be useful',
    ])) {
      return MemoryType.idea;
    }

    return MemoryType.thought;
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
      if (type == MemoryType.reminder) {
        return 'Reminder: $taskTitle';
      }
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
        .trim();

    if (task.isEmpty) {
      return _sentenceCase(transcript);
    }

    return _sentenceCase(task);
  }

  DateTime? _extractReminderTime(String transcript, DateTime now) {
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
