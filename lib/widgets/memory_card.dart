import 'package:flutter/material.dart';

import '../models/memory_entry.dart';

class MemoryCard extends StatelessWidget {
  const MemoryCard({
    super.key,
    required this.entry,
    required this.tagColors,
    this.isProcessing = false,
    this.onTodoChanged,
    this.onDelete,
    this.onTap,
  });

  final MemoryEntry entry;
  final Map<String, Color> tagColors;
  final bool isProcessing;
  final ValueChanged<bool>? onTodoChanged;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _priorityBorderColor(entry);
    final hasPriorityBorder =
        entry.type == MemoryType.todo && borderColor.opacity > 0;
    final preview = _secondaryPreview(entry);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete entry?'),
          content: Text(entry.summary),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF991B1B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.dividerColor.withAlpha(50)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: hasPriorityBorder
                    ? Border(left: BorderSide(color: borderColor, width: 4))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.type == MemoryType.todo &&
                          onTodoChanged != null)
                        Checkbox(
                          value: entry.isComplete,
                          onChanged: (value) =>
                              onTodoChanged?.call(value ?? false),
                        ),
                      Expanded(
                        child: Text(
                          _typeLabel(entry.type).toUpperCase(),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        _smartTimestamp(entry.createdAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isProcessing) ...[
                    _ShimmerLine(widthFactor: 0.82),
                    const SizedBox(height: 8),
                    _ShimmerLine(widthFactor: 0.56),
                    const SizedBox(height: 12),
                    Text('Organizing...', style: theme.textTheme.bodySmall),
                  ] else ...[
                    Text(
                      _primaryText(entry),
                      style: theme.textTheme.titleLarge?.copyWith(
                        decoration: entry.isComplete
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                    ),
                    if (preview != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        preview,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...entry.tags.map(
                        (tag) => _TagPill(
                          label: tag,
                          color: tagColors[tag] ?? const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(_metadata(entry), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _primaryText(MemoryEntry entry) {
    if (entry.type == MemoryType.todo) {
      return entry.taskTitle ?? entry.summary;
    }
    return entry.summary;
  }

  String? _secondaryPreview(MemoryEntry entry) {
    if (entry.type == MemoryType.todo) {
      final transcript = entry.transcript.trim();
      final title = (entry.taskTitle ?? '').trim();
      if (transcript.isEmpty ||
          title.isEmpty ||
          transcript.toLowerCase() == title.toLowerCase()) {
        return null;
      }
      return transcript;
    }

    final transcript = entry.transcript.trim();
    final summary = entry.summary.trim();
    if (transcript.isEmpty ||
        transcript.toLowerCase() == summary.toLowerCase()) {
      return null;
    }
    return transcript;
  }

  String _metadata(MemoryEntry entry) {
    final parts = <String>[_fullDate(entry.createdAt)];
    if (entry.type == MemoryType.todo && entry.triggerTime != null) {
      parts.add('Due ${_formatDue(entry.triggerTime!)}');
    }
    if (entry.type == MemoryType.todo &&
        entry.priority != MemoryPriority.none) {
      parts.add(_priorityLabel(entry.priority));
    }
    return parts.join(' • ');
  }

  String _typeLabel(MemoryType type) {
    return switch (type) {
      MemoryType.braindump => 'Braindump',
      MemoryType.idea => 'Idea',
      MemoryType.todo => 'Todo',
    };
  }

  Color _priorityBorderColor(MemoryEntry entry) {
    if (entry.type != MemoryType.todo) {
      return Colors.transparent;
    }

    return switch (entry.priority) {
      MemoryPriority.none => Colors.transparent,
      MemoryPriority.low => const Color(0xFF5E81AC),
      MemoryPriority.medium => const Color(0xFFD97706),
      MemoryPriority.high => const Color(0xFFDC2626),
    };
  }

  String _priorityLabel(MemoryPriority priority) {
    return switch (priority) {
      MemoryPriority.none => 'No priority',
      MemoryPriority.low => 'Low priority',
      MemoryPriority.medium => 'Medium priority',
      MemoryPriority.high => 'High priority',
    };
  }

  String _smartTimestamp(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return _clockStr(dt);
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    if (diff < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[dt.weekday - 1];
    }
    return '${dt.month}/${dt.day}';
  }

  String _clockStr(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  String _fullDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  String _formatDue(DateTime dt) {
    return '${dt.month}/${dt.day} ${_clockStr(dt)}';
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  const _ShimmerLine({required this.widthFactor});

  final double widthFactor;

  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widget.widthFactor,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_controller),
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: Theme.of(context).dividerColor.withAlpha(100),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
