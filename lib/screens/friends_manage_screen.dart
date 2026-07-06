import 'package:flutter/material.dart';

import '../data/friend_group_store.dart';
import '../data/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/group_sheets.dart';
import 'friend_profile_screen.dart';

class FriendsManageScreen extends StatefulWidget {
  const FriendsManageScreen({super.key});

  @override
  State<FriendsManageScreen> createState() => _FriendsManageScreenState();
}

class _FriendsManageScreenState extends State<FriendsManageScreen> {
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  void _openProfile(Friend f) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: f)));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Friends'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
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
          ValueListenableBuilder<List<FriendGroup>>(
            valueListenable: FriendGroupStore.all,
            builder: (context, groups, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _SectionHeader('Groups'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => showGroupEditDialog(context),
                        icon: const Icon(Icons.group_add_outlined, size: 18),
                        label: const Text('New'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent),
                      ),
                    ],
                  ),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                          'Group friends (like "Family") to filter the feed '
                          'and map to just them.',
                          style:
                              TextStyle(color: colors.subtle, fontSize: 13)),
                    ),
                  ...groups.map((g) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: AppTheme.panel(context, radius: 16),
                        child: ListTile(
                          leading: GroupAvatar(group: g, size: 30),
                          title: Text(g.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${g.usernames.length} member${g.usernames.length == 1 ? '' : 's'}',
                              style: TextStyle(color: colors.subtle)),
                          trailing:
                              Icon(Icons.edit_outlined, color: colors.subtle),
                          onTap: () =>
                              showGroupEditDialog(context, existing: g),
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
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
                        onTap: () => _openProfile(f),
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
                              icon: Icon(Icons.cancel, color: colors.subtle),
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
                        onTap: () => _openProfile(f),
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
  const _FriendTile(
      {required this.friend, required this.trailing, this.onTap});
  final Friend friend;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: AppTheme.panel(context, radius: 16),
      child: ListTile(
        onTap: onTap,
        leading: PersonAvatar(name: friend.name),
        title: Text(friend.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('@${friend.username}',
            style: TextStyle(color: colors.subtle)),
        trailing: trailing,
      ),
    );
  }
}
