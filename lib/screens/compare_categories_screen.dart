import 'package:flutter/material.dart';

import '../data/category_mapping.dart';
import '../data/category_store.dart';
import '../data/social_service.dart';
import '../models/category.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/gradient_app_bar.dart';

/// Compare friends' categories with yours. Swipe right to import a category
/// exactly as-is, swipe left to hide it from suggestions, or tap Link to map
/// it to one of your existing categories.
///
/// When [friend] is given, shows just that friend; otherwise groups every
/// friend in an expandable list (used from the map).
class CompareCategoriesScreen extends StatefulWidget {
  const CompareCategoriesScreen({super.key, this.friend});

  final Friend? friend;

  @override
  State<CompareCategoriesScreen> createState() =>
      _CompareCategoriesScreenState();
}

class _CompareCategoriesScreenState extends State<CompareCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // Link identically-named categories automatically before showing the
    // list (the map listens, so the UI updates when links land).
    final friends = widget.friend == null
        ? SocialService.friends.value
        : [widget.friend!];
    for (final f in friends) {
      CategoryMapping.autoLink(
          SocialService.categoriesFor(f.name), CategoryStore.all.value);
    }
    // And pull fresh copies from the cloud in case the cache is stale or
    // was fetched before the friend synced; re-links when they land.
    SocialService.cloudRefreshCategories?.call().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action,
                  style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _importExact(AppCategory fc) async {
    final imported = await CategoryStore.add(fc.label, iconIndex: fc.iconIndex);
    await CategoryMapping.link(fc.key, imported.key);
    if (mounted) setState(() {});
  }

  Future<void> _choose(AppCategory fc) async {
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
            Text('Match "${fc.label}" to…',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
      await CategoryMapping.unlink(fc.key);
    } else {
      await CategoryMapping.link(fc.key, result);
    }
    if (mounted) setState(() {});
  }

  List<AppCategory> _visibleFor(String friendName) =>
      SocialService.categoriesFor(friendName)
          .where((c) => !CategoryMapping.isHidden(c.key))
          .toList();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: GradientAppBar(
          title: widget.friend == null
              ? 'Compare Categories'
              : '${widget.friend!.name.split(' ').first}\'s Categories'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(
            'Swipe right to import a category as-is · swipe left to hide it · '
            'tap Link to match it to one of yours.',
            style: TextStyle(color: colors.subtle, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: CategoryMapping.map,
            builder: (context, mapping, _) {
              if (widget.friend != null) {
                final cats = _visibleFor(widget.friend!.name);
                return Column(
                  children: cats
                      .map((fc) => _row(fc, mapping, widget.friend!.username))
                      .toList(),
                );
              }
              return Column(
                children: SocialService.friends.value.map((f) {
                  final cats = _visibleFor(f.name);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppTheme.panel(context, radius: 16),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      shape: const Border(),
                      leading: PersonAvatar(name: f.name, size: 38),
                      title: Text(f.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text('${cats.length} categories',
                          style: TextStyle(color: colors.subtle)),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children:
                          cats.map((fc) => _row(fc, mapping, f.username)).toList(),
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

  Widget _row(AppCategory fc, Map<String, String> mapping, String keyPrefix) {
    final colors = context.colors;
    final localKey = mapping[fc.key];
    final local = localKey == null ? null : CategoryStore.byKey(localKey);

    return Dismissible(
      key: ValueKey('${keyPrefix}_${fc.key}'),
      background: _swipeBg(
          Alignment.centerLeft, const Color(0xFF2E9E5B), Icons.download, 'Import'),
      secondaryBackground: _swipeBg(Alignment.centerRight,
          const Color(0xFFE0484D), Icons.visibility_off, 'Hide'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          final ok = await _confirm('Import "${fc.label}"?',
              'Adds it to your categories exactly as named.', 'Import');
          if (ok) await _importExact(fc);
          return false;
        } else {
          final ok = await _confirm('Hide "${fc.label}"?',
              'It won\'t be suggested in Compare again.', 'Hide');
          if (ok) await CategoryMapping.hide(fc.key);
          return ok;
        }
      },
      onDismissed: (_) => setState(() {}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.panel(context, radius: 14),
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
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(
                    local == null ? 'Not linked' : 'Linked to ${local.label}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            local == null ? colors.subtle : AppTheme.accent,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _choose(fc),
              style: TextButton.styleFrom(foregroundColor: AppTheme.accent),
              child: Text(local == null ? 'Link' : 'Change'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeBg(
      Alignment align, Color color, IconData icon, String label) {
    return Container(
      alignment: align,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
