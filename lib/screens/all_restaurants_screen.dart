import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/restaurant_card.dart';
import 'restaurant_detail_screen.dart';

/// Lists all of a person's restaurants (tap to open the detail).
class AllRestaurantsScreen extends StatelessWidget {
  const AllRestaurantsScreen({
    super.key,
    required this.title,
    required this.restaurants,
  });

  final String title;
  final List<Restaurant> restaurants;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: GradientAppBar(title: title),
      body: restaurants.isEmpty
          ? Center(
              child: Text('No restaurants yet.',
                  style: TextStyle(color: colors.subtle)),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              itemCount: restaurants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final r = restaurants[i];
                return RestaurantCard(
                  restaurant: r,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RestaurantDetailScreen(restaurant: r)),
                  ),
                );
              },
            ),
    );
  }
}
