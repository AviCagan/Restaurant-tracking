import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_prefs.dart';
import '../data/auth_service.dart';
import '../data/plan_store.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import 'tour_screen.dart';
import 'wrapped_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';
import '../services/haptics.dart';

/// Root scaffold: a clean gradient header (profile avatar top-left, settings
/// top-right), a swipeable PageView body, and a floating pill nav that doubles
/// as a slider with haptics. Only two tabs — profile opens from the header.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  final _pageController = PageController();

  Timer? _arrivalTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // First time in the app: show the quick tour.
      if (!AppPrefs.tourSeen.value) {
        TourScreen.show(context);
        return;
      }
      // On the 1st of the month: last month's Wrapped (once).
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      final tag = '${lastMonth.year}-${lastMonth.month}';
      if (now.day == 1 && AppPrefs.wrappedLastShown.value != tag) {
        await AppPrefs.setWrappedLastShown(tag);
        if (mounted) WrappedScreen.show(context, lastMonth);
      }
    });
    // Gentle arrival check while the app is open.
    NotificationService.checkArrival();
    _arrivalTimer = Timer.periodic(const Duration(minutes: 10),
        (_) => NotificationService.checkArrival());
  }

  static const _titles = ['My Eats', 'Food Map', 'Friends'];
  static const _items = [
    (Icons.restaurant_rounded, 'Eats'),
    (Icons.map_rounded, 'Map'),
    (Icons.group_rounded, 'Friends'),
  ];

  final _screens = const [HomeScreen(), MapScreen(), SocialScreen()];

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _index) return;
    Haptics.tick();
    setState(() => _index = i);
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _openSettings() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _openProfile() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const ProfileScreen()));

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: AppTheme.accentTick,
            builder: (context, _, child) => Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 20),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: child,
            ),
            child: Row(
              children: [
                _ProfileButton(onTap: _openProfile),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    switchInCurve: const Interval(0.4, 1, curve: Curves.easeOut),
                    switchOutCurve: const Interval(0.6, 1, curve: Curves.easeIn),
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previous, if (current != null) current],
                    ),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                        alignment: Alignment.centerLeft,
                        child: child,
                      ),
                    ),
                    child: Text(_titles[_index],
                        key: ValueKey(_index),
                        style: AppTheme.heading(28, color: Colors.white)),
                  ),
                ),
                _CircleButton(
                    icon: Icons.settings_outlined, onTap: _openSettings),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _index = i),
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PillNav(
        index: _index,
        items: _items,
        onSelect: _goTo,
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5),
                  width: 1.5),
            ),
            child: Center(
              child: user == null
                  ? const Icon(Icons.person_outline,
                      color: Colors.white, size: 22)
                  : Text(user.initials,
                      style: AppTheme.heading(16, color: Colors.white)),
            ),
          );
        },
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 21),
      ),
    );
  }
}

/// Red count bubble over the Friends tab icon: pending friend requests plus
/// plan invites waiting for you.
class _SocialBadge extends StatelessWidget {
  const _SocialBadge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Friend>>(
      valueListenable: SocialService.requests,
      builder: (context, requests, _) {
        return ValueListenableBuilder<List<PlanInvite>>(
          valueListenable: SocialService.invites,
          builder: (context, invites, _) {
            final count = requests.length + invites.length;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                child,
                if (count > 0)
                  Positioned(
                    right: -10,
                    top: -7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0484D),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            height: 1.2,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PillNav extends StatelessWidget {
  const _PillNav(
      {required this.index, required this.items, required this.onSelect});

  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(28, 0, 28, 14),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(26),
          border:
              Border.all(color: colors.ink.withValues(alpha: 0.13), width: 1.5),
          boxShadow: AppTheme.shadow(context),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final width = c.maxWidth;
            final n = items.length;
            return GestureDetector(
              onHorizontalDragUpdate: (d) {
                var i = (d.localPosition.dx / width * n).floor();
                if (i < 0) i = 0;
                if (i > n - 1) i = n - 1;
                onSelect(i);
              },
              child: SizedBox(
                height: 52,
                child: Stack(
                  children: [
                    // One gradient pill that glides between tabs.
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 340),
                      curve: Curves.easeOutBack,
                      alignment: Alignment(
                          n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
                      child: Container(
                        width: width / n,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppTheme.accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(n, (i) {
                        final selected = i == index;
                        Widget icon = AnimatedScale(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          scale: selected ? 1.18 : 1.0,
                          child: Icon(items[i].$1,
                              size: 24,
                              color: selected
                                  ? Colors.white
                                  : colors.subtle),
                        );
                        // Friend requests + plan invites badge on the
                        // Friends tab.
                        if (items[i].$2 == 'Friends') {
                          icon = _SocialBadge(child: icon);
                        }
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => onSelect(i),
                            behavior: HitTestBehavior.opaque,
                            child: Center(child: icon),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
