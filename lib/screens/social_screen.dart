import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'package:intl/intl.dart';

import '../data/friend_group_store.dart';
import '../data/plan_store.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/group_sheets.dart';
import '../widgets/sign_in_prompt.dart';
import 'friend_profile_screen.dart';
import 'friends_manage_screen.dart';

/// Combined Friends + Feed: a row of friends up top, their shared ratings
/// below, filterable by friend group.
class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  String? _groupId; // null = everyone

  void _openManage(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const FriendsManageScreen()));

  void _openProfile(BuildContext context, Friend f) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => FriendProfileScreen(friend: f)));

  List<FeedItem> _filteredFeed() {
    final feed = SocialService.feed();
    final group = _groupId == null ? null : FriendGroupStore.byId(_groupId!);
    if (group == null) return feed;
    // Map friend names -> usernames to match against the group.
    final nameToUsername = {
      for (final f in SocialService.friends.value) f.name: f.username
    };
    return feed
        .where((i) =>
            group.usernames.contains(nameToUsername[i.friendName] ?? ''))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          if (user == null) {
            return const SignInPrompt(
                message:
                    'Add friends to share ratings and see what they\'re eating.');
          }
          final feed = _filteredFeed();
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    Text('Your table',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.colors.ink)),
                    const Spacer(),
                    ValueListenableBuilder<List<Friend>>(
                      valueListenable: SocialService.requests,
                      builder: (context, requests, _) => TextButton.icon(
                        onPressed: () => _openManage(context),
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: Text(requests.isEmpty
                            ? 'Manage'
                            : 'Manage (${requests.length})'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent),
                      ),
                    ),
                  ],
                ),
              ),
              _FriendsRow(onTapFriend: (f) => _openProfile(context, f),
                  onAdd: () => _openManage(context)),
              const _UpcomingPlans(),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Friends',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.colors.ink)),
              ),
              _GroupChips(
                selected: _groupId,
                onSelect: (id) => setState(() => _groupId = id),
              ),
              const SizedBox(height: 4),
              if (feed.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _groupId == null
                        ? 'Nothing here yet — once friends share ratings, '
                            'they\'ll show up right here.'
                        : 'No shared ratings from this group yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.subtle),
                  ),
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

/// Upcoming plans: your own plans + invites friends sent you.
class _UpcomingPlans extends StatelessWidget {
  const _UpcomingPlans();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<List<Plan>>(
      valueListenable: PlanStore.all,
      builder: (context, plans, _) {
        return ValueListenableBuilder<List<PlanInvite>>(
          valueListenable: SocialService.invites,
          builder: (context, invites, _) {
            final upcoming = plans
                .where((p) => p.when.isAfter(
                    DateTime.now().subtract(const Duration(hours: 3))))
                .toList();
            if (upcoming.isEmpty && invites.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text('Upcoming plans',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: colors.ink)),
                ),
                ...upcoming.map((p) => _planRow(
                      context,
                      emoji: '📅',
                      title: p.restaurantName,
                      subtitle:
                          '${DateFormat.MMMEd().add_jm().format(p.when)}'
                          '${p.friendUsernames.isEmpty ? '' : ' · ${p.friendUsernames.length} invited'}',
                      onDelete: () => PlanStore.delete(p.id),
                    )),
                ...invites.map((i) => _planRow(
                      context,
                      emoji: '💌',
                      title: '${i.fromName} → ${i.restaurantName}',
                      subtitle: DateFormat.MMMEd().add_jm().format(i.when),
                    )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _planRow(BuildContext context,
      {required String emoji,
      required String title,
      required String subtitle,
      VoidCallback? onDelete}) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.panel(context, radius: 16),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: colors.subtle),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}

/// Group filter chips: Everyone + each group (long-press to edit) + New.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder<List<FriendGroup>>(
      valueListenable: FriendGroupStore.all,
      builder: (context, groups, _) {
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip(context, '👥', 'Everyone', selected == null,
                  () => onSelect(null)),
              ...groups.map((g) => _chip(
                    context,
                    g.emoji,
                    g.name,
                    selected == g.id,
                    () => onSelect(selected == g.id ? null : g.id),
                    onLongPress: () async {
                      final changed = await showGroupEditDialog(context,
                          existing: g);
                      if (changed && FriendGroupStore.byId(g.id) == null) {
                        onSelect(null); // group deleted
                      }
                    },
                  )),
              GestureDetector(
                onTap: () => showGroupEditDialog(context),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.line, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.group_add_outlined,
                          size: 16, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Text('New group',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: colors.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, String emoji, String label, bool on,
      VoidCallback onTap,
      {VoidCallback? onLongPress}) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: on ? AppTheme.accentGradient : null,
          color: on ? null : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: on ? Colors.transparent : colors.line, width: 1.5),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: on ? Colors.white : colors.ink)),
          ],
        ),
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
