import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../data/friend_group_store.dart';
import '../data/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';

/// Settings → Notifications: pick exactly which notifications you get.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Notifications'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const _SectionLabel('Me'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: _toggle(
              colors,
              AppPrefs.notifArrival,
              AppPrefs.setNotifArrival,
              'Rate reminders',
              'Nudge me when I\'m at a place I track (app open)',
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Friends'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                _toggle(
                  colors,
                  AppPrefs.notifFriends,
                  AppPrefs.setNotifFriends,
                  'Friend ratings',
                  'When friends share new ratings',
                ),
                Divider(height: 1, color: colors.line),
                ListTile(
                  leading:
                      Icon(Icons.filter_alt_outlined, color: colors.subtle),
                  title: const Text('Which friends notify me',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: colors.subtle),
                  onTap: () => _customizeFriendNotifs(context),
                ),
                Divider(height: 1, color: colors.line),
                _toggle(
                  colors,
                  AppPrefs.notifSocial,
                  AppPrefs.setNotifSocial,
                  'Friend requests',
                  'New requests and when someone accepts yours',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Plans'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: _toggle(
              colors,
              AppPrefs.notifPlans,
              AppPrefs.setNotifPlans,
              'Plan invites & RSVPs',
              'Invites from friends, and who\'s in / who can\'t make it',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Plan reminders ("2 hours before" / "rate it after") are chosen '
            'per plan when you create it.',
            style: TextStyle(fontSize: 12, color: colors.subtle),
          ),
        ],
      ),
    );
  }

  Widget _toggle(AppColors colors, ValueNotifier<bool> pref,
      Future<void> Function(bool) setter, String title, String sub) {
    return ValueListenableBuilder<bool>(
      valueListenable: pref,
      builder: (context, on, _) => SwitchListTile(
        value: on,
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.accent,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Text(sub, style: TextStyle(color: colors.subtle, fontSize: 12)),
        onChanged: setter,
      ),
    );
  }

  /// Choose which friends' ratings notify you: everyone, specific groups,
  /// or specific friends.
  Future<void> _customizeFriendNotifs(BuildContext context) async {
    var mode = 'all';
    var ids = <String>{};
    try {
      final raw = AppPrefs.notifFriendsFilter.value;
      if (raw.isNotEmpty) {
        final d = jsonDecode(raw) as Map<String, dynamic>;
        mode = d['mode'] as String? ?? 'all';
        ids = (d['ids'] as List? ?? []).map((e) => e.toString()).toSet();
      }
    } catch (_) {}

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          final colors = context.colors;
          void save() => AppPrefs.setNotifFriendsFilter(
              jsonEncode({'mode': mode, 'ids': ids.toList()}));

          Widget modeChip(String value, String label) {
            final on = mode == value;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setSheet(() {
                    mode = value;
                    ids.clear();
                  });
                  save();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: on ? AppTheme.accent : colors.background,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: on ? AppTheme.accent : colors.line),
                  ),
                  child: Center(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: on ? Colors.white : colors.ink)),
                  ),
                ),
              ),
            );
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notify me about…',
                      style: AppTheme.heading(18, color: colors.ink)),
                  const SizedBox(height: 14),
                  Row(children: [
                    modeChip('all', 'Everyone'),
                    modeChip('groups', 'Groups'),
                    modeChip('friends', 'Friends'),
                  ]),
                  const SizedBox(height: 14),
                  if (mode == 'groups')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FriendGroupStore.all.value.map((g) {
                        final on = ids.contains(g.id);
                        return FilterChip(
                          selected: on,
                          selectedColor:
                              AppTheme.accent.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.accent,
                          avatar: Text(g.emoji,
                              style: const TextStyle(fontSize: 14)),
                          label: Text(g.name),
                          onSelected: (_) {
                            setSheet(
                                () => on ? ids.remove(g.id) : ids.add(g.id));
                            save();
                          },
                        );
                      }).toList(),
                    ),
                  if (mode == 'friends')
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: SocialService.friends.value.map((f) {
                        final on = ids.contains(f.username);
                        return FilterChip(
                          selected: on,
                          selectedColor:
                              AppTheme.accent.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.accent,
                          label: Text(f.name),
                          onSelected: (_) {
                            setSheet(() => on
                                ? ids.remove(f.username)
                                : ids.add(f.username));
                            save();
                          },
                        );
                      }).toList(),
                    ),
                  if (mode != 'all' && ids.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('Pick at least one, or nothing will notify.',
                          style:
                              TextStyle(fontSize: 12, color: colors.subtle)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );
}
