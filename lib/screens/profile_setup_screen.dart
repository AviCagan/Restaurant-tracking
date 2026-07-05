import 'package:flutter/material.dart';

import '../data/firebase_services.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector.dart';

/// Quick first-time setup after Google sign-in: name, username, and a first
/// pass over categories. Everything can be changed later.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final _nameCtrl =
      TextEditingController(text: FirebaseAuthService.suggestedName());
  late final _userCtrl =
      TextEditingController(text: FirebaseAuthService.suggestedUsername());
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    final error = await FirebaseAuthService.completeSetup(
        _nameCtrl.text, _userCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
    // On success the app gate flips to MainScaffold automatically.
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, topInset + 24, 24, 24),
            decoration: const BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Almost there! 🎉',
                    style: AppTheme.heading(28, color: Colors.white)),
                Text('Set up your profile in 30 seconds.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                Text('Your name',
                    style: AppTheme.heading(16, color: colors.ink)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'What friends call you'),
                ),
                const SizedBox(height: 20),
                Text('Pick a username',
                    style: AppTheme.heading(16, color: colors.ink)),
                const SizedBox(height: 4),
                Text('Friends add you with this — lowercase, no spaces.',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.alternate_email),
                    hintText: 'username',
                  ),
                ),
                const SizedBox(height: 24),
                Text('Your categories',
                    style: AppTheme.heading(16, color: colors.ink)),
                const SizedBox(height: 4),
                Text(
                    'Here\'s a starter set — tap Add to make your own, '
                    'long-press to remove.',
                    style: TextStyle(fontSize: 12, color: colors.subtle)),
                const SizedBox(height: 10),
                CategorySelector(
                  selected: const {},
                  editable: true,
                  onChanged: (_) {},
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.honey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Text('💡', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'All of this can be changed later from your profile '
                          'and settings.',
                          style: TextStyle(
                              fontSize: 12,
                              color: colors.ink,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _finish,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Let\'s go!',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
