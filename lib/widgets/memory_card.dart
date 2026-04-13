import 'package:flutter/material.dart';

import '../models/memory_entry.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.entry,
    this.onTodoChanged,
    this.onDelete,
    this.onTap,
  });

  final MemoryEntry entry;
  final ValueChanged<bool>? onTodoChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MemoryTypeBadge(type: entry.type),
                  const Spacer(),
                  Text(
                    _smartTimestamp(entry.createdAt),
                    style: theme.textTheme.bodySmall,
                  ),
                  PopupMenuButton<_CardAction>(
                    tooltip: 'Entry actions',
                    onSelected: (action) {
                      if (action == _CardAction.delete) {
                        onDelete?.call();
                      }
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem<_CardAction>(
                          value: _CardAction.delete,
                          child: Text('Delete'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (entry.type == MemoryType.todo && onTodoChanged != null) ...[
                Row(
                  children: [
                    Checkbox(
                      value: entry.isComplete,
                      onChanged: (value) => onTodoChanged?.call(value ?? false),
                    ),
                    Expanded(
                      child: Text(
                        entry.taskTitle ?? entry.summary,
                        style: theme.textTheme.titleLarge?.copyWith(
                          decoration: entry.isComplete
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(entry.summary, style: theme.textTheme.titleLarge),
              ],
              if (entry.type == MemoryType.reminder &&
                  entry.triggerTime != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Scheduled for ${_formatTimestamp(entry.triggerTime!, includeDate: true)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              if (_shouldShowTranscriptPreview(entry)) ...[
                const SizedBox(height: 8),
                Text(
                  entry.transcript,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Show a 2-line transcript preview only for thought/idea cards where the
  // Gemini summary meaningfully differs from the raw transcript.
  bool _shouldShowTranscriptPreview(MemoryEntry entry) {
    if (entry.type == MemoryType.todo || entry.type == MemoryType.reminder) {
      return false;
    }
    final s = entry.summary.toLowerCase().trim();
    final t = entry.transcript.toLowerCase().trim();
    // Skip if they're basically the same string or one contains the other fully
    if (s == t || t.startsWith(s) || s == t.replaceAll(RegExp(r'[.!?]$'), '')) {
      return false;
    }
    return true;
  }

  String _clockStr(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _smartTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return _clockStr(dt);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[dt.weekday - 1];
    }
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
    return '${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTimestamp(DateTime dateTime, {bool includeDate = false}) {
    final timeStr = _clockStr(dateTime);
    if (!includeDate) return timeStr;
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
    return '${months[dateTime.month - 1]} ${dateTime.day} • $timeStr';
  }
}

enum _CardAction { delete }

class MemoryTypeBadge extends StatelessWidget {
  const MemoryTypeBadge({super.key, required this.type});

  final MemoryType type;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = switch (type) {
      MemoryType.thought => (
        isDark ? const Color(0xFF382F24) : const Color(0xFFEDE3D6),
        isDark ? const Color(0xFFEADBCA) : const Color(0xFF5A4C3A),
      ),
      MemoryType.todo => (
        isDark ? const Color(0xFF204D36) : const Color(0xFFDFF0E7),
        isDark ? const Color(0xFFBFE0D0) : const Color(0xFF206348),
      ),
      MemoryType.idea => (
        isDark ? const Color(0xFF382D6E) : const Color(0xFFE9E5FF),
        isDark ? const Color(0xFFD2CBF7) : const Color(0xFF5948B0),
      ),
      MemoryType.reminder => (
        isDark ? const Color(0xFF6E311B) : const Color(0xFFFFE2D7),
        isDark ? const Color(0xFFF7D1C3) : const Color(0xFFB04E2C),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        switch (type) {
          MemoryType.thought => 'Brain Dump',
          MemoryType.todo => 'To-Do',
          MemoryType.idea => 'Lightbulb Moment',
          MemoryType.reminder => 'Yell At Future Me',
        },
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: palette.$2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
