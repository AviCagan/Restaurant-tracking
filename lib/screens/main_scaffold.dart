import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';

/// Root scaffold: a morphing animated header, a swipeable PageView body, and a
/// floating pill nav that also works as a slider. Settings live top-right and
/// are reachable from every page.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;
  final _pageController = PageController();

  static const _titles = ['My Eats', 'Friends', 'You'];
  static const _items = [
    (Icons.restaurant_rounded, 'Eats'),
    (Icons.group_rounded, 'Friends'),
    (Icons.person_rounded, 'You'),
  ];

  final _screens = const [HomeScreen(), SocialScreen(), ProfileScreen()];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    _pageController.animateToPage(i,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  void _openSettings() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  // Each page gets a different header shape so the bar morphs as you move.
  BorderRadius _shape(int i) {
    switch (i) {
      case 0:
        return const BorderRadius.vertical(bottom: Radius.circular(30));
      case 1:
        return const BorderRadius.only(
            bottomLeft: Radius.circular(10), bottomRight: Radius.circular(46));
      default:
        return const BorderRadius.only(
            bottomLeft: Radius.circular(46), bottomRight: Radius.circular(10));
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22, topInset + 14, 10, 18),
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: _shape(_index),
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0, 0.4), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(_titles[_index],
                        key: ValueKey(_index),
                        style: AppTheme.heading(30, color: Colors.white)),
                  ),
                ),
                IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Settings',
                ),
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
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
              // Drag across the bar to slide between pages.
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
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                            if (selected) ...[
                              const SizedBox(width: 8),
                              Text(items[i].$2,
                                  style:
                                      AppTheme.heading(15, color: Colors.white)),
                            ],
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
