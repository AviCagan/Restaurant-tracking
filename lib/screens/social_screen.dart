import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/sign_in_prompt.dart';
import 'friend_profile_screen.dart';
import 'friends_manage_screen.dart';

/// Combined Friends + Feed: a row of friends up top, their shared ratings below.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  void _openManage(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FriendsManageScreen()));

  void _openProfile(BuildContext context, Friend f) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: f)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: 'Friends',
        actions: [
          ValueListenableBuilder<List<Friend>>(
            valueListenable: SocialService.requests,
            builder: (context, requests, _) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: const Icon(Icons.group_outlined),
                    tooltip: 'Manage friends',
                    onPressed: () => _openManage(context),
                  ),
                  if (requests.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: AppTheme.accent, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${requests.length}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          if (user == null) {
            return const SignInPrompt(
                message:
                    'Add friends to share ratings and see what they\'re eating.');
          }
          final feed = SocialService.feed();
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
            children: [
              _FriendsRow(onTapFriend: (f) => _openProfile(context, f),
                  onAdd: () => _openManage(context)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Recent from friends',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.colors.ink)),
              ),
              ...feed.map((f) => Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: FeedCard(item: f),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _FriendsRow extends StatelessWidget {
  const _FriendsRow({required this.onTapFriend, required this.onAdd});
  final void Function(Friend) onTapFriend;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      height: 92,
      child: ValueListenableBuilder<List<Friend>>(
        valueListenable: SocialService.friends,
        builder: (context, friends, _) {
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Add button
              _RowItem(
                label: 'Add',
                onTap: onAdd,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.line),
                  ),
                  child: Icon(Icons.add, color: colors.subtle),
                ),
              ),
              ...friends.map((f) => _RowItem(
                    label: f.name.split(' ').first,
                    onTap: () => onTapFriend(f),
                    child: PersonAvatar(name: f.name, size: 56),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  const _RowItem(
      {required this.child, required this.label, required this.onTap});
  final Widget child;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            child,
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colors.subtle)),
            ),
          ],
        ),
      ),
    );
  }
}
