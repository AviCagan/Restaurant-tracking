import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/friend_group_store.dart';
import '../data/social_service.dart';
import '../services/media_storage.dart';
import '../theme/app_theme.dart';
import 'photo_source_sheet.dart';

/// Shows a group's photo if it has one, otherwise its emoji.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.group, this.size = 24});

  final FriendGroup group;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (group.photoPath.isNotEmpty && File(group.photoPath).existsSync()) {
      return ClipOval(
        child: Image.file(File(group.photoPath),
            width: size, height: size, fit: BoxFit.cover),
      );
    }
    return Text(group.emoji, style: TextStyle(fontSize: size * 0.8));
  }
}

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
  var photoPath = existing?.photoPath ?? '';
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
                  children: [
                    ...{...groupEmojis, emoji}.map((e) {
                      final on = e == emoji && photoPath.isEmpty;
                      return GestureDetector(
                        onTap: () => setState(() {
                          emoji = e;
                          photoPath = '';
                        }),
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
                    }),
                    // Any emoji via the keyboard.
                    GestureDetector(
                      onTap: () async {
                        final custom = await _askAnyEmoji(context);
                        if (custom != null) {
                          setState(() {
                            emoji = custom;
                            photoPath = '';
                          });
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.line),
                        ),
                        child: Icon(Icons.add,
                            size: 20, color: AppTheme.accent),
                      ),
                    ),
                    // Or a photo instead of an emoji.
                    GestureDetector(
                      onTap: () async {
                        final source = await PhotoSourceSheet.show(context);
                        if (source == null) return;
                        final img = await ImagePicker().pickImage(
                            source: source,
                            maxWidth: 800,
                            imageQuality: 85);
                        if (img == null) return;
                        final saved = await MediaStorage.persist(img.path);
                        setState(() => photoPath = saved);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: photoPath.isNotEmpty
                                  ? AppTheme.accent
                                  : colors.line),
                        ),
                        child: photoPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Image.file(File(photoPath),
                                    fit: BoxFit.cover),
                              )
                            : Icon(Icons.add_a_photo_outlined,
                                size: 18, color: AppTheme.accent),
                      ),
                    ),
                  ],
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
          emoji: emoji, photoPath: photoPath, usernames: selected.toList());
    } else if (FriendGroupStore.byId(existing.id) != null) {
      await FriendGroupStore.update(existing.copyWith(
          name: nameCtrl.text,
          emoji: emoji,
          photoPath: photoPath,
          usernames: selected.toList()));
    }
    return true;
  }
  return saved ?? false;
}

Future<String?> _askAnyEmoji(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Pick any emoji'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32),
            decoration: const InputDecoration(hintText: '😋'),
          ),
          const SizedBox(height: 8),
          Text('Tap the emoji key on your keyboard',
              style: TextStyle(
                  fontSize: 12, color: dialogContext.colors.subtle)),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
          onPressed: () {
            final text = ctrl.text.trim();
            Navigator.pop(dialogContext,
                text.isEmpty ? null : text.characters.first.toString());
          },
          child: const Text('Use it'),
        ),
      ],
    ),
  );
  return (result == null || result.isEmpty) ? null : result;
}
