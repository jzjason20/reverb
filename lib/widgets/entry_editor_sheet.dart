import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../models/memory_entry.dart';

Future<void> showEntryEditorSheet(
  BuildContext context, {
  required ReverbController controller,
  required MemoryEntry entry,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _EntryEditorSheet(controller: controller, entry: entry),
  );
}

class _EntryEditorSheet extends StatefulWidget {
  const _EntryEditorSheet({required this.controller, required this.entry});

  final ReverbController controller;
  final MemoryEntry entry;

  @override
  State<_EntryEditorSheet> createState() => _EntryEditorSheetState();
}

class _EntryEditorSheetState extends State<_EntryEditorSheet> {
  late final TextEditingController _textController;
  late MemoryType _selectedType;
  late Set<String> _selectedTags;
  late MemoryPriority _priority;
  DateTime? _dueAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.entry.transcript);
    _selectedType = widget.entry.type;
    _selectedTags = Set<String>.from(widget.entry.tags);
    _priority = widget.entry.priority;
    _dueAt = widget.entry.triggerTime;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, viewInsets + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedType == MemoryType.todo ? 'Edit todo' : 'Edit note',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          if (_selectedType != MemoryType.todo) ...[
            const SizedBox(height: 12),
            SegmentedButton<MemoryType>(
              segments: const [
                ButtonSegment<MemoryType>(
                  value: MemoryType.braindump,
                  label: Text('Braindump'),
                ),
                ButtonSegment<MemoryType>(
                  value: MemoryType.idea,
                  label: Text('Idea'),
                ),
              ],
              selected: <MemoryType>{_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
              },
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            minLines: _selectedType == MemoryType.todo ? 2 : 5,
            maxLines: _selectedType == MemoryType.todo ? 4 : 10,
            decoration: InputDecoration(
              labelText: _selectedType == MemoryType.todo
                  ? 'Task / details'
                  : 'Content',
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_selectedType == MemoryType.todo) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                InputChip(
                  label: Text(
                    _dueAt == null ? 'Add due date' : _formatDue(_dueAt!),
                  ),
                  onPressed: _pickDueDateTime,
                  onDeleted: _dueAt == null
                      ? null
                      : () => setState(() => _dueAt = null),
                  avatar: const Icon(Icons.calendar_today, size: 16),
                ),
                ActionChip(
                  label: Text('Priority: ${_priorityLabel(_priority)}'),
                  onPressed: () {
                    setState(() => _priority = _nextPriority(_priority));
                  },
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _priorityColor(_priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text('Tags', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.controller.tags
                .map((tag) {
                  final isSelected = _selectedTags.contains(tag.name);
                  return FilterChip(
                    label: Text(tag.name),
                    selected: isSelected,
                    showCheckmark: false,
                    avatar: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(tag.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        if (isSelected) {
                          _selectedTags.remove(tag.name);
                        } else {
                          _selectedTags.add(tag.name);
                        }
                      });
                    },
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDateTime() async {
    final now = DateTime.now();
    final initial = _dueAt ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await widget.controller.updateEntry(
      entryId: widget.entry.id,
      type: _selectedType,
      transcript: _textController.text,
      taskTitle: _selectedType == MemoryType.todo ? _textController.text : null,
      tags: _selectedTags.toList(growable: false),
      priority: _selectedType == MemoryType.todo ? _priority : null,
      dueAt: _selectedType == MemoryType.todo ? _dueAt : null,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  MemoryPriority _nextPriority(MemoryPriority priority) {
    return switch (priority) {
      MemoryPriority.none => MemoryPriority.low,
      MemoryPriority.low => MemoryPriority.medium,
      MemoryPriority.medium => MemoryPriority.high,
      MemoryPriority.high => MemoryPriority.none,
    };
  }

  Color _priorityColor(MemoryPriority priority) {
    return switch (priority) {
      MemoryPriority.none => const Color(0xFF6B7280),
      MemoryPriority.low => const Color(0xFF5E81AC),
      MemoryPriority.medium => const Color(0xFFD97706),
      MemoryPriority.high => const Color(0xFFDC2626),
    };
  }

  String _priorityLabel(MemoryPriority priority) {
    return switch (priority) {
      MemoryPriority.none => 'None',
      MemoryPriority.low => 'Low',
      MemoryPriority.medium => 'Medium',
      MemoryPriority.high => 'High',
    };
  }

  String _formatDue(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '${value.month}/${value.day} $hour:$minute $suffix';
  }
}
