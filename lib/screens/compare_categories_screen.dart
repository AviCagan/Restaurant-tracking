import 'package:flutter/material.dart';

import '../data/category_mapping.dart';
import '../data/category_store.dart';
import '../data/social_service.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';

/// Compare your friends' categories with yours and link/import them so
/// differently-named categories become comparable for filtering.
class CompareCategoriesScreen extends StatefulWidget {
  const CompareCategoriesScreen({super.key});

  @override
  State<CompareCategoriesScreen> createState() =>
      _CompareCategoriesScreenState();
}

class _CompareCategoriesScreenState extends State<CompareCategoriesScreen> {
  Future<void> _choose(AppCategory friendCat) async {
    final yours = CategoryStore.all.value;
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            Text('Match "${friendCat.label}" to…',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ...yours.map((c) => ListTile(
                        leading: Icon(c.icon, color: context.colors.subtle),
                        title: Text(c.label),
                        onTap: () => Navigator.pop(context, c.key),
                      )),
                  ListTile(
                    leading: const Icon(Icons.add, color: AppTheme.accent),
                    title: const Text('Import as a new category',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700)),
                    onTap: () => Navigator.pop(context, '__import__'),
                  ),
                  ListTile(
                    leading: Icon(Icons.link_off, color: context.colors.subtle),
                    title: const Text('Unlink'),
                    onTap: () => Navigator.pop(context, '__unlink__'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (result == '__unlink__') {
      await CategoryMapping.unlink(friendCat.key);
    } else if (result == '__import__') {
      final imported = await CategoryStore.add(
          friendCat.label.replaceAll(RegExp(r'\s[^\w\s].*$'), '').trim(),
          iconIndex: friendCat.iconIndex);
      await CategoryMapping.link(friendCat.key, imported.key);
    } else {
      await CategoryMapping.link(friendCat.key, result);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final friendCats = SocialService.friendCategories();

    return Scaffold(
      appBar: const GradientAppBar(title: 'Compare Categories'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            'Link your friends\' categories to yours so you can filter the map '
            'even when names differ.',
            style: TextStyle(color: colors.subtle, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: CategoryMapping.map,
            builder: (context, mapping, _) {
              return Column(
                children: friendCats.map((fc) {
                  final localKey = mapping[fc.key];
                  final local =
                      localKey == null ? null : CategoryStore.byKey(localKey);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: AppTheme.panel(context, radius: 16),
                    child: Row(
                      children: [
                        Icon(fc.icon, size: 20, color: colors.subtle),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fc.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text(
                                local == null
                                    ? 'Not linked'
                                    : 'Linked to ${local.label}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: local == null
                                        ? colors.subtle
                                        : AppTheme.accent,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _choose(fc),
                          style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accent),
                          child: Text(local == null ? 'Link' : 'Change'),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
