import 'package:flutter/material.dart';

import '../controllers/reverb_controller.dart';
import '../models/tag_definition.dart';
import '../services/tag_manager.dart';

Future<void> showTagManagementSheet(
  BuildContext context, {
  required ReverbController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TagManagementSheet(controller: controller),
  );
}

class _TagManagementSheet extends StatefulWidget {
  const _TagManagementSheet({required this.controller});

  final ReverbController controller;

  @override
  State<_TagManagementSheet> createState() => _TagManagementSheetState();
}

class _TagManagementSheetState extends State<_TagManagementSheet> {
  final TextEditingController _newTagController = TextEditingController();
  late int _selectedColorValue;

  @override
  void initState() {
    super.initState();
    _selectedColorValue = TagManager.defaultColors.first;
  }

  @override
  void dispose() {
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Manage tags',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newTagController,
                decoration: InputDecoration(
                  labelText: 'New tag',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onSubmitted: (_) => _createTag(),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TagManager.defaultColors
                    .map((colorValue) {
                      final isSelected = colorValue == _selectedColorValue;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () =>
                            setState(() => _selectedColorValue = colorValue),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _createTag,
                  child: const Text('Add tag'),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.controller.tags.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tag = widget.controller.tags[index];
                    return _TagRow(
                      tag: tag,
                      onRename: () => _renameTag(tag),
                      onDelete: tag.isProtected
                          ? null
                          : () => widget.controller.deleteTag(tag.id),
                      onColorChanged: (colorValue) {
                        widget.controller.updateTagColor(tag.id, colorValue);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createTag() async {
    final created = await widget.controller.createTag(
      _newTagController.text,
      colorValue: _selectedColorValue,
    );
    if (created != null) {
      _newTagController.clear();
    }
  }

  Future<void> _renameTag(TagDefinition tag) async {
    final controller = TextEditingController(text: tag.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename tag'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nextName == null) {
      return;
    }
    await widget.controller.renameTag(tag.id, nextName);
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.onRename,
    required this.onColorChanged,
    this.onDelete,
  });

  final TagDefinition tag;
  final VoidCallback onRename;
  final ValueChanged<int> onColorChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Color(tag.colorValue),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tag.name, style: theme.textTheme.titleMedium),
              ),
              if (tag.isProtected)
                Text('Locked', style: theme.textTheme.bodySmall)
              else ...[
                IconButton(
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TagManager.defaultColors
                .map((colorValue) {
                  final isSelected = colorValue == tag.colorValue;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onColorChanged(colorValue),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color(colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
