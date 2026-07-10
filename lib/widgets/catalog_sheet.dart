import 'package:flutter/material.dart';

import '../data/catalog.dart';
import '../data/category_store.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';

/// Search the shared category database and pick one to add. If the search
/// comes up empty, the user can submit it as a brand-new category — it
/// appears in the database for everyone, instantly.
///
/// Returns the added [AppCategory], or null if dismissed.
class CatalogSheet extends StatefulWidget {
  const CatalogSheet({super.key});

  static Future<AppCategory?> show(BuildContext context) {
    return showModalBottomSheet<AppCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CatalogSheet(),
    );
  }

  @override
  State<CatalogSheet> createState() => _CatalogSheetState();
}

class _CatalogSheetState extends State<CatalogSheet> {
  final _searchCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    Catalog.extras.addListener(_onCatalogChanged); // live updates
  }

  @override
  void dispose() {
    Catalog.extras.removeListener(_onCatalogChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCatalogChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pick(AppCategory c) async {
    // Add with the catalog's name; the user can relabel it later.
    final added = await CategoryStore.add(c.label, iconIndex: c.iconIndex);
    if (mounted) Navigator.pop(context, added);
  }

  Future<void> _submitNew() async {
    final label = _searchCtrl.text.trim();
    if (label.isEmpty) return;
    setState(() => _submitting = true);
    final error = await Catalog.submit(label, 16);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final added = await CategoryStore.add(label, iconIndex: 16);
    if (mounted) Navigator.pop(context, added);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _searchCtrl.text;
    final mine = {for (final c in CategoryStore.all.value) c.key};
    final results =
        Catalog.search(query).where((c) => !mine.contains(c.key)).toList();
    final exactExists = query.trim().isEmpty ||
        Catalog.byKey(Catalog.keyFor(query)) != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Add a category',
                    style: AppTheme.heading(20, color: colors.ink)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search — Pizza, Ramen, Rooftop…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  // Not in the database yet? Offer to create it for everyone.
                  if (!exactExists)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _submitting ? null : _submitNew,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.add_circle_outline, size: 20),
                        label: Text('Add "${query.trim()}" as a new category',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ...results.map((c) => ListTile(
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.icon,
                              size: 19, color: AppTheme.accent),
                        ),
                        title: Text(c.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        trailing: Icon(Icons.add_circle_outline,
                            color: AppTheme.accent),
                        onTap: () => _pick(c),
                      )),
                  if (results.isEmpty && exactExists)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        query.trim().isEmpty
                            ? 'The whole database is yours to search.'
                            : 'You already have that one! 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.subtle),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
