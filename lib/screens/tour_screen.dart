import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../theme/app_theme.dart';

/// A quick swipeable tour of the app. Shown once after first login and
/// replayable from Settings → About → App tour.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => const TourScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourPage {
  final String emoji;
  final String title;
  final String body;
  const _TourPage(this.emoji, this.title, this.body);
}

const _pages = [
  _TourPage('🍔', 'Rate in 30 seconds',
      'Click the + button, pick the restaurant (it finds the one closest '
      'to you), then drag the scales to rate food and atmosphere. Every '
      'visit gets its own rating — YUMS averages them for you.'),
  _TourPage('📁', 'Keep it organized',
      'Make folders like “Date nights” or “Pizza tour” and drop restaurants '
      'in. Filter by your categories, chains, price or distance — and add '
      'your own categories anytime.'),
  _TourPage('🗺️', 'The Food Map',
      'Every place your friends rated shows as a colored pin — green means '
      'go. Tap a pin to see who liked it, read their takes, and open Google '
      'Maps to call or place an order.'),
  _TourPage('👋', 'Pull up a chair',
      'Add friends by username and see what they\'re eating. Each review is '
      'Friends or Private — you choose every time, and Private never leaves '
      'your phone.'),
  _TourPage('❤️', 'Make it yours',
      'Heart your favorites to show them on your profile. Tweak haptics, '
      'themes and privacy in Settings. Okay — go eat something great!'),
];

class _TourScreenState extends State<TourScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    AppPrefs.setTourSeen(true);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(maxHeight: 480),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppTheme.shadow(context),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 36, 28, 8),
                        child: Column(
                          children: [
                            Text(p.emoji,
                                style: const TextStyle(fontSize: 64)),
                            const SizedBox(height: 18),
                            Text(p.title,
                                textAlign: TextAlign.center,
                                style:
                                    AppTheme.heading(24, color: colors.ink)),
                            const SizedBox(height: 12),
                            Text(p.body,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    height: 1.45,
                                    color: colors.subtle,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    final on = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: on ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: on ? AppTheme.accent : colors.line,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _finish,
                        child: Text('Skip',
                            style: TextStyle(color: colors.subtle)),
                      ),
                      const Spacer(),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: last
                            ? _finish
                            : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic),
                        child: Text(last ? 'Let\'s eat!' : 'Next',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
