import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences (privacy defaults), persisted locally.
class AppPrefs {
  static const _visKey = 'default_visibility';
  static const _catViewKey = 'categories_viewable';

  /// Default visibility applied to a new review: 'private' or 'friends'.
  static final ValueNotifier<String> defaultVisibility =
      ValueNotifier<String>('friends');

  /// Whether your categories are visible to friends.
  static final ValueNotifier<bool> categoriesViewable =
      ValueNotifier<bool>(true);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    defaultVisibility.value = p.getString(_visKey) ?? 'friends';
    categoriesViewable.value = p.getBool(_catViewKey) ?? true;
  }

  static Future<void> setVisibility(String v) async {
    defaultVisibility.value = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_visKey, v);
  }

  static Future<void> setCategoriesViewable(bool b) async {
    categoriesViewable.value = b;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_catViewKey, b);
  }
}
