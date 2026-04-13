import 'package:flutter/foundation.dart';

import '../models/memory_entry.dart';
import '../repositories/memory_repository.dart';
import '../services/gemini_summary_service.dart';
import '../services/memory_processor.dart';
import '../services/reminder_scheduler.dart';

enum FeedFilter { all, todos, ideas, thoughts }

class ReverbController extends ChangeNotifier {
  ReverbController({
    required MemoryRepository repository,
    required MemoryProcessor processor,
    required ReminderScheduler reminderScheduler,
    required TranscriptSummaryService summaryService,
  }) : _repository = repository,
       _processor = processor,
       _reminderScheduler = reminderScheduler,
       _summaryService = summaryService;

  final MemoryRepository _repository;
  final MemoryProcessor _processor;
  final ReminderScheduler _reminderScheduler;
  final TranscriptSummaryService _summaryService;

  List<MemoryEntry> _entries = const [];
  FeedFilter _activeFilter = FeedFilter.all;
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _lastErrorMessage;

  List<MemoryEntry> get entries => List.unmodifiable(_entries);
  FeedFilter get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  bool get remoteSummaryEnabled => _summaryService.isConfigured;
  String? get lastErrorMessage => _lastErrorMessage;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<MemoryEntry> get visibleEntries {
    var liveEntries = _entries.where((entry) => !entry.isDeleted).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      liveEntries = liveEntries.where((entry) {
        return entry.summary.toLowerCase().contains(q) ||
            entry.transcript.toLowerCase().contains(q) ||
            (entry.taskTitle?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    switch (_activeFilter) {
      case FeedFilter.all:
        return liveEntries;
      case FeedFilter.todos:
        return liveEntries
            .where((entry) => entry.type == MemoryType.todo)
            .toList();
      case FeedFilter.ideas:
        return liveEntries
            .where((entry) => entry.type == MemoryType.idea)
            .toList();
      case FeedFilter.thoughts:
        return liveEntries
            .where((entry) => entry.type == MemoryType.thought)
            .toList();
    }
  }

  List<MemoryEntry> get upcomingReminders {
    final now = DateTime.now();
    final reminders =
        _entries
            .where(
              (entry) =>
                  !entry.isDeleted &&
                  entry.type == MemoryType.reminder &&
                  entry.triggerTime != null &&
                  entry.triggerTime!.isAfter(now),
            )
            .toList()
          ..sort((left, right) {
            return left.triggerTime!.compareTo(right.triggerTime!);
          });
    return reminders.take(3).toList();
  }

  int get openTodoCount {
    return _entries.where((entry) {
      return !entry.isDeleted &&
          entry.type == MemoryType.todo &&
          !entry.isComplete;
    }).length;
  }

  int countFor(MemoryType type) {
    return _entries
        .where((entry) => !entry.isDeleted && entry.type == type)
        .length;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _entries = await _repository.fetchEntries();

    _isLoading = false;
    notifyListeners();
  }

  void selectFilter(FeedFilter filter) {
    if (_activeFilter == filter) {
      return;
    }

    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> captureTranscript(String transcript) async {
    if (transcript.trim().isEmpty) {
      return;
    }

    _isProcessing = true;
    _lastErrorMessage = null;
    notifyListeners();

    try {
      // 1. Always build a complete, valid entry using deterministic rules first.
      //    This is the guaranteed fallback — it works 100% offline.
      var entry = _processor.processTranscript(transcript);

      // 2. Attempt AI enrichment (classification + summary + taskTitle + time).
      //    If offline, timed-out, or API key missing, enrich() returns null and
      //    we proceed with the deterministic entry unchanged.
      final ai = await _summaryService.enrich(transcript, entry.createdAt);
      if (ai != null) {
        var aiType = ai.type ?? entry.type;
        var aiTaskTitle = ai.taskTitle ?? entry.taskTitle;

        // Resolve AI-supplied reminder time from ISO string.
        DateTime? aiTriggerTime = entry.triggerTime;
        if (aiType == MemoryType.reminder && ai.triggerTimeIso != null) {
          aiTriggerTime =
              DateTime.tryParse(ai.triggerTimeIso!) ?? entry.triggerTime;
        }

        // Apply the same safety rule as the deterministic path: a reminder
        // without a resolvable time is demoted to a todo.
        if (aiType == MemoryType.reminder && aiTriggerTime == null) {
          aiType = MemoryType.todo;
        }

        // For non-todo/reminder types taskTitle is meaningless.
        if (aiType != MemoryType.todo && aiType != MemoryType.reminder) {
          aiTaskTitle = null;
        }

        entry = entry.copyWith(
          type: aiType,
          summary: ai.summary ?? entry.summary,
          taskTitle: aiTaskTitle,
          triggerTime: aiTriggerTime,
          metadata: <String, Object?>{
            ...entry.metadata,
            'summary_provider': 'gemini',
            'classification_provider': 'gemini',
          },
        );
      }

      await _repository.upsertEntry(entry);
      await _reminderScheduler.scheduleReminder(entry);
      _entries = await _repository.fetchEntries();
    } catch (_) {
      _lastErrorMessage = 'Could not process that memory yet.';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> toggleTodo(String entryId, bool isComplete) async {
    final current = _entries.where((entry) => entry.id == entryId).firstOrNull;
    if (current == null) {
      return;
    }

    final updated = current.copyWith(
      isComplete: isComplete,
      updatedAt: DateTime.now(),
      version: current.version + 1,
      syncStatus: SyncStatus.pendingUpload,
    );

    await _repository.upsertEntry(updated);
    _entries = await _repository.fetchEntries();
    notifyListeners();
  }

  Future<void> deleteEntry(String entryId) async {
    final current = _entries.where((entry) => entry.id == entryId).firstOrNull;
    if (current == null || current.isDeleted) {
      return;
    }

    final deletedEntry = current.copyWith(
      updatedAt: DateTime.now(),
      deletedAt: DateTime.now(),
      version: current.version + 1,
      syncStatus: SyncStatus.pendingDelete,
      metadata: <String, Object?>{...current.metadata, 'deleted_locally': true},
    );

    await _repository.upsertEntry(deletedEntry);
    await _reminderScheduler.cancelReminder(current);
    _entries = await _repository.fetchEntries();
    notifyListeners();
  }
}
