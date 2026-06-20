import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'category_selector.dart';

/// Bottom sheet to pick which categories to filter by (multi-select).
/// Returns the chosen set of category keys, or null if dismissed.
class CategoryFilterSheet extends StatefulWidget {
  const CategoryFilterSheet({super.key, required this.initial});

  final Set<String> initial;

  static Future<Set<String>?> show(
      BuildContext context, Set<String> initial) {
    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CategoryFilterSheet(initial: initial),
    );
  }

  @override
  State<CategoryFilterSheet> createState() => _CategoryFilterSheetState();
}

class _CategoryFilterSheetState extends State<CategoryFilterSheet> {
  late Set<String> _selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('Filter',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: Text('Clear',
                        style: TextStyle(color: colors.subtle)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to filter · long-press to delete · use Add to create your own',
              style: TextStyle(fontSize: 11.5, color: colors.subtle),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: CategorySelector(
                  selected: _selected,
                  editable: true,
                  onChanged: (s) => setState(() => _selected = s),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(
                  _selected.isEmpty
                      ? 'Show all'
                      : 'Apply ${_selected.length} filter${_selected.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
