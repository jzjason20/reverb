import 'package:flutter/foundation.dart';

import '../models/memory_entry.dart';
import '../repositories/memory_repository.dart';
import '../services/memory_processor.dart';
import '../services/openai_summary_service.dart';
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
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _lastErrorMessage;

  List<MemoryEntry> get entries => List.unmodifiable(_entries);
  FeedFilter get activeFilter => _activeFilter;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  bool get remoteSummaryEnabled => _summaryService.isConfigured;
  String? get lastErrorMessage => _lastErrorMessage;

  List<MemoryEntry> get visibleEntries {
    final liveEntries = _entries.where((entry) => !entry.isDeleted).toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

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
      var entry = _processor.processTranscript(transcript);
      final remoteSummary = await _summaryService.summarize(entry);
      if (remoteSummary != null && remoteSummary.trim().isNotEmpty) {
        entry = entry.copyWith(
          summary: remoteSummary.trim(),
          metadata: <String, Object?>{
            ...entry.metadata,
            'summary_provider': 'openai',
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
}
