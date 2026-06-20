import 'package:flutter/material.dart';

/// The fixed set of restaurant categories the user can tag and filter by.
enum FoodCategory {
  kosherDairy('Kosher · Dairy', Icons.icecream_outlined),
  kosherMeat('Kosher · Meat', Icons.kebab_dining_outlined),
  fastFood('Fast Food', Icons.fastfood_outlined),
  fancy('Fancy', Icons.local_bar_outlined),
  mexican('Mexican', Icons.local_fire_department_outlined),
  chinese('Chinese', Icons.ramen_dining_outlined),
  vegan('Vegan', Icons.eco_outlined),
  healthy('Healthy', Icons.spa_outlined);

  const FoodCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Stable key persisted to storage (so renaming labels won't break data).
  String get key => name;

  static FoodCategory? fromKey(String key) {
    for (final c in FoodCategory.values) {
      if (c.key == key) return c;
    }
    return null;
  }

  static List<FoodCategory> fromKeys(List<String> keys) =>
      keys.map(fromKey).whereType<FoodCategory>().toList();
}
