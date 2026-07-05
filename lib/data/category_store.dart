import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';

/// Persisted, user-editable list of categories. Seeded with [defaultCategories]
/// on first run; the user can add and remove their own.
class CategoryStore {
  static const _key = 'categories_v1';

  static final ValueNotifier<List<AppCategory>> all =
      ValueNotifier<List<AppCategory>>(List.of(defaultCategories));

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      all.value = List.of(defaultCategories);
      return;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => AppCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    all.value = list.isEmpty ? List.of(defaultCategories) : list;
  }

  /// Set by the cloud layer to mirror category changes to Firestore.
  static void Function()? onChanged;

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((c) => c.toJson()).toList()));
    onChanged?.call();
  }

  static Future<AppCategory> add(String label, {int iconIndex = 0}) async {
    final clean = label.trim();
    final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final cat = AppCategory(key: key, label: clean, iconIndex: iconIndex);
    all.value = [...all.value, cat];
    await _save();
    return cat;
  }

  static Future<void> remove(String key) async {
    all.value = all.value.where((c) => c.key != key).toList();
    await _save();
  }

  /// Returns an existing category whose label matches (case-insensitive), or
  /// creates one. Used so a chain only ever gets a single shared category.
  static Future<AppCategory> ensure(String label, {int iconIndex = 0}) async {
    final clean = label.trim();
    for (final c in all.value) {
      if (c.label.toLowerCase() == clean.toLowerCase()) return c;
    }
    return add(clean, iconIndex: iconIndex);
  }

  static AppCategory? byKey(String key) {
    for (final c in all.value) {
      if (c.key == key) return c;
    }
    return null;
  }

  static List<AppCategory> fromKeys(List<String> keys) =>
      keys.map(byKey).whereType<AppCategory>().toList();
}
