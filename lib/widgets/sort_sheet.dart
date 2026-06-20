import 'package:flutter/material.dart';

import '../models/sort_option.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for picking the sort order.
class SortSheet extends StatelessWidget {
  const SortSheet({super.key, required this.current});

  final SortOption current;

  static Future<SortOption?> show(BuildContext context, SortOption current) {
    return showModalBottomSheet<SortOption>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SortSheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Sort by',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
          ),
          ...SortOption.values.map((o) {
            final selected = o == current;
            return ListTile(
              onTap: () => Navigator.pop(context, o),
              title: Text(
                o.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppTheme.accent : AppTheme.ink,
                ),
              ),
              trailing: selected
                  ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                  : null,
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
