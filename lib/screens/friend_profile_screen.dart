import 'package:flutter/material.dart';

import '../data/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/gradient_app_bar.dart';

class FriendProfileScreen extends StatelessWidget {
  const FriendProfileScreen({super.key, required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context) {
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (favorites.isNotEmpty) ...[
            const Row(
              children: [
                Icon(Icons.favorite, size: 18, color: AppTheme.accent),
                SizedBox(width: 8),
                Text('Favorites',
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
        ],
      ),
    );
  }
}
