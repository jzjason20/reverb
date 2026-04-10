import 'package:flutter/material.dart';

import '../models/memory_entry.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({super.key, required this.entry, this.onTodoChanged});

  final MemoryEntry entry;
  final ValueChanged<bool>? onTodoChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(type: entry.type),
                const Spacer(),
                Text(
                  _formatTimestamp(entry.createdAt),
                  style: theme.textTheme.bodySmall,
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
                  color: theme.colorScheme.primary, // Using theme primary
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(entry.transcript, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(label: 'v${entry.version}'),
                _MetaChip(label: _syncLabel(entry.syncStatus)),
                if (entry.taskTitle != null && entry.type != MemoryType.todo)
                  _MetaChip(label: entry.taskTitle!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime, {bool includeDate = false}) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final suffix = dateTime.hour >= 12 ? 'PM' : 'AM';
    if (!includeDate) {
      return '$hour:$minute $suffix';
    }
    return '${dateTime.month}/${dateTime.day} • $hour:$minute $suffix';
  }

  String _syncLabel(SyncStatus status) {
    switch (status) {
      case SyncStatus.localOnly:
        return 'local only';
      case SyncStatus.pendingUpload:
        return 'sync-ready';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingDelete:
        return 'pending delete';
      case SyncStatus.conflict:
        return 'needs review';
    }
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}
