import 'package:flutter/material.dart';

/// Manages custom user-created tags for organizing memory entries.
class TagManager {
  TagManager();

  final List<String> _allTags = [];

  /// All tags that exist in the system (from all entries)
  List<String> get allTags => List.unmodifiable(_allTags);

  /// Default color palette for tags (cycles through these)
  static const List<int> defaultColors = [
    0xFF2196F3, // Blue
    0xFF9C27B0, // Purple
    0xFF4CAF50, // Green
    0xFFFF9800, // Orange
    0xFFE91E63, // Pink
    0xFF00BCD4, // Cyan
    0xFFFF5722, // Deep Orange
    0xFF607D8B, // Blue Grey
    0xFF8BC34A, // Light Green
    0xFFFFEB3B, // Yellow
  ];

  /// Updates the list of all tags from entries
  void updateFromEntries(Iterable<String> tags) {
    final uniqueTags = tags.toSet().toList()..sort();
    _allTags
      ..clear()
      ..addAll(uniqueTags);
  }

  /// Validates a tag name
  static String? validateTagName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Tag name cannot be empty';
    }
    if (trimmed.length > 20) {
      return 'Tag name too long (max 20 characters)';
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers, dashes and underscores allowed';
    }
    return null;
  }

  /// Normalizes a tag name (lowercase, trimmed)
  static String normalizeTag(String tag) {
    return tag.trim().toLowerCase();
  }

  /// Gets a color for a tag based on its index
  static Color getColorForTag(String tag, List<String> allTags) {
    final index = allTags.indexOf(tag);
    final colorIndex = index >= 0 ? index % defaultColors.length : 0;
    return Color(defaultColors[colorIndex]);
  }

  /// Suggests tags based on transcript content (simple keyword matching)
  static List<String> suggestTags(String transcript, List<String> existingTags) {
    final text = transcript.toLowerCase();
    final suggestions = <String>[];

    // Match against existing tags
    for (final tag in existingTags) {
      if (text.contains(tag.toLowerCase())) {
        suggestions.add(tag);
      }
    }

    return suggestions.take(2).toList();
  }
}
