import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/reverb_controller.dart';
import '../models/memory_entry.dart';
import '../services/speech_capture_service.dart';
import '../widgets/capture_sheet.dart';
import '../widgets/memory_card.dart';

class ReverbHomeScreen extends StatelessWidget {
  const ReverbHomeScreen({
    super.key,
    required this.controller,
    required this.speechCaptureService,
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _HeroPanel(controller: controller),
                Expanded(
                  child: controller.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _FeedSection(controller: controller),
                ),
              ],
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _CaptureButton(
            controller: controller,
            speechCaptureService: speechCaptureService,
          ),
        );
      },
    );
  }
}

class _HeroPanel extends StatefulWidget {
  const _HeroPanel({required this.controller});

  final ReverbController controller;

  @override
  State<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<_HeroPanel> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: theme.textTheme.bodyMedium,
                        onChanged: (val) {
                          widget.controller.setSearchQuery(val);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search memories...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(999),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white10
                              : Colors.black.withAlpha(50),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                      )
                    : Text('Reverb', style: theme.textTheme.headlineMedium),
              ),
              const SizedBox(width: 12),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor:
                      _isSearching || widget.controller.searchQuery.isNotEmpty
                      ? (isDark ? Colors.white24 : Colors.black12)
                      : (isDark ? Colors.white10 : Colors.black.withAlpha(50)),
                ),
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    if (_isSearching) {
                      _isSearching = false;
                      _searchController.clear();
                      widget.controller.setSearchQuery('');
                    } else {
                      _isSearching = true;
                      _searchController.text = widget.controller.searchQuery;
                    }
                  });
                },
              ),
            ],
          ),
          if (widget.controller.upcomingReminders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Future nags',
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            ...widget.controller.upcomingReminders.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${entry.taskTitle ?? entry.summary} • ${_formatReminder(entry.triggerTime!)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatReminder(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day} at $hour:$minute $suffix';
  }
}

class _FeedSection extends StatefulWidget {
  const _FeedSection({required this.controller});

  final ReverbController controller;

  @override
  State<_FeedSection> createState() => _FeedSectionState();
}

class _FeedSectionState extends State<_FeedSection> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: FeedFilter.values.indexOf(widget.controller.activeFilter),
    );
  }

  @override
  void didUpdateWidget(covariant _FeedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = FeedFilter.values.indexOf(
      widget.controller.activeFilter,
    );
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: FeedFilter.values.map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    '${_filterLabel(filter)}  ${_filterCount(filter)}',
                  ),
                  selected: widget.controller.activeFilter == filter,
                  showCheckmark: false,
                  onSelected: (_) => widget.controller.selectFilter(filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final newFilter = FeedFilter.values[index];
              if (widget.controller.activeFilter != newFilter) {
                widget.controller.selectFilter(newFilter);
              }
            },
            itemCount: FeedFilter.values.length,
            itemBuilder: (context, filterIndex) {
              final currentFilter = FeedFilter.values[filterIndex];

              // Filter logic applied locally for each page view so they render independently
              var displayedEntries =
                  widget.controller.entries
                      .where((entry) => !entry.isDeleted)
                      .toList()
                    ..sort(
                      (left, right) =>
                          right.createdAt.compareTo(left.createdAt),
                    );

              if (widget.controller.searchQuery.isNotEmpty) {
                final q = widget.controller.searchQuery.toLowerCase();
                displayedEntries = displayedEntries.where((entry) {
                  return entry.summary.toLowerCase().contains(q) ||
                      entry.transcript.toLowerCase().contains(q) ||
                      (entry.taskTitle?.toLowerCase().contains(q) ?? false);
                }).toList();
              }

              switch (currentFilter) {
                case FeedFilter.all:
                  break;
                case FeedFilter.todos:
                  displayedEntries = displayedEntries
                      .where((entry) => entry.type == MemoryType.todo)
                      .toList();
                  break;
                case FeedFilter.ideas:
                  displayedEntries = displayedEntries
                      .where((entry) => entry.type == MemoryType.idea)
                      .toList();
                  break;
                case FeedFilter.thoughts:
                  displayedEntries = displayedEntries
                      .where((entry) => entry.type == MemoryType.thought)
                      .toList();
                  break;
              }

              if (displayedEntries.isEmpty) {
                return const _EmptyState();
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                itemCount: displayedEntries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = displayedEntries[index];
                  return MemoryCard(
                    entry: entry,
                    onTodoChanged: entry.type == MemoryType.todo
                        ? (isComplete) =>
                              widget.controller.toggleTodo(entry.id, isComplete)
                        : null,
                    onDelete: () => _confirmDelete(context, entry),
                    onTap: () => _showEntryDetails(context, entry),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Utility functions ---

  String _filterLabel(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.all:
        return 'Everything';
      case FeedFilter.todos:
        return 'Need to do';
      case FeedFilter.ideas:
        return 'Genius stuff';
      case FeedFilter.thoughts:
        return 'Random noise';
    }
  }

  int _filterCount(FeedFilter filter) {
    switch (filter) {
      case FeedFilter.all:
        return widget.controller.entries.where((e) => !e.isDeleted).length;
      case FeedFilter.todos:
        return widget.controller.openTodoCount;
      case FeedFilter.ideas:
        return widget.controller.countFor(MemoryType.idea);
      case FeedFilter.thoughts:
        return widget.controller.countFor(MemoryType.thought);
    }
  }

  Future<void> _confirmDelete(BuildContext context, MemoryEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete memory?'),
          content: Text(
            entry.summary.isNotEmpty
                ? entry.summary
                : 'This entry will be removed from your feed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      await widget.controller.deleteEntry(entry.id);
    }
  }

  Future<void> _showEntryDetails(
    BuildContext context,
    MemoryEntry entry,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EntryDetailSheet(entry: entry),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.graphic_eq, size: 42),
            ),
            const SizedBox(height: 18),
            Text(
              'Zero thoughts recorded.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Scream into the void below. We promise to remember it forever.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
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
  });

  final ReverbController controller;
  final SpeechCaptureService speechCaptureService;

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
      label: Text(
        controller.isProcessing
            ? 'Processing your ramblings...'
            : 'Yell at your phone',
      ),
    );
  }
}

// ── Entry detail bottom sheet ──────────────────────────────────────────────

class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({required this.entry});

  final MemoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withAlpha(40),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge + timestamp row
                      Row(
                        children: [
                          MemoryTypeBadge(type: entry.type),
                          const Spacer(),
                          Text(
                            _fullDate(entry.createdAt),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Summary section
                      _SectionLabel(label: 'Summary'),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.summary,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CopyIconButton(
                            value: entry.summary,
                            tooltip: 'Copy summary',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Transcript section
                      _SectionLabel(label: 'Transcript'),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              entry.transcript,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CopyIconButton(
                            value: entry.transcript,
                            tooltip: 'Copy transcript',
                          ),
                        ],
                      ),

                      // Reminder time
                      if (entry.type == MemoryType.reminder &&
                          entry.triggerTime != null) ...[
                        const SizedBox(height: 20),
                        _SectionLabel(label: 'Scheduled for'),
                        const SizedBox(height: 6),
                        Text(
                          '${_fullDate(entry.triggerTime!)} at ${_clockStr(entry.triggerTime!)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],

                      // Todo status
                      if (entry.type == MemoryType.todo) ...[
                        const SizedBox(height: 20),
                        _SectionLabel(label: 'Status'),
                        const SizedBox(height: 6),
                        Text(
                          entry.isComplete
                              ? '✓ Done — you absolute legend'
                              : 'Still on the list...',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],

                      const SizedBox(height: 28),
                      // Close button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Close'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _clockStr(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _fullDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
      ),
    );
  }
}

class _CopyIconButton extends StatefulWidget {
  const _CopyIconButton({required this.value, required this.tooltip});

  final String value;
  final String tooltip;

  @override
  State<_CopyIconButton> createState() => _CopyIconButtonState();
}

class _CopyIconButtonState extends State<_CopyIconButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied 👌'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 140,
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
      onPressed: _copy,
    );
  }
}
