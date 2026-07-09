import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../services/haptics.dart';
import '../theme/app_theme.dart';
import '../widgets/tap_rating_bar.dart';

/// Full-screen animated tour: five quick pages, barely any reading, and a
/// live rating bar to play with. Shown once after first login, replayable
/// from Settings → About → App tour.
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
    this.features = const [],
    required this.top,
    required this.bottom,
    this.demo = false,
  });
}

const _pages = [
  _TourPage(
    emoji: '🍔',
    title: 'Rate it',
    tagline: 'Tap or drag — try it right here:',
    top: Color(0xFFF59E6C),
    bottom: Color(0xFFD65F31),
    demo: true,
    features: [
      _Feature(Icons.add_circle_outline, 'Tap + to add a spot'),
      _Feature(Icons.group_outlined,
          'Share with your friends in 30 seconds or less!'),
    ],
  ),
  _TourPage(
    emoji: '🌟',
    title: 'Save & plan',
    tagline: 'For places you haven\'t hit yet.',
    top: Color(0xFFFFC24B),
    bottom: Color(0xFFE8A21D),
    features: [
      _Feature(Icons.bookmark_outline, '"Want to go" saves it for later'),
      _Feature(Icons.event_outlined, 'Plan a visit, invite friends'),
      _Feature(Icons.how_to_reg_outlined, 'They RSVP — see who\'s in'),
    ],
  ),
  _TourPage(
    emoji: '🗺️',
    title: 'The Food Map',
    tagline: 'You + your friends, pinned.',
    top: Color(0xFF6FAEDC),
    bottom: Color(0xFF3574A6),
    features: [
      _Feature(Icons.place_outlined,
          'Check out where all the good spots are at!'),
      _Feature(Icons.touch_app_outlined, 'Tap a pin for everyone\'s takes'),
    ],
  ),
  _TourPage(
    emoji: '👥',
    title: 'Your people',
    tagline: 'No strangers, no fake reviews.',
    top: Color(0xFFE87FA3),
    bottom: Color(0xFFC94570),
    features: [
      _Feature(Icons.alternate_email, 'Add friends by username'),
      _Feature(Icons.lock_outline, 'Each review: Friends or Private'),
    ],
  ),
  _TourPage(
    emoji: '🎨',
    title: 'Make it yours',
    tagline: 'Then go eat something great.',
    top: Color(0xFF9B6BC7),
    bottom: Color(0xFF7E4FA8),
    features: [
      _Feature(Icons.palette_outlined, 'Themes & custom rating bars'),
      _Feature(Icons.auto_awesome, 'Monthly food Wrapped 🎉'),
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

  Future<void> _finish() async {
    // First run: MainScaffold swaps us out the moment this flag flips (no
    // navigation involved). Replays from Settings arrive as a pushed route,
    // which the maybePop dismisses; on first run it's a safe no-op.
    await AppPrefs.setTourSeen(true);
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pages[_page];
    final last = _page == _pages.length - 1;
    // In a mobile browser the bottom edge hides under the browser's own
    // toolbar (Safari especially) — keep our controls well above it.
    const bottomLift = kIsWeb ? 40.0 : 18.0;

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
                      color:
                          Colors.white.withValues(alpha: on ? 1 : 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, bottomLift),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: p.bottom,
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
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
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
                style: AppTheme.heading(30,
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 22),
          if (p.demo) ...[
            const SizedBox(height: 8),
            _Reveal(
              slot: 3,
              pageKey: index,
              // Shield: drags that start on the card belong to the rating
              // bar (or die here) — they never swipe the page.
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TapRatingBar(
                        label: 'Food',
                        emoji: '🍔',
                        value: _demoRating,
                        onChanged: (v) => setState(() => _demoRating = v),
                      ),
                    ),
                    // A playful "Try it!" bubble perched on the card.
                    Positioned(
                      top: -14,
                      right: 10,
                      child: Transform.rotate(
                        angle: 0.06,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC24B),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Text('Try it! 👇',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4A3B32))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...List.generate(p.features.length, (j) {
            final f = p.features[j];
            return _Reveal(
              slot: (p.demo ? 4 : 3) + j,
              pageKey: index,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
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
                              fontSize: 14.5,
                              height: 1.25,
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
