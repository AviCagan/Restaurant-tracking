import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../theme/app_theme.dart';

/// Shown on social tabs when the user isn't signed in.
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({super.key, required this.message, this.onSignedIn});

  final String message;
  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, size: 64, color: colors.subtle),
            const SizedBox(height: 16),
            const Text('Sign in to connect',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.subtle)),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                ),
                onPressed: () async {
                  await AuthService.signInDemo();
                  onSignedIn?.call();
                },
                icon: const Icon(Icons.login),
                label: const Text('Continue (demo)',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Preview: accounts & syncing are local for now.',
                style: TextStyle(fontSize: 11.5, color: colors.subtle)),
          ],
        ),
      ),
    );
  }
}
