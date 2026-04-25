import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/memory_entry.dart';
import '../models/tag_definition.dart';
import '../repositories/memory_repository.dart';
import '../services/gemini_summary_service.dart';
import '../services/memory_processor.dart';
import '../services/reminder_scheduler.dart';
import '../services/tag_manager.dart';

enum HomeTab { today, all, tags }

enum EntryTypeFilter { all, braindumps, ideas, todos }

enum DueDateShortcut { today, tomorrow, thisWeek }

class CaptureFeedback {
  const CaptureFeedback({
    required this.id,
    required this.entryCount,
    required this.todoCount,
  });

  final String id;
  final int entryCount;
  final int todoCount;

  String get message {
    if (todoCount > 1 && todoCount == entryCount) {
      return 'Created $todoCount todos from your voice note!';
    }

    return 'Split your voice note into $entryCount entries.';
  }
}

class ReverbController extends ChangeNotifier {
  ReverbController({
    required MemoryRepository repository,
    required MemoryProcessor processor,
    required ReminderScheduler reminderScheduler,
    required TranscriptSummaryService summaryService,
  }) : _repository = repository,
       _processor = processor,
       _reminderScheduler = reminderScheduler,
       _summaryService = summaryService,
       _tagManager = TagManager();

  final MemoryRepository _repository;
  final MemoryProcessor _processor;
  final ReminderScheduler _reminderScheduler;
  final TranscriptSummaryService _summaryService;
  final TagManager _tagManager;

  List<MemoryEntry> _entries = const [];
  List<TagDefinition> _tags = const [];
  HomeTab _activeTab = HomeTab.today;
  EntryTypeFilter _allFilter = EntryTypeFilter.all;
  EntryTypeFilter _tagViewFilter = EntryTypeFilter.all;
  final Set<String> _selectedAllTags = <String>{};
  String? _selectedTagId;
  final Set<String> _processingEntryIds = <String>{};
  String? _pendingDueDateEntryId;
  bool _isLoading = false;
  bool _isProcessing = false;
  String? _lastErrorMessage;
  CaptureFeedback? _latestCaptureFeedback;

  List<MemoryEntry> get entries => List.unmodifiable(_entries);
  List<TagDefinition> get tags => List.unmodifiable(_tags);
  HomeTab get activeTab => _activeTab;
  EntryTypeFilter get allFilter => _allFilter;
  EntryTypeFilter get tagViewFilter => _tagViewFilter;
  Set<String> get selectedTags => Set.unmodifiable(_selectedAllTags);
  String? get selectedTagId => _selectedTagId;
  TagDefinition? get selectedTag =>
      _tags.where((tag) => tag.id == _selectedTagId).firstOrNull;
  TagManager get tagManager => _tagManager;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  bool get remoteSummaryEnabled => _summaryService.isConfigured;
  String? get lastErrorMessage => _lastErrorMessage;
  CaptureFeedback? get latestCaptureFeedback => _latestCaptureFeedback;

  MemoryEntry? get pendingDueDateEntry {
    final entryId = _pendingDueDateEntryId;
    if (entryId == null) {
      return null;
    }

    return _entries.where((entry) => entry.id == entryId).firstOrNull;
  }

  bool isEntryProcessing(String entryId) {
    return _processingEntryIds.contains(entryId);
  }

  List<MemoryEntry> get todayEntries {
    final entries = _liveEntries.where((entry) {
      return entry.type == MemoryType.todo &&
          !entry.isComplete &&
          entry.triggerTime != null &&
          _isSameDay(entry.triggerTime!, DateTime.now());
    }).toList();

    entries.sort(_compareTodayEntries);
    return entries;
  }

  int get todayCount => todayEntries.length;

  List<MemoryEntry> get allEntries {
    return _applyFilters(
      _liveEntries,
      typeFilter: _allFilter,
      tagNames: _selectedAllTags,
    );
  }

  List<MemoryEntry> get tagEntries {
    final tag = selectedTag;
    if (tag == null) {
      return const [];
    }

    final scopedEntries = _liveEntries
        .where((entry) => entry.tags.contains(tag.name))
        .toList(growable: false);
    return _applyFilters(scopedEntries, typeFilter: _tagViewFilter);
  }

  int get openTodoCount {
    return _liveEntries.where((entry) {
      return entry.type == MemoryType.todo && !entry.isComplete;
    }).length;
  }

  int countFor(MemoryType type) {
    return _liveEntries.where((entry) => entry.type == type).length;
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    await _reloadState(notify: false);

    _isLoading = false;
    notifyListeners();
  }

  void selectTab(HomeTab tab) {
    if (_activeTab == tab) {
      return;
    }
    _activeTab = tab;
    notifyListeners();
  }

  void setAllFilter(EntryTypeFilter filter) {
    if (_allFilter == filter) {
      return;
    }
    _allFilter = filter;
    notifyListeners();
  }

  void setTagViewFilter(EntryTypeFilter filter) {
    if (_tagViewFilter == filter) {
      return;
    }
    _tagViewFilter = filter;
    notifyListeners();
  }

  void toggleTag(String tagName) {
    if (_selectedAllTags.contains(tagName)) {
      _selectedAllTags.remove(tagName);
    } else {
      _selectedAllTags.add(tagName);
    }
    notifyListeners();
  }

  void clearTagFilters() {
    if (_selectedAllTags.isEmpty) {
      return;
    }
    _selectedAllTags.clear();
    notifyListeners();
  }

  void selectTagScope(String? tagId) {
    if (_selectedTagId == tagId) {
      return;
    }
    _selectedTagId = tagId;
    notifyListeners();
  }

  void dismissDueDatePrompt() {
    if (_pendingDueDateEntryId == null) {
      return;
    }
    _pendingDueDateEntryId = null;
    notifyListeners();
  }

  Future<TagDefinition?> createTag(String rawName, {int? colorValue}) async {
    final normalized = _validateAndNormalizeTagName(rawName);
    if (normalized == null) {
      return null;
    }

    final existing = _tags.where((tag) => tag.name == normalized).firstOrNull;
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final tag = TagDefinition(
      id: _generateTagId(),
      name: normalized,
      colorValue: colorValue ?? _nextTagColorValue(),
      createdAt: now,
      updatedAt: now,
    );

    await _repository.upsertTag(tag);
    await _reloadState(notify: false);
    notifyListeners();
    return tag;
  }

  Future<void> renameTag(String tagId, String rawName) async {
    final current = _tags.where((tag) => tag.id == tagId).firstOrNull;
    if (current == null || current.isProtected) {
      return;
    }

    final normalized = _validateAndNormalizeTagName(rawName);
    if (normalized == null || normalized == current.name) {
      return;
    }

    final duplicate = _tags
        .where((tag) => tag.name == normalized && tag.id != tagId)
        .firstOrNull;
    if (duplicate != null) {
      _lastErrorMessage = 'That tag name already exists.';
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    await _repository.upsertTag(
      current.copyWith(name: normalized, updatedAt: now),
    );

    for (final entry in _entries.where(
      (item) => item.tags.contains(current.name),
    )) {
      final newTags = entry.tags
          .map((tag) => tag == current.name ? normalized : tag)
          .toList(growable: false);
      await _repository.upsertEntry(
        entry.copyWith(
          tags: _normalizeAssignedTags(newTags),
          updatedAt: now,
          version: entry.version + 1,
          syncStatus: SyncStatus.pendingUpload,
        ),
      );
    }

    if (_selectedAllTags.remove(current.name)) {
      _selectedAllTags.add(normalized);
    }

    await _reloadState(notify: false);
    notifyListeners();
  }

  Future<void> updateTagColor(String tagId, int colorValue) async {
    final current = _tags.where((tag) => tag.id == tagId).firstOrNull;
    if (current == null) {
      return;
    }

    await _repository.upsertTag(
      current.copyWith(colorValue: colorValue, updatedAt: DateTime.now()),
    );
    await _reloadState(notify: false);
    notifyListeners();
  }

  Future<void> deleteTag(String tagId) async {
    final current = _tags.where((tag) => tag.id == tagId).firstOrNull;
    if (current == null || current.isProtected) {
      return;
    }

    final now = DateTime.now();
    for (final entry in _entries.where(
      (item) => item.tags.contains(current.name),
    )) {
      final nextTags = entry.tags
          .where((tag) => tag != current.name)
          .toList(growable: false);
      await _repository.upsertEntry(
        entry.copyWith(
          tags: _normalizeAssignedTags(nextTags),
          updatedAt: now,
          version: entry.version + 1,
          syncStatus: SyncStatus.pendingUpload,
        ),
      );
    }

    await _repository.deleteTag(tagId);
    _selectedAllTags.remove(current.name);
    if (_selectedTagId == tagId) {
      _selectedTagId = null;
    }
    await _reloadState(notify: false);
    notifyListeners();
  }

  Future<int> captureTranscript(String transcript) async {
    final normalized = transcript.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    _isProcessing = true;
    _lastErrorMessage = null;
    _latestCaptureFeedback = null;
    notifyListeners();

    try {
      final captureGroupId = _generateCaptureGroupId();
      final processedEntries = _processor.processTranscriptEntries(normalized);
      final processed = processedEntries.first;
      final baseEntry = processed.copyWith(
        tags: _resolveAssignedTags(
          preferredTags: processed.tags,
          transcript: processed.transcript,
          source: 'capture-base',
        ),
        metadata: <String, Object?>{
          ...processed.metadata,
          'capture_group_id': captureGroupId,
          'ai_state': 'processing',
        },
      );

      await _repository.upsertEntry(baseEntry);
      _processingEntryIds.add(baseEntry.id);
      await _reloadState(notify: false);

      unawaited(_enrichCapture(baseEntry, normalized, processedEntries));
      return 1;
    } catch (_) {
      _lastErrorMessage = 'Could not process that memory yet.';
      return 0;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> applyDueDateShortcut(DueDateShortcut shortcut) async {
    final entry = pendingDueDateEntry;
    if (entry == null) {
      return;
    }

    final dueTime = _resolveShortcut(shortcut, DateTime.now());
    final updated = entry.copyWith(
      triggerTime: dueTime,
      updatedAt: DateTime.now(),
      version: entry.version + 1,
      syncStatus: SyncStatus.pendingUpload,
    );

    await _repository.upsertEntry(updated);
    await _reminderScheduler.scheduleReminder(updated);
    _pendingDueDateEntryId = null;
    await _reloadState(notify: false);
    notifyListeners();
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
    if (isComplete) {
      await _reminderScheduler.cancelReminder(updated);
    } else {
      await _reminderScheduler.scheduleReminder(updated);
    }
    await _reloadState(notify: false);
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
    await _reloadState(notify: false);
    notifyListeners();
  }

  Future<void> updateEntryTags(String entryId, List<String> tags) async {
    final current = _entries.where((entry) => entry.id == entryId).firstOrNull;
    if (current == null || current.isDeleted) {
      return;
    }

    final updated = current.copyWith(
      tags: _normalizeAssignedTags(tags),
      updatedAt: DateTime.now(),
      version: current.version + 1,
      syncStatus: SyncStatus.pendingUpload,
    );

    await _repository.upsertEntry(updated);
    await _reloadState(notify: false);
    notifyListeners();
  }

  Future<void> updateEntry({
    required String entryId,
    required MemoryType type,
    required String transcript,
    String? taskTitle,
    List<String>? tags,
    MemoryPriority? priority,
    DateTime? dueAt,
  }) async {
    final current = _entries.where((entry) => entry.id == entryId).firstOrNull;
    if (current == null || current.isDeleted) {
      return;
    }

    final normalizedTranscript = transcript.trim();
    final normalizedTaskTitle = type == MemoryType.todo
        ? _cleanTaskTitle((taskTitle ?? normalizedTranscript).trim())
        : null;
    final nextSummary = type == MemoryType.todo
        ? (normalizedTaskTitle!.isEmpty
              ? _summarizeContent(normalizedTranscript)
              : normalizedTaskTitle)
        : _summarizeContent(normalizedTranscript);

    final updated = current.copyWith(
      transcript: normalizedTranscript,
      summary: nextSummary,
      type: type,
      taskTitle: normalizedTaskTitle,
      triggerTime: type == MemoryType.todo ? dueAt : null,
      priority: type == MemoryType.todo
          ? (priority ?? current.priority)
          : MemoryPriority.none,
      tags: _normalizeAssignedTags(tags ?? current.tags),
      updatedAt: DateTime.now(),
      version: current.version + 1,
      syncStatus: SyncStatus.pendingUpload,
    );

    await _repository.upsertEntry(updated);
    if (updated.type == MemoryType.todo) {
      await _reminderScheduler.scheduleReminder(updated);
    } else {
      await _reminderScheduler.cancelReminder(updated);
    }

    if (_pendingDueDateEntryId == entryId && updated.triggerTime != null) {
      _pendingDueDateEntryId = null;
    }

    await _reloadState(notify: false);
    notifyListeners();
  }

  List<MemoryEntry> get _liveEntries {
    final entries = _entries.where((entry) => !entry.isDeleted).toList();
    entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return entries;
  }

  Future<void> _reloadState({bool notify = true}) async {
    _entries = await _repository.fetchEntries();
    _tags = await _repository.fetchTags();
    _tagManager.updateFromEntries(_tags.map((tag) => tag.name));
    _selectedAllTags.removeWhere(
      (name) => !_tags.any((tag) => tag.name == name),
    );
    if (_selectedTagId != null &&
        !_tags.any((tag) => tag.id == _selectedTagId)) {
      _selectedTagId = null;
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _enrichCapture(
    MemoryEntry baseEntry,
    String transcript,
    List<MemoryEntry> processedEntries,
  ) async {
    try {
      final deterministicEntries = _buildDeterministicCaptureEntries(
        baseEntry,
        processedEntries,
      );
      final aiResults = await _summaryService.enrichMulti(
        transcript,
        baseEntry.createdAt,
        availableTags: _availableAiTags(),
      );
      _logTagDebug(
        'available=${_availableAiTags()} aiReturned=${aiResults?.map((result) => result.tags).toList() ?? const []}',
      );
      final captureContextTags = _resolveAssignedTags(
        preferredTags: baseEntry.tags,
        transcript: transcript,
        source: 'capture-context',
      );

      if (aiResults == null || aiResults.isEmpty) {
        final enrichedDeterministicEntries = _inheritCaptureTags(
          deterministicEntries,
          captureContextTags,
        );
        await _persistCaptureEntries(enrichedDeterministicEntries);
        _setCaptureFeedback(enrichedDeterministicEntries);
        _pendingDueDateEntryId = _firstTodoMissingDue(
          enrichedDeterministicEntries,
        )?.id;
        return;
      }

      if (_shouldPreferDeterministicSplit(aiResults, deterministicEntries)) {
        final enrichedDeterministicEntries = _inheritCaptureTags(
          deterministicEntries,
          captureContextTags,
        );
        await _persistCaptureEntries(enrichedDeterministicEntries);
        _setCaptureFeedback(enrichedDeterministicEntries);
        _pendingDueDateEntryId = _firstTodoMissingDue(
          enrichedDeterministicEntries,
        )?.id;
        return;
      }

      final createdEntries = <MemoryEntry>[];
      final primaryEntry = _applyAiResult(
        baseEntry: baseEntry,
        result: aiResults.first,
        entryId: baseEntry.id,
        preserveBaseTaskTitle: true,
        preferEntrySpecificTranscript: aiResults.length > 1,
        inheritedTags: captureContextTags,
      );
      await _repository.upsertEntry(primaryEntry);
      await _reminderScheduler.scheduleReminder(primaryEntry);
      createdEntries.add(primaryEntry);

      for (final aiResult in aiResults.skip(1)) {
        final derivedEntry = _applyAiResult(
          baseEntry: baseEntry,
          result: aiResult,
          entryId: _generateEntryId(),
          preserveBaseTaskTitle: false,
          preferEntrySpecificTranscript: true,
          inheritedTags: captureContextTags,
        );
        await _repository.upsertEntry(derivedEntry);
        await _reminderScheduler.scheduleReminder(derivedEntry);
        createdEntries.add(derivedEntry);
      }

      _setCaptureFeedback(createdEntries);

      _pendingDueDateEntryId = _firstTodoMissingDue(createdEntries)?.id;
    } catch (_) {
      final deterministicEntries = _inheritCaptureTags(
        _buildDeterministicCaptureEntries(baseEntry, processedEntries),
        _resolveAssignedTags(
          preferredTags: baseEntry.tags,
          transcript: transcript,
          source: 'capture-context-error',
        ),
      );
      await _persistCaptureEntries(deterministicEntries);
      _setCaptureFeedback(deterministicEntries);
      _pendingDueDateEntryId = _firstTodoMissingDue(deterministicEntries)?.id;
    } finally {
      _processingEntryIds.remove(baseEntry.id);
      await _reloadState(notify: false);
      notifyListeners();
    }
  }

  MemoryEntry _markAiComplete(MemoryEntry entry) {
    return entry.copyWith(
      tags: _resolveAssignedTags(
        preferredTags: entry.tags,
        transcript: entry.transcript,
        source: 'complete-entry',
      ),
      metadata: <String, Object?>{...entry.metadata, 'ai_state': 'complete'},
    );
  }

  MemoryEntry _applyAiResult({
    required MemoryEntry baseEntry,
    required GeminiEnrichmentResult result,
    required String entryId,
    required bool preserveBaseTaskTitle,
    required bool preferEntrySpecificTranscript,
    List<String> inheritedTags = const <String>[],
  }) {
    final resolvedType = result.type ?? baseEntry.type;
    final dueAt = result.triggerTimeIso == null
        ? (preserveBaseTaskTitle ? baseEntry.triggerTime : null)
        : DateTime.tryParse(result.triggerTimeIso!);

    final taskTitle = resolvedType == MemoryType.todo
        ? _cleanTaskTitle(
            result.taskTitle ??
                (preserveBaseTaskTitle ? baseEntry.taskTitle : null) ??
                result.summary ??
                baseEntry.summary,
          )
        : null;

    final summary = result.summary?.trim().isNotEmpty == true
        ? result.summary!.trim()
        : (taskTitle ?? baseEntry.summary);
    final focusedTranscript = _resolveFocusedTranscript(
      baseEntry: baseEntry,
      result: result,
      taskTitle: taskTitle,
      summary: summary,
      preferEntrySpecificTranscript: preferEntrySpecificTranscript,
    );

    return baseEntry.copyWith(
      id: entryId,
      updatedAt: DateTime.now(),
      transcript: focusedTranscript,
      type: resolvedType,
      summary: summary,
      taskTitle: taskTitle,
      triggerTime: dueAt,
      tags: _resolveAssignedTags(
        preferredTags: result.tags,
        transcript: focusedTranscript,
        source: entryId == baseEntry.id ? 'ai-primary' : 'ai-derived',
        inheritedTags: inheritedTags,
      ),
      priority: MemoryPriority.none,
      metadata: <String, Object?>{
        ...baseEntry.metadata,
        'ai_state': 'complete',
        'summary_provider': 'gemini',
        'classification_provider': 'gemini',
        if (entryId != baseEntry.id) 'derived_from_entry_id': baseEntry.id,
      },
    );
  }

  List<MemoryEntry> _buildDeterministicCaptureEntries(
    MemoryEntry baseEntry,
    List<MemoryEntry> processedEntries,
  ) {
    final captureGroupId = baseEntry.metadata['capture_group_id'];
    final entries = <MemoryEntry>[_markAiComplete(baseEntry)];

    for (final entry in processedEntries.skip(1)) {
      entries.add(
        entry.copyWith(
          tags: _resolveAssignedTags(
            preferredTags: entry.tags,
            transcript: entry.transcript,
            source: 'deterministic-derived',
          ),
          metadata: <String, Object?>{
            ...entry.metadata,
            'capture_group_id': captureGroupId,
            'ai_state': 'complete',
            'derived_from_entry_id': baseEntry.id,
          },
        ),
      );
    }

    return entries;
  }

  Future<void> _persistCaptureEntries(List<MemoryEntry> entries) async {
    for (final entry in entries) {
      await _repository.upsertEntry(entry);
      await _reminderScheduler.scheduleReminder(entry);
    }
  }

  List<MemoryEntry> _inheritCaptureTags(
    List<MemoryEntry> entries,
    List<String> captureContextTags,
  ) {
    if (_isOnlyFallbackTag(captureContextTags)) {
      return entries;
    }

    return entries
        .map(
          (entry) => entry.copyWith(
            tags: _resolveAssignedTags(
              preferredTags: entry.tags,
              transcript: entry.transcript,
              source: 'capture-inherit',
              inheritedTags: captureContextTags,
            ),
          ),
        )
        .toList(growable: false);
  }

  bool _shouldPreferDeterministicSplit(
    List<GeminiEnrichmentResult> aiResults,
    List<MemoryEntry> deterministicEntries,
  ) {
    if (deterministicEntries.length <= 1) {
      return false;
    }

    final deterministicTodoCount = deterministicEntries
        .where((entry) => entry.type == MemoryType.todo)
        .length;
    return deterministicTodoCount == deterministicEntries.length &&
        aiResults.length < deterministicEntries.length;
  }

  void _setCaptureFeedback(List<MemoryEntry> entries) {
    final todoCount = entries
        .where((entry) => entry.type == MemoryType.todo)
        .length;
    if (entries.length > 1) {
      _latestCaptureFeedback = CaptureFeedback(
        id: _generateCaptureFeedbackId(),
        entryCount: entries.length,
        todoCount: todoCount,
      );
    }
  }

  String _resolveFocusedTranscript({
    required MemoryEntry baseEntry,
    required GeminiEnrichmentResult result,
    required String? taskTitle,
    required String summary,
    required bool preferEntrySpecificTranscript,
  }) {
    if (!preferEntrySpecificTranscript) {
      return baseEntry.transcript;
    }

    final transcript = (result.transcript ?? taskTitle ?? summary).trim();
    if (transcript.isEmpty) {
      return baseEntry.transcript;
    }
    return transcript;
  }

  List<MemoryEntry> _applyFilters(
    List<MemoryEntry> source, {
    required EntryTypeFilter typeFilter,
    Set<String> tagNames = const <String>{},
  }) {
    var filtered = source;

    if (tagNames.isNotEmpty) {
      filtered = filtered
          .where((entry) => entry.tags.any(tagNames.contains))
          .toList(growable: false);
    }

    filtered = filtered
        .where((entry) => _matchesTypeFilter(entry, typeFilter))
        .toList(growable: false);
    filtered.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return filtered;
  }

  bool _matchesTypeFilter(MemoryEntry entry, EntryTypeFilter filter) {
    return switch (filter) {
      EntryTypeFilter.all => true,
      EntryTypeFilter.braindumps => entry.type == MemoryType.braindump,
      EntryTypeFilter.ideas => entry.type == MemoryType.idea,
      EntryTypeFilter.todos => entry.type == MemoryType.todo,
    };
  }

  List<String> _normalizeAssignedTags(List<String> tags) {
    final knownNames = _tags.map((tag) => tag.name).toSet();
    final normalized =
        tags
            .map(TagManager.normalizeTag)
            .where(knownNames.contains)
            .toSet()
            .toList()
          ..sort();

    if (normalized.length > 1) {
      normalized.remove(TagDefinition.othersName);
    }

    if (normalized.isEmpty) {
      return const [TagDefinition.othersName];
    }

    return normalized;
  }

  List<String> _resolveAssignedTags({
    required List<String> preferredTags,
    required String transcript,
    required String source,
    List<String> inheritedTags = const <String>[],
  }) {
    final normalizedPreferred = _normalizeAssignedTags(preferredTags);
    if (!_isOnlyFallbackTag(normalizedPreferred)) {
      _logTagDebug(
        '$source applied=$normalizedPreferred raw=$preferredTags text=${_shortLogText(transcript)}',
      );
      return normalizedPreferred;
    }

    final suggested = TagManager.suggestTags(transcript, _availableAiTags());
    final normalizedSuggested = _normalizeAssignedTags(suggested);
    if (!_isOnlyFallbackTag(normalizedSuggested)) {
      _logTagDebug(
        '$source fallback=$normalizedSuggested raw=$preferredTags text=${_shortLogText(transcript)}',
      );
      return normalizedSuggested;
    }

    final normalizedInherited = _normalizeAssignedTags(inheritedTags);
    if (!_isOnlyFallbackTag(normalizedInherited)) {
      _logTagDebug(
        '$source inherited=$normalizedInherited raw=$preferredTags text=${_shortLogText(transcript)}',
      );
      return normalizedInherited;
    }

    _logTagDebug(
      '$source no-tags raw=$preferredTags inherited=$inheritedTags available=${_availableAiTags()} text=${_shortLogText(transcript)}',
    );
    return normalizedPreferred;
  }

  List<String> _availableAiTags() {
    return _tags
        .where((tag) => tag.name != TagDefinition.othersName)
        .map((tag) => tag.name)
        .toList(growable: false);
  }

  bool _isOnlyFallbackTag(List<String> tags) {
    return tags.length == 1 && tags.single == TagDefinition.othersName;
  }

  void _logTagDebug(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[Reverb][tags] $message');
  }

  String _shortLogText(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 96) {
      return compact;
    }
    return '${compact.substring(0, 93)}...';
  }

  String? _validateAndNormalizeTagName(String rawName) {
    final error = TagManager.validateTagName(rawName);
    if (error != null) {
      _lastErrorMessage = error;
      notifyListeners();
      return null;
    }

    return TagManager.normalizeTag(rawName);
  }

  MemoryEntry? _firstTodoMissingDue(Iterable<MemoryEntry> entries) {
    return entries.where((entry) {
      return entry.type == MemoryType.todo &&
          !entry.isComplete &&
          entry.triggerTime == null;
    }).firstOrNull;
  }

  int _compareTodayEntries(MemoryEntry left, MemoryEntry right) {
    final priorityComparison = _priorityRank(
      right.priority,
    ).compareTo(_priorityRank(left.priority));
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final leftTime = left.triggerTime;
    final rightTime = right.triggerTime;
    if (leftTime == null && rightTime == null) {
      return right.createdAt.compareTo(left.createdAt);
    }
    if (leftTime == null) {
      return 1;
    }
    if (rightTime == null) {
      return -1;
    }
    return leftTime.compareTo(rightTime);
  }

  int _priorityRank(MemoryPriority priority) {
    return switch (priority) {
      MemoryPriority.high => 3,
      MemoryPriority.medium => 2,
      MemoryPriority.low => 1,
      MemoryPriority.none => 0,
    };
  }

  DateTime _resolveShortcut(DueDateShortcut shortcut, DateTime now) {
    final roundedHour = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(const Duration(hours: 1));
    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 9);

    return switch (shortcut) {
      DueDateShortcut.today => roundedHour,
      DueDateShortcut.tomorrow => tomorrowMorning,
      DueDateShortcut.thisWeek => _endOfWorkWeek(now),
    };
  }

  DateTime _endOfWorkWeek(DateTime date) {
    final daysUntilFriday = (DateTime.friday - date.weekday) % 7;
    final friday = DateTime(
      date.year,
      date.month,
      date.day + daysUntilFriday,
      17,
    );
    if (friday.isAfter(date)) {
      return friday;
    }
    return friday.add(const Duration(days: 7));
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _cleanTaskTitle(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return value;
    }
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  String _summarizeContent(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return '';
    }
    if (compact.length <= 72) {
      return '${compact[0].toUpperCase()}${compact.substring(1)}';
    }
    final snippet = compact.substring(0, 69).trimRight();
    return '${snippet[0].toUpperCase()}${snippet.substring(1)}...';
  }

  int _nextTagColorValue() {
    final colorIndex = _tags.length % TagManager.defaultColors.length;
    return TagManager.defaultColors[colorIndex];
  }

  String _generateEntryId() {
    return 'mem_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _generateTagId() {
    return 'tag_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _generateCaptureGroupId() {
    return 'cap_${DateTime.now().microsecondsSinceEpoch}';
  }

  String _generateCaptureFeedbackId() {
    return 'fb_${DateTime.now().microsecondsSinceEpoch}';
  }
}
