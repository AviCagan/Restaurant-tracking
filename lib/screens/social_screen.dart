import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import 'package:intl/intl.dart';

import '../data/friend_group_store.dart';
import '../data/plan_store.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feed_card.dart';
import '../widgets/friend_actions.dart';
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
                ...upcoming.map((p) => _myPlanRow(context, p)),
                ...invites.map((i) => _inviteRow(context, i)),
              ],
            );
          },
        );
      },
    );
  }

  static String _firstNameFor(String username) {
    for (final f in SocialService.friends.value) {
      if (f.username == username) return f.name.split(' ').first;
    }
    return username;
  }

  /// One of my plans: date, who's in, and — tucked in the corner — a tap
  /// target listing who couldn't make it.
  Widget _myPlanRow(BuildContext context, Plan p) {
    final colors = context.colors;
    final going = p.going.map(_firstNameFor).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.panel(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📅', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(
                        '${DateFormat.MMMEd().add_jm().format(p.when)}'
                        '${p.friendUsernames.isEmpty ? '' : ' · ${p.friendUsernames.length} invited'}'
                        '${p.isJoined ? ' · ${p.ownerName.split(' ').first}\'s plan' : ''}',
                        style:
                            TextStyle(fontSize: 12, color: colors.subtle)),
                  ],
                ),
              ),
              if (p.declined.isNotEmpty)
                GestureDetector(
                  onTap: () => _showDeclined(context, p),
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0484D).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${p.declined.length} can\'t',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE0484D)),
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.subtle),
                onPressed: () => _removePlan(context, p),
              ),
            ],
          ),
          if (going.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, bottom: 4),
              child: Text('✅ In: ${going.join(', ')}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E9E5B))),
            ),
        ],
      ),
    );
  }

  /// Removing a plan means different things: cancel it for everyone (my
  /// plan with invitees), tell the owner I can't make it (a joined plan),
  /// or just delete it (solo plan).
  Future<void> _removePlan(BuildContext context, Plan p) async {
    void cancelReminders() {
      final baseId = p.id.hashCode & 0x7ffffff;
      NotificationService.cancel(baseId);
      NotificationService.cancel(baseId + 1);
    }

    if (p.isJoined) {
      final out = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Can\'t make it anymore?'),
          content: Text(
              '${p.ownerName.split(' ').first} will be told you\'re out of '
              'the ${p.restaurantName} plan.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep plan')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE0484D)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Can\'t make it'),
            ),
          ],
        ),
      );
      if (out != true) return;
      await SocialService.cloudSendReply
          ?.call(p.ownerUid, p.id, false, p.restaurantName, p.when);
      cancelReminders();
      await PlanStore.delete(p.id);
      return;
    }

    if (p.friendUsernames.isEmpty) {
      cancelReminders();
      await PlanStore.delete(p.id); // solo plan — nothing to broadcast
      return;
    }

    final cancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this plan?'),
        content: Text(
            'Everyone invited to ${p.restaurantName} will see it\'s off '
            'right away.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep plan')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE0484D)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel for everyone'),
          ),
        ],
      ),
    );
    if (cancel != true) return;
    await SocialService.cloudCancelPlan?.call(p);
    cancelReminders();
    await PlanStore.delete(p.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Plan cancelled — everyone\'s been told.')));
    }
  }

  void _showDeclined(BuildContext context, Plan p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Couldn\'t make it 😢',
                  style:
                      AppTheme.heading(18, color: sheetContext.colors.ink)),
              const SizedBox(height: 10),
              ...p.declined.map((u) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        PersonAvatar(name: _firstNameFor(u), size: 32),
                        const SizedBox(width: 10),
                        Text(_firstNameFor(u),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const Spacer(),
                        Text('@$u',
                            style: TextStyle(
                                fontSize: 12,
                                color: sheetContext.colors.subtle)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  /// An invite from a friend, with accept / decline right on the card.
  Widget _inviteRow(BuildContext context, PlanInvite i) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: AppTheme.panel(context, radius: 16),
      child: Row(
        children: [
          const Text('💌', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i.fromName} → ${i.restaurantName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
                Text(DateFormat.MMMEd().add_jm().format(i.when),
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'I\'m in!',
            icon: const Icon(Icons.check_circle,
                color: Color(0xFF2E9E5B), size: 26),
            onPressed: () async {
              await SocialService.respondInvite(i, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'You\'re in — added ${i.restaurantName} to your plans! 🙌')));
              }
            },
          ),
          IconButton(
            tooltip: 'Can\'t make it',
            icon: Icon(Icons.cancel_outlined, color: colors.subtle, size: 24),
            onPressed: () async {
              await SocialService.respondInvite(i, false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Let ${i.fromName} know you can\'t make it.')));
              }
            },
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
              _chip(context, const Text('👥', style: TextStyle(fontSize: 14)),
                  'Everyone', selected == null, () => onSelect(null)),
              ...groups.map((g) => _chip(
                    context,
                    GroupAvatar(group: g, size: 18),
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
                      Icon(Icons.group_add_outlined,
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

  Widget _chip(BuildContext context, Widget leading, String label, bool on,
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
            leading,
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
                    onLongPress: () => FriendActions.showSheet(context, f,
                        onOpenProfile: () => onTapFriend(f)),
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
      {required this.child,
      required this.label,
      required this.onTap,
      this.onLongPress});
  final Widget child;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
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
