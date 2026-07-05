import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../data/friend_group_store.dart';
import '../data/social_service.dart';
import '../data/auth_service.dart';
import '../data/firebase_services.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/gradient_app_bar.dart';
import 'tour_screen.dart';
import 'wrapped_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: const GradientAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          const _SectionLabel('Appearance'),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.mode,
            builder: (context, mode, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.line),
                ),
                child: Column(
                  children: [
                    _themeTile('System', ThemeMode.system, mode),
                    Divider(height: 1, color: colors.line),
                    _themeTile('Light', ThemeMode.light, mode),
                    Divider(height: 1, color: colors.line),
                    _themeTile('Dark', ThemeMode.dark, mode),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Privacy'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('New reviews default to',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: colors.ink)),
                  ),
                ),
                ValueListenableBuilder<String>(
                  valueListenable: AppPrefs.defaultVisibility,
                  builder: (context, vis, _) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        _visOption(context, 'friends', Icons.group_outlined,
                            'Friends', vis),
                        const SizedBox(width: 10),
                        _visOption(context, 'private', Icons.lock_outline,
                            'Private', vis),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: colors.line),
                ValueListenableBuilder<bool>(
                  valueListenable: AppPrefs.categoriesViewable,
                  builder: (context, on, _) => SwitchListTile(
                    value: on,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.accent,
                    title: const Text('Let friends see my categories',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    onChanged: AppPrefs.setCategoriesViewable,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Account'),
          ValueListenableBuilder(
            valueListenable: AuthService.user,
            builder: (context, user, _) {
              return Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.line),
                ),
                child: user == null
                    ? ListTile(
                        leading: const Icon(Icons.login),
                        title: const Text('Sign in with Google'),
                        onTap: () async {
                          try {
                            await FirebaseAuthService.signInWithGoogle();
                          } catch (_) {
                            await AuthService.signInDemo();
                          }
                        },
                      )
                    : ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        subtitle: Text('@${user.username}'),
                        onTap: () => FirebaseAuthService.isCloudSignedIn
                            ? FirebaseAuthService.signOut()
                            : AuthService.signOut(),
                      ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Haptics'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: ValueListenableBuilder<int>(
              valueListenable: AppPrefs.hapticStrength,
              builder: (context, strength, _) {
                const labels = ['None', 'Light', 'Medium', 'Strong'];
                return Row(
                  children: List.generate(4, (i) {
                    final on = i == strength;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        child: GestureDetector(
                          onTap: () async {
                            await AppPrefs.setHapticStrength(i);
                            Haptics.step(); // feel the new strength
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  on ? AppTheme.accent : colors.background,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      on ? AppTheme.accent : colors.line),
                            ),
                            child: Center(
                              child: Text(labels[i],
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: on
                                          ? Colors.white
                                          : colors.ink)),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Notifications'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: AppPrefs.notifArrival,
                  builder: (context, on, _) => SwitchListTile(
                    value: on,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.accent,
                    title: const Text('Rate reminders',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        'Nudge me when I\'m at a place I track (app open)',
                        style:
                            TextStyle(color: colors.subtle, fontSize: 12)),
                    onChanged: AppPrefs.setNotifArrival,
                  ),
                ),
                Divider(height: 1, color: colors.line),
                ValueListenableBuilder<bool>(
                  valueListenable: AppPrefs.notifFriends,
                  builder: (context, on, _) => SwitchListTile(
                    value: on,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppTheme.accent,
                    title: const Text('Friend ratings',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('When friends share new ratings',
                        style:
                            TextStyle(color: colors.subtle, fontSize: 12)),
                    onChanged: AppPrefs.setNotifFriends,
                  ),
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
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('About'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.restaurant_menu),
                  title: Text('YUMS'),
                  subtitle: Text('Alpha pre-release'),
                ),
                Divider(height: 1, color: colors.line),
                ListTile(
                  leading:
                      const Icon(Icons.tour_outlined, color: AppTheme.accent),
                  title: const Text('App tour'),
                  subtitle: Text('Replay the quick intro',
                      style: TextStyle(color: colors.subtle, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: colors.subtle),
                  onTap: () => TourScreen.show(context),
                ),
                Divider(height: 1, color: colors.line),
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppTheme.honey),
                  title: const Text('Preview monthly Wrapped'),
                  subtitle: Text('Your food recap — auto-shows on the 1st',
                      style: TextStyle(color: colors.subtle, fontSize: 12)),
                  trailing: Icon(Icons.chevron_right, color: colors.subtle),
                  onTap: () => WrappedScreen.show(context, DateTime.now()),
                ),
              ],
            ),
          ),
        ],
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

  Widget _visOption(BuildContext context, String key, IconData icon,
      String label, String current) {
    final colors = context.colors;
    final on = key == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => AppPrefs.setVisibility(key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? AppTheme.accent : colors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? AppTheme.accent : colors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: on ? Colors.white : colors.subtle),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: on ? Colors.white : colors.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeTile(String label, ThemeMode value, ThemeMode current) {
    final selected = value == current;
    return ListTile(
      title: Text(label),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppTheme.accent)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () => ThemeController.set(value),
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
