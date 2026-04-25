import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../models/memory_entry.dart';
import '../services/speech_capture_service.dart';
import '../services/whisper_transcribe_service.dart';
import '../widgets/capture_sheet.dart';
import '../widgets/entry_editor_sheet.dart';
import '../widgets/memory_card.dart';
import '../widgets/tag_management_sheet.dart';

class ReverbHomeScreen extends StatefulWidget {
  const ReverbHomeScreen({
    super.key,
    required this.controller,
    required this.speechCaptureService,
    this.whisperTranscribeService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;
  final WhisperTranscribeService? whisperTranscribeService;

  @override
  State<ReverbHomeScreen> createState() => _ReverbHomeScreenState();
}

class _ReverbHomeScreenState extends State<ReverbHomeScreen> {
  String? _lastShownError;
  String? _lastShownCaptureFeedbackId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        _showPendingError();
        _showCaptureFeedback();

        final promptEntry = widget.controller.pendingDueDateEntry;
        return Scaffold(
          body: SafeArea(
            child: widget.controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      Column(
                        children: [
                          _TopBar(controller: widget.controller),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: _TabBody(
                                controller: widget.controller,
                                onOpenEntry: _openEntryEditor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (promptEntry != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 92,
                          child: _DueDatePrompt(
                            entry: promptEntry,
                            controller: widget.controller,
                          ),
                        ),
                    ],
                  ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: widget.controller.activeTab.index,
            onDestinationSelected: (index) {
              final tab = HomeTab.values[index];
              widget.controller.selectTab(tab);
              if (tab == HomeTab.tags &&
                  widget.controller.selectedTagId == null &&
                  widget.controller.tags.isNotEmpty) {
                widget.controller.selectTagScope(
                  widget.controller.tags.first.id,
                );
              }
            },
            destinations: [
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: widget.controller.todayCount > 0,
                  label: Text('${widget.controller.todayCount}'),
                  child: const Icon(Icons.today_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: widget.controller.todayCount > 0,
                  label: Text('${widget.controller.todayCount}'),
                  child: const Icon(Icons.today),
                ),
                label: 'Today',
              ),
              const NavigationDestination(
                icon: Icon(Icons.view_agenda_outlined),
                selectedIcon: Icon(Icons.view_agenda),
                label: 'All',
              ),
              const NavigationDestination(
                icon: Icon(Icons.sell_outlined),
                selectedIcon: Icon(Icons.sell),
                label: 'Tags',
              ),
            ],
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _CaptureButton(
            controller: widget.controller,
            speechCaptureService: widget.speechCaptureService,
            whisperTranscribeService: widget.whisperTranscribeService,
          ),
        );
      },
    );
  }

  Future<void> _openEntryEditor(MemoryEntry entry) async {
    await showEntryEditorSheet(
      context,
      controller: widget.controller,
      entry: entry,
    );
  }

  void _showPendingError() {
    final error = widget.controller.lastErrorMessage;
    if (error == null || error == _lastShownError) {
      return;
    }

    _lastShownError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    });
  }

  void _showCaptureFeedback() {
    final feedback = widget.controller.latestCaptureFeedback;
    if (feedback == null || feedback.id == _lastShownCaptureFeedbackId) {
      return;
    }

    _lastShownCaptureFeedbackId = feedback.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(feedback.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller});

  final ReverbController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (controller.activeTab) {
      HomeTab.today => 'Today',
      HomeTab.all => 'All',
      HomeTab.tags => 'Tags',
    };
    final subtitle = switch (controller.activeTab) {
      HomeTab.today =>
        controller.todayCount == 0
            ? 'Nothing due today.'
            : '${controller.todayCount} todo${controller.todayCount == 1 ? '' : 's'} due today.',
      HomeTab.all =>
        '${controller.entries.where((entry) => !entry.isDeleted).length} saved entries.',
      HomeTab.tags => controller.selectedTag?.name ?? 'Browse your tag spaces.',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reverb', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('$title • $subtitle', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              showTagManagementSheet(context, controller: controller);
            },
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Manage tags',
          ),
        ],
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.controller, required this.onOpenEntry});

  final ReverbController controller;
  final ValueChanged<MemoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return switch (controller.activeTab) {
      HomeTab.today => _EntryListTab(
        entries: controller.todayEntries,
        controller: controller,
        onOpenEntry: onOpenEntry,
        emptyTitle: 'No fires today.',
        emptyBody: 'Anything with a due date today will show up here.',
      ),
      HomeTab.all => _AllTab(controller: controller, onOpenEntry: onOpenEntry),
      HomeTab.tags => _TagsTab(
        controller: controller,
        onOpenEntry: onOpenEntry,
      ),
    };
  }
}

class _AllTab extends StatelessWidget {
  const _AllTab({required this.controller, required this.onOpenEntry});

  final ReverbController controller;
  final ValueChanged<MemoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FilterBlock(
          title: 'Type',
          children: EntryTypeFilter.values
              .map((filter) {
                return _OutlineChip(
                  label: _typeFilterLabel(filter),
                  selected: controller.allFilter == filter,
                  onTap: () => controller.setAllFilter(filter),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        _FilterBlock(
          title: 'Tags',
          trailing: controller.selectedTags.isEmpty
              ? null
              : TextButton(
                  onPressed: controller.clearTagFilters,
                  child: const Text('Clear'),
                ),
          children: controller.tags
              .map((tag) {
                return _OutlineChip(
                  label: tag.name,
                  selected: controller.selectedTags.contains(tag.name),
                  accentColor: Color(tag.colorValue),
                  onTap: () => controller.toggleTag(tag.name),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _EntryListTab(
            entries: controller.allEntries,
            controller: controller,
            onOpenEntry: onOpenEntry,
            emptyTitle: 'Nothing here yet.',
            emptyBody:
                'Your full history will stack up here once you start capturing.',
          ),
        ),
      ],
    );
  }

  String _typeFilterLabel(EntryTypeFilter filter) {
    return switch (filter) {
      EntryTypeFilter.all => 'All',
      EntryTypeFilter.braindumps => 'Braindumps',
      EntryTypeFilter.ideas => 'Ideas',
      EntryTypeFilter.todos => 'Todos',
    };
  }
}

class _TagsTab extends StatelessWidget {
  const _TagsTab({required this.controller, required this.onOpenEntry});

  final ReverbController controller;
  final ValueChanged<MemoryEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final selectedTag = controller.selectedTag;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final tagRail = _TagRail(controller: controller, isWide: isWide);
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilterBlock(
              title: selectedTag?.name ?? 'Type',
              children: EntryTypeFilter.values
                  .map((filter) {
                    return _OutlineChip(
                      label: switch (filter) {
                        EntryTypeFilter.all => 'All',
                        EntryTypeFilter.braindumps => 'Braindumps',
                        EntryTypeFilter.ideas => 'Ideas',
                        EntryTypeFilter.todos => 'Todos',
                      },
                      selected: controller.tagViewFilter == filter,
                      onTap: () => controller.setTagViewFilter(filter),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _EntryListTab(
                entries: controller.tagEntries,
                controller: controller,
                onOpenEntry: onOpenEntry,
                emptyTitle: selectedTag == null
                    ? 'Pick a tag.'
                    : 'No entries under ${selectedTag.name}.',
                emptyBody: selectedTag == null
                    ? 'Choose a tag to see its full context.'
                    : 'This space is empty for the selected type filter.',
              ),
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              SizedBox(width: 180, child: tagRail),
              const SizedBox(width: 16),
              Expanded(child: content),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(height: 40, child: tagRail),
            const SizedBox(height: 12),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

class _TagRail extends StatelessWidget {
  const _TagRail({required this.controller, required this.isWide});

  final ReverbController controller;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (controller.tags.isNotEmpty && controller.selectedTagId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.selectedTagId == null && controller.tags.isNotEmpty) {
          controller.selectTagScope(controller.tags.first.id);
        }
      });
    }

    if (isWide) {
      return ListView.separated(
        itemCount: controller.tags.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final tag = controller.tags[index];
          final selected = controller.selectedTagId == tag.id;
          return _TagRailItem(
            tagName: tag.name,
            color: Color(tag.colorValue),
            selected: selected,
            onTap: () => controller.selectTagScope(tag.id),
          );
        },
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: controller.tags.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final tag = controller.tags[index];
        final selected = controller.selectedTagId == tag.id;
        return _TagRailItem(
          tagName: tag.name,
          color: Color(tag.colorValue),
          selected: selected,
          onTap: () => controller.selectTagScope(tag.id),
        );
      },
    );
  }
}

class _TagRailItem extends StatelessWidget {
  const _TagRailItem({
    required this.tagName,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String tagName;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.cardColor : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.onSurface
                  : theme.dividerColor.withAlpha(60),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(child: Text(tagName)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryListTab extends StatelessWidget {
  const _EntryListTab({
    required this.entries,
    required this.controller,
    required this.onOpenEntry,
    required this.emptyTitle,
    required this.emptyBody,
  });

  final List<MemoryEntry> entries;
  final ReverbController controller;
  final ValueChanged<MemoryEntry> onOpenEntry;
  final String emptyTitle;
  final String emptyBody;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return _EmptyState(title: emptyTitle, body: emptyBody);
    }

    final tagColors = <String, Color>{
      for (final tag in controller.tags) tag.name: Color(tag.colorValue),
    };

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 160),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return MemoryCard(
          entry: entry,
          tagColors: tagColors,
          isProcessing: controller.isEntryProcessing(entry.id),
          onTodoChanged: entry.type == MemoryType.todo
              ? (value) => controller.toggleTodo(entry.id, value)
              : null,
          onDelete: () => controller.deleteEntry(entry.id),
          onTap: () => onOpenEntry(entry),
        );
      },
    );
  }
}

class _FilterBlock extends StatelessWidget {
  const _FilterBlock({
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = selected
        ? (accentColor ?? theme.colorScheme.onSurface)
        : theme.dividerColor.withAlpha(80);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (accentColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _DueDatePrompt extends StatelessWidget {
  const _DueDatePrompt({required this.entry, required this.controller});

  final MemoryEntry entry;
  final ReverbController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a due date?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              entry.taskTitle ?? entry.summary,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Today'),
                  onPressed: () =>
                      controller.applyDueDateShortcut(DueDateShortcut.today),
                ),
                ActionChip(
                  label: const Text('Tomorrow'),
                  onPressed: () =>
                      controller.applyDueDateShortcut(DueDateShortcut.tomorrow),
                ),
                ActionChip(
                  label: const Text('This week'),
                  onPressed: () =>
                      controller.applyDueDateShortcut(DueDateShortcut.thisWeek),
                ),
                ActionChip(
                  label: const Text('Skip'),
                  onPressed: controller.dismissDueDatePrompt,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.notes_rounded),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({
    required this.controller,
    required this.speechCaptureService,
    this.whisperTranscribeService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;
  final WhisperTranscribeService? whisperTranscribeService;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FloatingActionButton.extended(
      onPressed: controller.isProcessing
          ? null
          : () async {
              await showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.colorScheme.surface,
                builder: (_) => CaptureSheet(
                  controller: controller,
                  speechCaptureService: speechCaptureService,
                  whisperTranscribeService: whisperTranscribeService,
                ),
              );
            },
      icon: controller.isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.mic_rounded),
      label: Text(controller.isProcessing ? 'Saving...' : 'Capture'),
    );
  }
}
