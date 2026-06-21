import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'social_screen.dart';

/// Root scaffold with a custom floating pill navigation bar.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    SocialScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (Icons.restaurant_rounded, 'Eats'),
    (Icons.group_rounded, 'Friends'),
    (Icons.person_rounded, 'You'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.ink.withValues(alpha: 0.13),
                width: 1.5),
            boxShadow: AppTheme.shadow(context),
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final selected = i == _index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _index = i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
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
                        Icon(_items[i].$1,
                            size: 22,
                            color: selected ? Colors.white : colors.subtle),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(_items[i].$2,
                              style: AppTheme.heading(15, color: Colors.white)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
