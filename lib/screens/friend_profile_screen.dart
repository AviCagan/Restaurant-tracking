import 'package:flutter/material.dart';

import '../data/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/friend_actions.dart';
import '../widgets/gradient_app_bar.dart';
import 'compare_categories_screen.dart';

class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({super.key, required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
    // Track the live friend record so their bio/photo appear the moment
    // they sync (the constructor copy may predate them).
    return ValueListenableBuilder<List<Friend>>(
      valueListenable: SocialService.friends,
      builder: (context, allFriends, _) {
        final friend = allFriends.firstWhere(
            (f) => f.username == this.friend.username,
            orElse: () => this.friend);
        return _build(context, friend);
      },
    );
  }

  Widget _build(BuildContext context, Friend friend) {
    final colors = context.colors;
    final favorites = SocialService.favoritesFor(friend.name);
    final reviews = SocialService.reviewsFor(friend.name);

    return Scaffold(
      appBar: GradientAppBar(title: friend.name),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: Column(
              children: [
                PersonAvatar(name: friend.name, size: 84),
                const SizedBox(height: 12),
                Text(friend.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                Text('@${friend.username}',
                    style: TextStyle(color: colors.subtle)),
                if (friend.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(friend.bio,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: colors.ink,
                            fontSize: 13.5,
                            height: 1.35)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: AppTheme.panel(context, radius: 16),
            child: ListTile(
              leading: Icon(Icons.category_outlined,
                  color: AppTheme.accent),
              title: const Text('Categories',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Compare & import ${friend.name.split(' ').first}\'s categories',
                  style: TextStyle(color: colors.subtle, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: colors.subtle),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CompareCategoriesScreen(friend: friend)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (favorites.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.favorite, size: 18, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text('Favorites',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: favorites
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: colors.line),
                        ),
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 26),
          ],

          const Text('Reviews',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            Text('No shared reviews yet.',
                style: TextStyle(color: colors.subtle))
          else
            ...reviews.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FeedCard(item: r, showWho: false),
                )),

          const SizedBox(height: 28),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                final blocked =
                    await FriendActions.confirmBlock(context, friend);
                // Leave the profile once they're blocked.
                if (blocked && context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.block, size: 16),
              style: TextButton.styleFrom(foregroundColor: colors.subtle),
              label: Text('Block @${friend.username}',
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
