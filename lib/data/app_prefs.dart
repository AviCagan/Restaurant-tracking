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

  static const _localModeKey = 'local_mode';

  /// True when the user chose "use offline" on the welcome screen — the app
  /// works fully, social features just show a sign-in prompt.
  static final ValueNotifier<bool> localMode = ValueNotifier<bool>(false);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    defaultVisibility.value = p.getString(_visKey) ?? 'friends';
    categoriesViewable.value = p.getBool(_catViewKey) ?? true;
    localMode.value = p.getBool(_localModeKey) ?? false;
    hapticStrength.value = p.getInt(_hapticsKey) ?? 3;
    tourSeen.value = p.getBool(_tourKey) ?? false;
  }

  static Future<void> setLocalMode(bool b) async {
    localMode.value = b;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_localModeKey, b);
  }

  static const _hapticsKey = 'haptic_strength';
  static const _tourKey = 'tour_seen';

  /// 0 = off, 1 = light, 2 = medium, 3 = strong.
  static final ValueNotifier<int> hapticStrength = ValueNotifier<int>(3);

  /// Whether the intro tour has been shown.
  static final ValueNotifier<bool> tourSeen = ValueNotifier<bool>(false);

  static Future<void> setHapticStrength(int v) async {
    hapticStrength.value = v.clamp(0, 3);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_hapticsKey, hapticStrength.value);
  }

  static Future<void> setTourSeen(bool b) async {
    tourSeen.value = b;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_tourKey, b);
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
