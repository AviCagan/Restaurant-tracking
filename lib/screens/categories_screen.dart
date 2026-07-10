import 'package:flutter/material.dart';

import '../data/category_store.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/catalog_sheet.dart';
import '../widgets/gradient_app_bar.dart';

/// Settings → Categories: manage your categories. Add more from the shared
/// database (or contribute new ones to it), rename how each looks for you,
/// pick icons, remove ones you don't use.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Categories'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CatalogSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add category',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ValueListenableBuilder<List<AppCategory>>(
        valueListenable: CategoryStore.all,
        builder: (context, cats, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              Text(
                'Tap a category to rename it or change its icon — that\'s '
                'just how it looks for you. Friends\' matching categories '
                'stay in sync automatically.',
                style: TextStyle(fontSize: 12.5, color: colors.subtle),
              ),
              const SizedBox(height: 14),
              ...cats.map((c) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.line),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(c.icon, size: 20, color: AppTheme.accent),
                      ),
                      title: Text(c.label,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      trailing:
                          Icon(Icons.edit_outlined, color: colors.subtle),
                      onTap: () => _edit(context, c),
                    ),
                  )),
              if (cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No categories yet — add some below!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.subtle)),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Rename (visual only — the shared identity is untouched) + icon +
  /// remove.
  Future<void> _edit(BuildContext context, AppCategory c) async {
    final labelCtrl = TextEditingController(text: c.label);
    var iconIndex = c.iconIndex;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Edit category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(labelText: 'Name (with emoji!)'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                width: double.maxFinite,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final on = i == iconIndex;
                    return GestureDetector(
                      onTap: () => setDialog(() => iconIndex = i),
                      child: Container(
                        width: 44,
                        decoration: BoxDecoration(
                          color: on
                              ? AppTheme.accent.withValues(alpha: 0.18)
                              : dialogContext.colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: on
                                  ? AppTheme.accent
                                  : dialogContext.colors.line),
                        ),
                        child: Icon(categoryIcons[i],
                            size: 20,
                            color: on
                                ? AppTheme.accent
                                : dialogContext.colors.subtle),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              child: const Text('Remove',
                  style: TextStyle(color: Color(0xFFE0484D))),
            ),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                if (labelCtrl.text.trim().isEmpty) return;
                Navigator.pop(dialogContext, 'save');
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (action == 'delete') {
      await CategoryStore.remove(c.key);
    } else if (action == 'save') {
      await CategoryStore.relabel(c.key, labelCtrl.text, iconIndex);
    }
  }
}
