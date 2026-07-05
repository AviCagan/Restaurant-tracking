import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/category_store.dart';
import '../data/restaurant_database.dart';
import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// Your monthly food recap — auto-shown on the 1st of each month (for the
/// previous month) and previewable from Settings.
class WrappedScreen extends StatefulWidget {
  const WrappedScreen({super.key, required this.month});

  /// The month to recap (any DateTime inside it).
  final DateTime month;

  static Future<void> show(BuildContext context, DateTime month) {
    return Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => WrappedScreen(month: month),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _Stats {
  int visitCount = 0;
  int placesVisited = 0;
  int newPlaces = 0;
  Restaurant? topRated;
  double topRatedScore = 0;
  Restaurant? mostVisited;
  int mostVisitedCount = 0;
  double avgPrice = 0;
  String? topCategory;
  int takeoutCount = 0;
}

class _WrappedScreenState extends State<WrappedScreen> {
  final _controller = PageController();
  int _page = 0;
  _Stats? _stats;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _compute() async {
    final start = DateTime(widget.month.year, widget.month.month, 1);
    final end = DateTime(widget.month.year, widget.month.month + 1, 1);
    final all = await RestaurantDatabase.instance.getAll();
    final s = _Stats();
    final catCounts = <String, int>{};
    var priceSum = 0;

    for (final r in all) {
      final monthVisits = r.visits
          .where((v) =>
              !v.date.isBefore(start) && v.date.isBefore(end))
          .toList();
      if (r.createdAt.isAfter(start) && r.createdAt.isBefore(end)) {
        s.newPlaces++;
      }
      if (monthVisits.isEmpty) continue;
      s.placesVisited++;
      s.visitCount += monthVisits.length;
      s.takeoutCount += monthVisits.where((v) => v.isTakeout).length;
      for (final v in monthVisits) {
        priceSum += v.price;
      }
      final score = monthVisits.fold<double>(0, (a, v) => a + v.overall) /
          monthVisits.length;
      if (score > s.topRatedScore) {
        s.topRatedScore = score;
        s.topRated = r;
      }
      if (monthVisits.length > s.mostVisitedCount) {
        s.mostVisitedCount = monthVisits.length;
        s.mostVisited = r;
      }
      for (final key in r.categoryKeys) {
        catCounts[key] = (catCounts[key] ?? 0) + monthVisits.length;
      }
    }
    if (s.visitCount > 0) s.avgPrice = priceSum / s.visitCount;
    if (catCounts.isNotEmpty) {
      final top = catCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
      s.topCategory = CategoryStore.byKey(top.key)?.label;
    }
    if (mounted) setState(() => _stats = s);
  }

  List<Widget> _pages(_Stats s) {
    final monthName = DateFormat.yMMMM().format(widget.month);
    const g1 = LinearGradient(
        colors: [Color(0xFFFFA26C), Color(0xFFF07A4B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight);
    const g2 = LinearGradient(
        colors: [Color(0xFF8FBA96), Color(0xFF5B9668)],
        begin: Alignment.topLeft, end: Alignment.bottomRight);
    const g3 = LinearGradient(
        colors: [Color(0xFFFFC24B), Color(0xFFE89A1D)],
        begin: Alignment.topLeft, end: Alignment.bottomRight);

    if (s.visitCount == 0) {
      return [
        _WrapPage(
          gradient: g1,
          emoji: '🍽️',
          title: 'Your $monthName Wrapped',
          big: 'No visits logged',
          sub: 'Rate a few spots and next month\'s recap will be delicious.',
        ),
      ];
    }

    return [
      _WrapPage(
        gradient: g1,
        emoji: '✨',
        title: 'Your $monthName Wrapped',
        big: '${s.visitCount} visit${s.visitCount == 1 ? '' : 's'}',
        sub: 'across ${s.placesVisited} '
            'place${s.placesVisited == 1 ? '' : 's'}'
            '${s.newPlaces > 0 ? ' — ${s.newPlaces} brand new!' : ''}',
      ),
      if (s.topRated != null)
        _WrapPage(
          gradient: g2,
          emoji: '🏆',
          title: 'Best bite of the month',
          big: s.topRated!.name,
          sub: 'You gave it ${s.topRatedScore.toStringAsFixed(1)}/10. '
              'Chef\'s kiss.',
        ),
      if (s.mostVisited != null && s.mostVisitedCount > 1)
        _WrapPage(
          gradient: g3,
          emoji: '🔁',
          title: 'Your go-to spot',
          big: s.mostVisited!.name,
          sub: '${s.mostVisitedCount} visits — at this point they '
              'should know your order.',
        ),
      _WrapPage(
        gradient: g1,
        emoji: '💸',
        title: 'Taste level',
        big: PriceTier.signs(s.avgPrice.round().clamp(1, 4)),
        sub: s.takeoutCount > 0
            ? '${s.takeoutCount} takeout run${s.takeoutCount == 1 ? '' : 's'} '
                'this month. No shame. 🥡'
            : 'All dine-in this month. Fancy!',
      ),
      _WrapPage(
        gradient: g2,
        emoji: '❤️',
        title: s.topCategory != null
            ? 'Your flavor of the month'
            : 'See you next month',
        big: s.topCategory ?? 'Keep eating good',
        sub: 'That\'s a wrap on $monthName — go make next month tastier!',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = _pages(s);
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: pages,
          ),
          // Dots + close
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ...List.generate(pages.length, (i) {
                    final on = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 5),
                      width: on ? 20 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: on ? 0.95 : 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WrapPage extends StatelessWidget {
  const _WrapPage({
    required this.gradient,
    required this.emoji,
    required this.title,
    required this.big,
    required this.sub,
  });

  final Gradient gradient;
  final String emoji;
  final String title;
  final String big;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (context, t, child) =>
                Transform.scale(scale: t, child: child),
            child: Text(emoji, style: const TextStyle(fontSize: 80)),
          ),
          const SizedBox(height: 28),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(big,
              textAlign: TextAlign.center,
              style: AppTheme.heading(40,
                  color: Colors.white, weight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
