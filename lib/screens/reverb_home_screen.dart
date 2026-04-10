import 'package:flutter/material.dart';

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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.controller});

  final ReverbController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFEBE0D2), // Subtle theme aware clean background
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.multitrack_audio, 
                  color: theme.textTheme.headlineMedium?.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reverb',
                      style: theme.textTheme.headlineMedium,
                    ),
                    Text(
                      'Dump your brain here. Future you will deal with it.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricPill(
                label: 'Stuff to do',
                value: controller.openTodoCount.toString(),
              ),
              _MetricPill(
                label: 'Shower thoughts',
                value: controller.countFor(MemoryType.idea).toString(),
              ),
              _MetricPill(
                label: 'Timebombs',
                value: controller.countFor(MemoryType.reminder).toString(),
              ),
            ],
          ),
          if (controller.upcomingReminders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Future nags',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...controller.upcomingReminders.map(
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

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white54,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge,
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FeedSection extends StatelessWidget {
  const _FeedSection({required this.controller});

  final ReverbController controller;

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
                  label: Text(_filterLabel(filter)),
                  selected: controller.activeFilter == filter,
                  onSelected: (_) => controller.selectFilter(filter),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: controller.visibleEntries.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  itemCount: controller.visibleEntries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = controller.visibleEntries[index];
                    return MemoryCard(
                      entry: entry,
                      onTodoChanged: entry.type == MemoryType.todo
                          ? (isComplete) =>
                                controller.toggleTodo(entry.id, isComplete)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

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
      label: Text(controller.isProcessing ? 'Processing your ramblings...' : 'Yell at your phone'),
    );
  }
}
