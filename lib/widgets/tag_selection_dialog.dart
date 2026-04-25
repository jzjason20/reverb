import 'package:flutter/material.dart';

import '../services/tag_manager.dart';

/// Shows a dialog for selecting/deselecting tags for a memory entry.
Future<List<String>?> showTagSelectionDialog(
  BuildContext context,
  List<String> currentTags,
  List<String> allAvailableTags,
) {
  return showDialog<List<String>>(
    context: context,
    builder: (context) => _TagSelectionDialog(
      currentTags: currentTags,
      allAvailableTags: allAvailableTags,
    ),
  );
}

class _TagSelectionDialog extends StatefulWidget {
  const _TagSelectionDialog({
    required this.currentTags,
    required this.allAvailableTags,
  });

  final List<String> currentTags;
  final List<String> allAvailableTags;

  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  late Set<String> _selectedTags;
  final TextEditingController _newTagController = TextEditingController();
  String? _newTagError;

  @override
  void initState() {
    super.initState();
    _selectedTags = Set<String>.from(widget.currentTags);
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  void _addNewTag() {
    final tagName = _newTagController.text.trim();
    final error = TagManager.validateTagName(tagName);

    if (error != null) {
      setState(() => _newTagError = error);
      return;
    }

    final normalized = TagManager.normalizeTag(tagName);

    if (widget.allAvailableTags.contains(normalized)) {
      setState(() => _newTagError = 'Tag already exists');
      return;
    }

    setState(() {
      _selectedTags.add(normalized);
      _newTagController.clear();
      _newTagError = null;
    });
  }

  void _deleteTag(String tag) {
    setState(() => _selectedTags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Combine available tags with selected tags
    final displayTags = <String>{
      ...widget.allAvailableTags,
      ..._selectedTags,
    }.toList()
      ..sort();

    return AlertDialog(
      title: const Text('Edit Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select or create tags',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),

            // New tag input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTagController,
                    decoration: InputDecoration(
                      hintText: 'Create new tag...',
                      errorText: _newTagError,
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.black.withAlpha(50),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _addNewTag(),
                    onChanged: (_) {
                      if (_newTagError != null) {
                        setState(() => _newTagError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addNewTag,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add tag',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Existing tags
            if (displayTags.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: displayTags.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      final color = TagManager.getColorForTag(tag, displayTags);

                      return InputChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        onDeleted: isSelected ? () => _deleteTag(tag) : null,
                        deleteIcon: const Icon(Icons.close, size: 16),
                        avatar: isSelected
                            ? Icon(Icons.check_circle, size: 18, color: color)
                            : null,
                        backgroundColor: color.withAlpha(40),
                        selectedColor: color.withAlpha(80),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              '${_selectedTags.length} tag${_selectedTags.length == 1 ? '' : 's'} selected',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_selectedTags.toList()..sort());
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
