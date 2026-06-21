import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/auth_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';

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

  static const _titles = ['My Eats', 'Food Map', 'Friends'];
  static const _subtitles = [
    'Your rated spots',
    'Where your friends have eaten',
    'What your circle is eating',
  ];
  static const _items = [
    (Icons.restaurant_rounded, 'Eats'),
    (Icons.map_rounded, 'Map'),
    (Icons.group_rounded, 'Friends'),
  ];

  final _screens = const [HomeScreen(), MapScreen(), SocialScreen()];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _index) return;
    HapticFeedback.selectionClick();
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
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, topInset + 12, 16, 20),
            decoration: const BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              children: [
                _ProfileButton(onTap: _openProfile),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeOut,
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: Column(
                      key: ValueKey(_index),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_titles[_index],
                            style: AppTheme.heading(26, color: Colors.white)),
                        Text(_subtitles[_index],
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
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
            return GestureDetector(
              onHorizontalDragUpdate: (d) {
                var i = (d.localPosition.dx / width * items.length).floor();
                if (i < 0) i = 0;
                if (i > items.length - 1) i = items.length - 1;
                onSelect(i);
              },
              child: Row(
                children: List.generate(items.length, (i) {
                  final selected = i == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelect(i),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: selected ? AppTheme.accentGradient : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(items[i].$1,
                                size: 22,
                                color:
                                    selected ? Colors.white : colors.subtle),
                            const SizedBox(width: 8),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              child: selected
                                  ? Text(items[i].$2,
                                      style: AppTheme.heading(15,
                                          color: Colors.white))
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          },
        ),
      ),
    );
  }
}
