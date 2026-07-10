import 'package:flutter/material.dart';

import '../config.dart';
import '../data/app_prefs.dart';
import '../data/auth_service.dart';
import '../data/firebase_services.dart';
import '../services/calendar_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/gradient_app_bar.dart';
import 'customize_screen.dart';
import 'notification_settings_screen.dart';
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
          const _SectionLabel('Customize'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: ListTile(
              leading: Icon(Icons.palette_outlined, color: AppTheme.accent),
              title: const Text('Make it yours',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Theme color, rating bars & haptics',
                  style: TextStyle(color: colors.subtle, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: colors.subtle),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomizeScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Calendar'),
          ValueListenableBuilder<String>(
            valueListenable: AppPrefs.calendarProvider,
            builder: (context, provider, _) => Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line),
              ),
              child: ListTile(
                leading: Icon(Icons.event_outlined, color: AppTheme.accent),
                title: const Text('Calendar app',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                    '"Add to calendar" uses ${CalendarService.labelFor(provider)}',
                    style: TextStyle(color: colors.subtle, fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: colors.subtle),
                onTap: () async {
                  final choice = await CalendarService.showChooser(context,
                      firstTime: false);
                  if (choice != null) {
                    await AppPrefs.setCalendarProvider(choice);
                  }
                },
              ),
            ),
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Sign-in didn\'t work — check your '
                                          'connection and try again.')));
                            }
                          }
                        },
                      )
                    : ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        subtitle: Text('@${user.username}'),
                        onTap: () async {
                          FirebaseAuthService.isCloudSignedIn
                              ? await FirebaseAuthService.signOut()
                              : await AuthService.signOut();
                          // Back to the root so the welcome screen shows.
                          if (context.mounted) {
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                          }
                        },
                      ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Notifications'),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: ListTile(
              leading:
                  Icon(Icons.notifications_outlined, color: AppTheme.accent),
              title: const Text('What notifies me',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Reminders, friends, requests & plans',
                  style: TextStyle(color: colors.subtle, fontSize: 12)),
              trailing: Icon(Icons.chevron_right, color: colors.subtle),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationSettingsScreen()),
              ),
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
                  subtitle: Text('Alpha pre-release · ${AppConfig.buildTag}'),
                ),
                Divider(height: 1, color: colors.line),
                ListTile(
                  leading:
                      Icon(Icons.tour_outlined, color: AppTheme.accent),
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
          ? Icon(Icons.check_circle, color: AppTheme.accent)
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
