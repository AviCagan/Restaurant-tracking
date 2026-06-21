import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/gradient_app_bar.dart';

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
                        title: const Text('Sign in'),
                        onTap: () => AuthService.signInDemo(),
                      )
                    : ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Sign out'),
                        subtitle: Text('@${user.username}'),
                        onTap: () => AuthService.signOut(),
                      ),
              );
            },
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
                  title: Text('Restaurant Tracker'),
                  subtitle: Text('Version 1.0.0 (preview)'),
                ),
                Divider(height: 1, color: colors.line),
                ListTile(
                  leading: const Icon(Icons.science_outlined,
                      color: AppTheme.accent),
                  title: const Text('Sharing is in preview'),
                  subtitle: Text(
                      'Accounts & feed are local mocks. Cloud sync via Firebase '
                      'is the next step.',
                      style: TextStyle(color: colors.subtle, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
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
