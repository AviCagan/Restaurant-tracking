import 'package:flutter/material.dart';

import '../models/sort_option.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for picking the sort order. Scrollable so it never overflows.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current});

  final SortOption current;

  static Future<SortOption?> show(BuildContext context, SortOption current) {
    return showModalBottomSheet<SortOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort by',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colors.ink)),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: SortOption.values.map((o) {
                  final selected = o == current;
                  return ListTile(
                    onTap: () => Navigator.pop(context, o),
                    title: Text(
                      o.label,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppTheme.accent : colors.ink,
                      ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded,
                            color: AppTheme.accent)
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
