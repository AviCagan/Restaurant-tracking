import 'package:flutter/material.dart';

import '../data/firebase_services.dart';
import '../theme/app_theme.dart';

/// Shown on social tabs when the user isn't signed in.
class SignInPrompt extends StatefulWidget {
  const SignInPrompt({super.key, required this.message, this.onSignedIn});

  final String message;
  final VoidCallback? onSignedIn;

  @override
  State<SignInPrompt> createState() => _SignInPromptState();
}

class _SignInPromptState extends State<SignInPrompt> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      final profile = await FirebaseAuthService.signInWithGoogle();
      if (profile != null) widget.onSignedIn?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sign-in didn\'t work — check your internet '
                'connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👋', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 12),
            Text('Sign in to connect',
                style: AppTheme.heading(22, color: colors.ink)),
            const SizedBox(height: 8),
            Text(widget.message,
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
                onPressed: _busy ? null : _google,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login),
                label: const Text('Continue with Google',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
