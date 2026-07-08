import 'package:flutter/material.dart';

import '../data/social_service.dart';
import '../theme/app_theme.dart';

/// Shared friend-management actions (remove / block) with confirmations,
/// used by the friends list and a friend's profile.
class FriendActions {
  static const _danger = Color(0xFFE0484D);

  /// Quick "are you sure?" before removing a friend. Returns true if removed.
  static Future<bool> confirmRemove(BuildContext context, Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove friend?'),
        content: Text(
            '${f.name} will be removed from your friends. You can always add '
            'them again later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    SocialService.removeFriend(f);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${f.name} from friends.')));
    }
    return true;
  }

  /// "Block @username?" confirmation. Returns true if blocked.
  static Future<bool> confirmBlock(BuildContext context, Friend f) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block @${f.username}?'),
        content: const Text(
            'They\'ll be removed as a friend, can\'t send you requests, and '
            'you won\'t see their ratings. You can unblock them later in '
            'Friends.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await SocialService.block(f);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Blocked @${f.username}.')));
    }
    return true;
  }

  /// Long-press action sheet: view profile / remove / block.
  static Future<void> showSheet(
    BuildContext context,
    Friend f, {
    VoidCallback? onOpenProfile,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetContext.colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Text(f.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('@${f.username}'),
            ),
            const Divider(height: 1),
            if (onOpenProfile != null)
              ListTile(
                leading: Icon(Icons.person_outline,
                    color: sheetContext.colors.ink),
                title: const Text('View profile'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onOpenProfile();
                },
              ),
            ListTile(
              leading: Icon(Icons.person_remove_outlined,
                  color: sheetContext.colors.ink),
              title: const Text('Remove friend'),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmRemove(context, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: _danger),
              title: const Text('Block',
                  style: TextStyle(
                      color: _danger, fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.pop(sheetContext);
                confirmBlock(context, f);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
