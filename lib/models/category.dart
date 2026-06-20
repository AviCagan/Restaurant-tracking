import 'package:flutter/material.dart';

/// A fixed palette of const icons categories can use. We store an index into
/// this list (not a raw codepoint) so icon tree-shaking still works in release.
const List<IconData> categoryIcons = [
  Icons.restaurant, // 0 - generic / default
  Icons.icecream_outlined, // 1
  Icons.kebab_dining_outlined, // 2
  Icons.fastfood_outlined, // 3
  Icons.local_bar_outlined, // 4
  Icons.local_fire_department_outlined, // 5
  Icons.ramen_dining_outlined, // 6
  Icons.eco_outlined, // 7
  Icons.spa_outlined, // 8
  Icons.local_pizza_outlined, // 9
  Icons.coffee_outlined, // 10
  Icons.bakery_dining_outlined, // 11
  Icons.set_meal_outlined, // 12
  Icons.lunch_dining_outlined, // 13
  Icons.cake_outlined, // 14
  Icons.local_cafe_outlined, // 15
  Icons.label_outline, // 16
];

/// A category the user can tag restaurants with. Defaults are seeded but the
/// user can add and remove their own.
@immutable
class AppCategory {
  final String key;
  final String label;
  final int iconIndex;

  const AppCategory({
    required this.key,
    required this.label,
    this.iconIndex = 0,
  });

  IconData get icon =>
      categoryIcons[iconIndex.clamp(0, categoryIcons.length - 1)];

  Map<String, dynamic> toJson() =>
      {'key': key, 'label': label, 'iconIndex': iconIndex};

  factory AppCategory.fromJson(Map<String, dynamic> j) => AppCategory(
        key: j['key'] as String,
        label: j['label'] as String,
        iconIndex: (j['iconIndex'] as num?)?.toInt() ?? 0,
      );
}

/// The starting set of categories (keys kept stable so existing data matches).
const List<AppCategory> defaultCategories = [
  AppCategory(key: 'kosherDairy', label: 'Kosher · Dairy', iconIndex: 1),
  AppCategory(key: 'kosherMeat', label: 'Kosher · Meat', iconIndex: 2),
  AppCategory(key: 'fastFood', label: 'Fast Food', iconIndex: 3),
  AppCategory(key: 'fancy', label: 'Fancy', iconIndex: 4),
  AppCategory(key: 'mexican', label: 'Mexican', iconIndex: 5),
  AppCategory(key: 'chinese', label: 'Chinese', iconIndex: 6),
  AppCategory(key: 'vegan', label: 'Vegan', iconIndex: 7),
  AppCategory(key: 'healthy', label: 'Healthy', iconIndex: 8),
];
