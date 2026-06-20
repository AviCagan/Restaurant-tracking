import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'feed_screen.dart';
import 'friends_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Root scaffold with the bottom navigation between the main sections.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    FeedScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: colors.surface,
        indicatorColor: AppTheme.accent.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant, color: AppTheme.accent),
            label: 'Restaurants',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed, color: AppTheme.accent),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group, color: AppTheme.accent),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppTheme.accent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
