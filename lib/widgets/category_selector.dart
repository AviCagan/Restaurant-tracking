import 'package:flutter/material.dart';

import '../models/category.dart';
import '../theme/app_theme.dart';

/// Multi-select chips for tagging a restaurant's categories.
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<FoodCategory> selected;
  final ValueChanged<Set<FoodCategory>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: FoodCategory.values.map((c) {
        final isOn = selected.contains(c);
        return _Chip(
          label: c.label,
          icon: c.icon,
          selected: isOn,
          onTap: () {
            final next = Set<FoodCategory>.from(selected);
            isOn ? next.remove(c) : next.add(c);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.white : AppTheme.subtle),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
