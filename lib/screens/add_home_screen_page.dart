import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../data/app_prefs.dart';
import '../services/web_bridge/web_bridge.dart' as web;
import '../theme/app_theme.dart';

/// Shown once on the web version after sign-in: get YUMS onto the home
/// screen. On Android Chrome a button pops the real install dialog; on
/// iPhone Safari (no install API exists) it walks through the two taps.
class AddHomeScreenPage extends StatelessWidget {
  const AddHomeScreenPage({super.key});

  Future<void> _done() => AppPrefs.setA2hsSeen(true);

  @override
  Widget build(BuildContext context) {
    final canInstall = web.canInstallPwa();
    final isIos = web.isIosBrowser();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.accentGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.asset('assets/icon/icon_fg.png'),
                ),
                const SizedBox(height: 18),
                Text('Put YUMS on your\nHome Screen',
                    textAlign: TextAlign.center,
                    style: AppTheme.heading(30,
                        color: Colors.white, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Full screen, its own icon — just like a real app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                // Android visitors can run the real app — better than any
                // website (notifications, photos, the works).
                if (web.isAndroidBrowser()) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text('🤖  You\'re on Android!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          AppConfig.playStoreUrl.isEmpty
                              ? 'The real Android app has notifications, '
                                  'photos and everything — ask Avi for the '
                                  'APK! 📲'
                              : 'The real Android app has notifications, '
                                  'photos and everything:',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        if (AppConfig.playStoreUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.accentDark,
                            ),
                            onPressed: () => launchUrl(
                                Uri.parse(AppConfig.playStoreUrl),
                                mode: LaunchMode.externalApplication),
                            icon: const Icon(Icons.shop, size: 18),
                            label: const Text('Get it on Google Play',
                                style:
                                    TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (canInstall)
                  // Android Chrome/Edge: we can pop the real install dialog.
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
                      onPressed: () async {
                        await web.promptInstallPwa();
                        await _done();
                      },
                      icon: const Icon(Icons.add_to_home_screen),
                      label: const Text('Add to Home Screen',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  )
                else
                  // iPhone Safari has no install API — show the two taps.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _step(
                            '1',
                            isIos
                                ? 'Tap the Share button below'
                                : 'Open your browser\'s menu',
                            isIos ? Icons.ios_share : Icons.more_vert),
                        const SizedBox(height: 14),
                        _step(
                            '2',
                            isIos
                                ? 'Scroll down, tap "Add to Home Screen"'
                                : 'Tap "Add to home screen" / "Install app"',
                            Icons.add_box_outlined),
                        const SizedBox(height: 14),
                        _step('3', 'Tap Add — that\'s it! 🎉',
                            Icons.check_circle_outline),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _done,
                  child: Text(
                      canInstall ? 'Maybe later' : 'Done — take me to YUMS',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The card is always white, so text colors are fixed (not theme-driven).
  Widget _step(String n, String text, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(n,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: AppTheme.accent)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4A3B32))),
        ),
        Icon(icon, size: 20, color: const Color(0xFFA38F80)),
      ],
    );
  }
}
