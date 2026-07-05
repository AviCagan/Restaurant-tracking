import 'package:flutter/material.dart';

import '../data/friend_group_store.dart';
import '../data/social_service.dart';
import '../theme/app_theme.dart';

const List<String> groupEmojis = [
  '👥', '👨‍👩‍👧', '💑', '🧑‍🤝‍🧑', '🕍', '🏠', '💼', '🎓', //
  '🍕', '☕', '🎉', '⭐',
];

/// Create or edit a friend group: name, emoji, and member selection.
/// Returns true if saved.
Future<bool> showGroupEditDialog(BuildContext context,
    {FriendGroup? existing}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var emoji = existing?.emoji ?? '👥';
  final selected = {...(existing?.usernames ?? const <String>[])};

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        final colors = context.colors;
        final friends = SocialService.friends.value;
        return AlertDialog(
          title: Text(existing == null ? 'New group' : 'Edit group'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: existing == null,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Family'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: {...groupEmojis, emoji}.map((e) {
                    final on = e == emoji;
                    return GestureDetector(
                      onTap: () => setState(() => emoji = e),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: on
                              ? AppTheme.accent.withValues(alpha: 0.18)
                              : colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: on
                                  ? AppTheme.accent
                                  : Colors.transparent),
                        ),
                        child: Center(
                            child: Text(e,
                                style: const TextStyle(fontSize: 18))),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text('Who\'s in it?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.subtle)),
                const SizedBox(height: 8),
                if (friends.isEmpty)
                  Text('Add some friends first!',
                      style: TextStyle(color: colors.subtle, fontSize: 13)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: friends.map((f) {
                    final on = selected.contains(f.username);
                    return FilterChip(
                      selected: on,
                      selectedColor:
                          AppTheme.accent.withValues(alpha: 0.18),
                      checkmarkColor: AppTheme.accent,
                      label: Text(f.name),
                      onSelected: (_) => setState(() {
                        on
                            ? selected.remove(f.username)
                            : selected.add(f.username);
                      }),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await FriendGroupStore.delete(existing.id);
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Delete',
                    style: TextStyle(color: Color(0xFFE0484D))),
              ),
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: Text(existing == null ? 'Create' : 'Save'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true && nameCtrl.text.trim().isNotEmpty) {
    if (existing == null) {
      await FriendGroupStore.create(nameCtrl.text,
          emoji: emoji, usernames: selected.toList());
    } else if (FriendGroupStore.byId(existing.id) != null) {
      await FriendGroupStore.update(existing.copyWith(
          name: nameCtrl.text, emoji: emoji, usernames: selected.toList()));
    }
    return true;
  }
  return saved ?? false;
}
