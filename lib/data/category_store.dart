import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import 'catalog.dart';
import 'restaurant_database.dart';

/// The user's OWN category list. Keys are canonical (shared with everyone
/// via [Catalog]); labels are this user's personal display names — rename
/// "Pizza" to "Pizzaaaa 🍕" all you like, the backend category stays
/// `pizza` and keeps syncing with everyone else's.
class CategoryStore {
  static const _key = 'categories_v1';
  static const _migratedKey = 'categories_canonical_v1';

  static final ValueNotifier<List<AppCategory>> all =
      ValueNotifier<List<AppCategory>>(List.of(Catalog.starters));

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      all.value = List.of(Catalog.starters);
      await prefs.setBool(_migratedKey, true); // fresh installs are canonical
      return;
    }
    final list = (jsonDecode(raw) as List)
        .map((e) => AppCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    all.value = list.isEmpty ? List.of(Catalog.starters) : list;
    await _migrateToCanonicalKeys(prefs);
  }

  /// One-time: convert legacy keys ('kosherDairy', 'custom_170…') to
  /// canonical ones derived from the label, rewriting saved restaurants'
  /// tags to match so nothing gets orphaned.
  static Future<void> _migrateToCanonicalKeys(SharedPreferences prefs) async {
    if (prefs.getBool(_migratedKey) ?? false) return;
    final remap = <String, String>{};
    final seen = <String>{};
    final migrated = <AppCategory>[];
    for (final c in all.value) {
      final canonical = Catalog.keyFor(c.label);
      final key = canonical.length >= 2 ? canonical : c.key;
      if (key != c.key) remap[c.key] = key;
      if (seen.add(key)) {
        migrated.add(
            AppCategory(key: key, label: c.label, iconIndex: c.iconIndex));
      }
    }
    all.value = migrated;
    await _save();
    if (remap.isNotEmpty) {
      final db = RestaurantDatabase.instance;
      for (final r in await db.getAll()) {
        final newKeys =
            [for (final k in r.categoryKeys) remap[k] ?? k];
        if (!listEquals(newKeys, r.categoryKeys)) {
          await db.upsert(r.copyWith(categoryKeys: newKeys));
        }
      }
    }
    await prefs.setBool(_migratedKey, true);
  }

  /// Set by the cloud layer to mirror category changes to Firestore.
  static void Function()? onChanged;

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((c) => c.toJson()).toList()));
    onChanged?.call();
  }

  /// Replace the whole set — used by first-time setup where the user picks
  /// which starter categories they actually want.
  static Future<void> setAll(List<AppCategory> cats) async {
    all.value = List.of(cats);
    await _save();
  }

  static Future<AppCategory> add(String label, {int iconIndex = 0}) async {
    final clean = label.trim();
    // Canonical key: identical for everyone who has this category, so it
    // syncs across users automatically.
    final canonical = Catalog.keyFor(clean);
    final key = canonical.length >= 2
        ? canonical
        : 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final existing = byKey(key);
    if (existing != null) return existing;
    final cat = AppCategory(key: key, label: clean, iconIndex: iconIndex);
    all.value = [...all.value, cat];
    await _save();
    return cat;
  }

  /// Change how a category LOOKS for this user (label + icon). The key —
  /// the shared backend identity — never changes.
  static Future<void> relabel(String key, String label, int iconIndex) async {
    final clean = label.trim();
    if (clean.isEmpty) return;
    all.value = [
      for (final c in all.value)
        c.key == key
            ? AppCategory(key: key, label: clean, iconIndex: iconIndex)
            : c
    ];
    await _save();
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
