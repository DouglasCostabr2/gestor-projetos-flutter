import 'package:flutter/material.dart';

/// A chip widget for displaying and managing tags
class TagChip extends StatelessWidget {
  final String label;
  final String? color;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showDelete;

  const TagChip({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.showDelete = false,
  });

  Color _parseColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return Colors.blue;
    }
    try {
      final hex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _parseColor(color);
    
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      deleteIcon: showDelete ? const Icon(Icons.close, size: 16) : null,
      onDeleted: showDelete ? onDelete : null,
      backgroundColor: chipColor.withValues(alpha: 0.1),
      selectedColor: chipColor.withValues(alpha: 0.3),
      checkmarkColor: chipColor,
      labelStyle: TextStyle(
        color: selected ? chipColor : Theme.of(context).colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: selected ? chipColor : chipColor.withValues(alpha: 0.3),
        width: selected ? 2 : 1,
      ),
    );
  }
}

/// Widget for managing tags (add, remove, filter)
class TagManager extends StatelessWidget {
  final List<Map<String, dynamic>> availableTags;
  final List<String> selectedTagIds;
  final Function(String tagId) onTagToggle;
  final VoidCallback? onCreateTag;
  final bool showCreateButton;

  const TagManager({
    super.key,
    required this.availableTags,
    required this.selectedTagIds,
    required this.onTagToggle,
    this.onCreateTag,
    this.showCreateButton = true,
  });

  @override
  Widget build(BuildContext context) {
    if (availableTags.isEmpty && !showCreateButton) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...availableTags.map((tag) {
          final tagId = tag['id'] as String;
          final tagName = tag['name'] as String;
          final tagColor = tag['color'] as String?;
          final isSelected = selectedTagIds.contains(tagId);

          return TagChip(
            label: tagName,
            color: tagColor,
            selected: isSelected,
            onTap: () => onTagToggle(tagId),
          );
        }),
        if (showCreateButton && onCreateTag != null)
          ActionChip(
            label: const Text('+ Nova Tag'),
            onPressed: onCreateTag,
            avatar: const Icon(Icons.add, size: 16),
          ),
      ],
    );
  }
}

