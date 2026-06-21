import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maps friends' category keys onto your own categories so differently-named
/// categories are comparable (e.g. a friend's "Dairy 🧀" -> your "Kosher · Dairy").
/// Used when filtering the food map.
class CategoryMapping {
  static const _key = 'category_mapping_v1';

  static const _hiddenKey = 'category_hidden_v1';

  /// externalKey -> localKey
  static final ValueNotifier<Map<String, String>> map =
      ValueNotifier<Map<String, String>>({});

  /// Friend category keys the user has dismissed (won't be suggested again).
  static final ValueNotifier<Set<String>> hidden =
      ValueNotifier<Set<String>>({});

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      map.value = (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    final rawHidden = prefs.getString(_hiddenKey);
    if (rawHidden != null && rawHidden.isNotEmpty) {
      hidden.value =
          (jsonDecode(rawHidden) as List).map((e) => e.toString()).toSet();
    }
  }

  static bool isHidden(String key) => hidden.value.contains(key);

  static Future<void> hide(String key) async {
    hidden.value = {...hidden.value, key};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hiddenKey, jsonEncode(hidden.value.toList()));
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map.value));
  }

  /// Resolve an external (friend) category key to a local one, if linked.
  static String resolve(String externalKey) =>
      map.value[externalKey] ?? externalKey;

  static Future<void> link(String externalKey, String localKey) async {
    map.value = {...map.value, externalKey: localKey};
    await _save();
  }

  static Future<void> unlink(String externalKey) async {
    final next = {...map.value}..remove(externalKey);
    map.value = next;
    await _save();
  }

  /// Resolve a whole list of external keys to local keys.
  static List<String> resolveAll(Iterable<String> keys) =>
      keys.map(resolve).toList();
}
