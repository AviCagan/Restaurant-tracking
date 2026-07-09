import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_rating_bar.dart';

/// Full-screen animated tour. Shown once after first login and replayable
/// from Settings → About → App tour. Each page has its own gradient, a
/// hero emoji, and staggered feature cards — page one has a live rating
/// bar to play with.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const TourScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _Feature {
  final IconData icon;
  final String text;
  const _Feature(this.icon, this.text);
}

class _TourPage {
  final String emoji;
  final String title;
  final String tagline;
  final List<_Feature> features;
  final Color top;
  final Color bottom;
  final bool demo;

  const _TourPage({
    required this.emoji,
    required this.title,
    required this.tagline,
    required this.features,
    required this.top,
    required this.bottom,
    this.demo = false,
  });
}

const _pages = [
  _TourPage(
    emoji: '🍔',
    title: 'Rate in 30 seconds',
    tagline: 'Tap + on the home screen, pick the place, tap the bar. Done.',
    top: Color(0xFFF59E6C),
    bottom: Color(0xFFD65F31),
    demo: true,
    features: [
      _Feature(Icons.touch_app_outlined,
          'Search finds the restaurant nearest you first'),
      _Feature(Icons.takeout_dining_outlined,
          'Takeout order? Flip the toggle — no atmosphere to rate'),
      _Feature(Icons.add_circle_outline,
          '"Add details" for dishes, photos and notes — all optional'),
    ],
  ),
  _TourPage(
    emoji: '🌟',
    title: 'Spotted somewhere good?',
    tagline: 'Save places you haven\'t been to yet.',
    top: Color(0xFFFFC24B),
    bottom: Color(0xFFE8A21D),
    features: [
      _Feature(Icons.bookmark_outline,
          'Flick "Want to go" when adding — it skips the rating'),
      _Feature(Icons.star_outline,
          'Wishlist spots wear a gold star until your first visit'),
      _Feature(Icons.filter_alt_outlined,
          'The "Want to go" filter on home shows just your list'),
    ],
  ),
  _TourPage(
    emoji: '📅',
    title: 'Plan the next meal',
    tagline: 'Date, time, crew — all in one sheet.',
    top: Color(0xFF7FB88C),
    bottom: Color(0xFF54835F),
    features: [
      _Feature(Icons.group_add_outlined,
          'Invite friends or whole groups — they RSVP with one tap'),
      _Feature(Icons.how_to_reg_outlined,
          'See who\'s in; who can\'t make it tucks into the corner'),
      _Feature(Icons.event_available_outlined,
          'Reminders before & after, plus Google or Apple Calendar'),
    ],
  ),
  _TourPage(
    emoji: '🗺️',
    title: 'The Food Map',
    tagline: 'Every rated spot from you and your friends, pinned.',
    top: Color(0xFF6FAEDC),
    bottom: Color(0xFF3574A6),
    features: [
      _Feature(Icons.place_outlined,
          'Greener pin = better eats. Tap one for everyone\'s takes'),
      _Feature(Icons.category_outlined,
          'Filter by categories or people — same-named categories '
              'auto-link with friends'),
      _Feature(Icons.directions_outlined,
          'Jump to Google Maps to call, order, or navigate'),
    ],
  ),
  _TourPage(
    emoji: '👥',
    title: 'Pull up a chair',
    tagline: 'Food\'s better with friends.',
    top: Color(0xFFE87FA3),
    bottom: Color(0xFFC94570),
    features: [
      _Feature(Icons.alternate_email,
          'Add friends by username; group them ("Family", "Work crew")'),
      _Feature(Icons.lock_outline,
          'Every review is Friends or Private — your call, every time'),
      _Feature(Icons.attach_money,
          'Friends see your rating and your price take'),
    ],
  ),
  _TourPage(
    emoji: '🔔',
    title: 'Stay in the loop',
    tagline: 'Hear about it without being buried in pings.',
    top: Color(0xFFAF85D6),
    bottom: Color(0xFF7E4FA8),
    features: [
      _Feature(Icons.notifications_active_outlined,
          'Requests, invites and RSVPs notify you right away'),
      _Feature(Icons.mark_email_read_outlined,
          'Email alerts too — friends\' ratings arrive as one daily digest'),
      _Feature(Icons.tune,
          'Pick exactly what notifies you in Settings → Notifications'),
    ],
  ),
  _TourPage(
    emoji: '🎨',
    title: 'Make it yours',
    tagline: 'Then go eat something great.',
    top: Color(0xFFF07A4B),
    bottom: Color(0xFF9B4A26),
    features: [
      _Feature(Icons.palette_outlined,
          'Six theme colors, custom rating bars & haptics in Customize'),
      _Feature(Icons.favorite_outline,
          'Heart favorites to headline your profile'),
      _Feature(Icons.auto_awesome,
          'Every month: your own food Wrapped 🎉'),
    ],
  ),
];

class _TourScreenState extends State<TourScreen> {
  final _controller = PageController();
  int _page = 0;
  int _demoRating = 7;

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
    final p = _pages[_page];
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [p.top, p.bottom],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar: progress + skip.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Text('${_page + 1} / ${_pages.length}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    const Spacer(),
                    if (!last)
                      TextButton(
                        onPressed: _finish,
                        child: Text('Skip',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) {
                    Haptics.tick();
                    setState(() => _page = i);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (_, i) => _buildPage(_pages[i], i),
                ),
              ),
              // Dots.
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
                      color: Colors.white
                          .withValues(alpha: on ? 1 : 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              // Nav buttons.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Row(
                  children: [
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _page == 0 ? 0 : 1,
                      child: IconButton(
                        onPressed: _page == 0
                            ? null
                            : () => _controller.previousPage(
                                duration:
                                    const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic),
                        icon: const Icon(Icons.arrow_back,
                            color: Colors.white),
                        style: IconButton.styleFrom(
                          side: BorderSide(
                              color:
                                  Colors.white.withValues(alpha: 0.6)),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: p.bottom,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: last
                          ? _finish
                          : () => _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic),
                      child: Text(last ? 'Let\'s eat! 🍽️' : 'Next',
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
    );
  }

  Widget _buildPage(_TourPage p, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Column(
        children: [
          _Reveal(
            slot: 0,
            pageKey: index,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Center(
                child:
                    Text(p.emoji, style: const TextStyle(fontSize: 46)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Reveal(
            slot: 1,
            pageKey: index,
            child: Text(p.title,
                textAlign: TextAlign.center,
                style: AppTheme.heading(28,
                    color: Colors.white, weight: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          _Reveal(
            slot: 2,
            pageKey: index,
            child: Text(p.tagline,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 20),
          if (p.demo)
            _Reveal(
              slot: 3,
              pageKey: index,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TapRatingBar(
                      label: 'Food',
                      emoji: '🍔',
                      value: _demoRating,
                      onChanged: (v) =>
                          setState(() => _demoRating = v),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text('☝️ Go on, tap it — that\'s the whole '
                          'rating flow!',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.colors.subtle)),
                    ),
                  ],
                ),
              ),
            ),
          if (p.demo) const SizedBox(height: 12),
          ...List.generate(p.features.length, (j) {
            final f = p.features[j];
            return _Reveal(
              slot: (p.demo ? 4 : 3) + j,
              pageKey: index,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child:
                          Icon(f.icon, size: 19, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(f.text,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.3,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Fades + slides its child up, staggered by [slot]; replays per page.
class _Reveal extends StatelessWidget {
  const _Reveal(
      {required this.slot, required this.pageKey, required this.child});
  final int slot;
  final int pageKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('reveal-$pageKey-$slot'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + slot * 90),
      curve: Curves.easeOutCubic,
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 22 * (1 - v)), child: c),
      ),
      child: child,
    );
  }
}
