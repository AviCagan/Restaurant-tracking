import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../data/firebase_services.dart';
import '../theme/app_theme.dart';

/// First screen: sign in with Google for the full social experience, or
/// continue offline with just the rating/tracking features.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _google() async {
    setState(() => _busy = true);
    try {
      await FirebaseAuthService.signInWithGoogle();
      // Auth state listener flips the app to MainScaffold.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Sign-in didn\'t work — check your connection and try again. '
                'You can also continue offline below.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.accentGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                // Logo
                Container(
                  width: 148,
                  height: 148,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/icon/icon_fg.png'),
                ),
                const SizedBox(height: 20),
                Text('YUMS',
                    style: AppTheme.heading(52,
                        color: Colors.white, weight: FontWeight.w700)),
                Text(
                  'Rate it. Remember it. Share it.',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.accentDark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: _busy ? null : _google,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.login),
                    label: const Text('Continue with Google',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed:
                        _busy ? null : () => AppPrefs.setLocalMode(true),
                    child: const Text('Use offline (no account)',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Offline mode keeps everything on your phone — you can '
                  'sign in anytime for friends, the feed & the food map.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11.5),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
