import 'package:flutter/material.dart';

import '../data/folder_store.dart';
import '../theme/app_theme.dart';

/// Dialog to create or rename a folder (name + emoji). Returns true if saved.
Future<bool> showFolderEditDialog(BuildContext context,
    {Folder? existing}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var emoji = existing?.emoji ?? '📁';

  final saved = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        final colors = context.colors;
        return AlertDialog(
          title: Text(existing == null ? 'New folder' : 'Edit folder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration:
                    const InputDecoration(hintText: 'e.g. Date nights'),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: folderEmojis.map((e) {
                  final on = e == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => emoji = e),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: on
                            ? AppTheme.accent.withValues(alpha: 0.18)
                            : colors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                on ? AppTheme.accent : Colors.transparent),
                      ),
                      child: Center(
                          child:
                              Text(e, style: const TextStyle(fontSize: 20))),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
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

  if (saved == true) {
    if (existing == null) {
      await FolderStore.create(nameCtrl.text, emoji: emoji);
    } else {
      await FolderStore.rename(existing.id, nameCtrl.text, emoji);
    }
    return true;
  }
  return false;
}

/// Bottom sheet with checkboxes to put [restaurantId] into folders.
Future<void> showAddToFolderSheet(
    BuildContext context, String restaurantId, String restaurantName) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: context.colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: ValueListenableBuilder<List<Folder>>(
        valueListenable: FolderStore.all,
        builder: (context, folders, _) {
          final colors = context.colors;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Add "$restaurantName" to…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.heading(18, color: colors.ink)),
              ),
              const SizedBox(height: 6),
              if (folders.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('No folders yet — make your first one below.',
                      style: TextStyle(color: colors.subtle)),
                ),
              ...folders.map((f) => CheckboxListTile(
                    value: f.restaurantIds.contains(restaurantId),
                    activeColor: AppTheme.accent,
                    secondary:
                        Text(f.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(f.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${f.restaurantIds.length} place${f.restaurantIds.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colors.subtle, fontSize: 12)),
                    onChanged: (_) =>
                        FolderStore.toggle(f.id, restaurantId),
                  )),
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined,
                    color: AppTheme.accent),
                title: const Text('New folder',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700)),
                onTap: () => showFolderEditDialog(context),
              ),
            ],
          );
        },
      ),
    ),
  );
}
