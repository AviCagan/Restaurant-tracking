import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_prompt.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          if (user == null) {
            return const SignInPrompt(
                message: 'Add friends to share and compare your ratings.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              // Add friend
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Add by username',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        SocialService.addFriend(_addCtrl.text);
                        _addCtrl.clear();
                        setState(() {});
                      },
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Requests
              ValueListenableBuilder<List<Friend>>(
                valueListenable: SocialService.requests,
                builder: (context, requests, _) {
                  if (requests.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Requests (${requests.length})'),
                      ...requests.map((f) => _FriendTile(
                            friend: f,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle,
                                      color: Color(0xFF34C759)),
                                  onPressed: () => setState(
                                      () => SocialService.acceptRequest(f)),
                                ),
                                IconButton(
                                  icon: Icon(Icons.cancel,
                                      color: colors.subtle),
                                  onPressed: () => setState(
                                      () => SocialService.declineRequest(f)),
                                ),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // Friends
              ValueListenableBuilder<List<Friend>>(
                valueListenable: SocialService.friends,
                builder: (context, friends, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Friends (${friends.length})'),
                      if (friends.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text('No friends yet — add some above.',
                              style: TextStyle(color: colors.subtle)),
                        ),
                      ...friends.map((f) => _FriendTile(
                            friend: f,
                            trailing: IconButton(
                              icon: Icon(Icons.person_remove_outlined,
                                  color: colors.subtle),
                              onPressed: () =>
                                  setState(() => SocialService.removeFriend(f)),
                            ),
                          )),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend, required this.trailing});
  final Friend friend;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(friend.initials,
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('@${friend.username}',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
