import 'package:flutter/material.dart';

import '../data/category_store.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// Multi-select chips for categories, backed by the editable [CategoryStore].
/// When [editable] is true, shows an "Add" chip and lets you long-press a chip
/// to delete that category.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.editable = false,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool editable;

  Future<void> _addCategory(BuildContext context) async {
    final result = await showDialog<_NewCategory>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (result == null) return;
    final cat =
        await CategoryStore.add(result.label, iconIndex: result.iconIndex);
    onChanged({...selected, cat.key});
  }

  Future<void> _deleteCategory(BuildContext context, AppCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${c.label}"?'),
        content: const Text(
            'It will be removed from the category list. Existing restaurants '
            'keep their other tags.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
    if (ok == true) {
      await CategoryStore.remove(c.key);
      onChanged({...selected}..remove(c.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppCategory>>(
      valueListenable: CategoryStore.all,
      builder: (context, categories, _) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...categories.map((c) {
              final isOn = selected.contains(c.key);
              return _Chip(
                label: c.label,
                icon: c.icon,
                selected: isOn,
                onTap: () {
                  final next = Set<String>.from(selected);
                  isOn ? next.remove(c.key) : next.add(c.key);
                  onChanged(next);
                },
                onLongPress:
                    editable ? () => _deleteCategory(context, c) : null,
              );
            }),
            if (editable)
              _Chip(
                label: 'Add',
                icon: Icons.add,
                selected: false,
                dashed: true,
                onTap: () => _addCategory(context),
              ),
          ],
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.dashed = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : colors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected
                ? AppTheme.accent
                : (dashed ? colors.subtle : colors.line),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.white : colors.subtle),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewCategory {
  final String label;
  final int iconIndex;
  _NewCategory(this.label, this.iconIndex);
}

class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _ctrl = TextEditingController();
  int _iconIndex = 16; // generic label icon

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      title: const Text('New category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'e.g. Sushi'),
          ),
          const SizedBox(height: 16),
          Text('Icon', style: TextStyle(fontSize: 13, color: colors.subtle)),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            width: 300,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: categoryIcons.length,
              itemBuilder: (_, i) {
                final on = i == _iconIndex;
                return GestureDetector(
                  onTap: () => setState(() => _iconIndex = i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: on
                          ? AppTheme.accent.withValues(alpha: 0.15)
                          : colors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: on ? AppTheme.accent : Colors.transparent),
                    ),
                    child: Icon(categoryIcons[i],
                        size: 18,
                        color: on ? AppTheme.accent : colors.subtle),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          onPressed: () {
            final label = _ctrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, _NewCategory(label, _iconIndex));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
