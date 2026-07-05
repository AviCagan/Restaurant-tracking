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
    notifArrival.value = p.getBool(_notifArrivalKey) ?? true;
    notifFriends.value = p.getBool(_notifFriendsKey) ?? true;
    notifFriendsFilter.value = p.getString(_notifFilterKey) ?? '';
    wrappedLastShown.value = p.getString(_wrappedKey) ?? '';
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

  // ---- Notifications ----
  static const _notifArrivalKey = 'notif_arrival';
  static const _notifFriendsKey = 'notif_friends';
  static const _notifFilterKey = 'notif_friends_filter';
  static const _wrappedKey = 'wrapped_last_shown';

  /// Nudge to rate when the phone notices you're at a tracked restaurant.
  static final ValueNotifier<bool> notifArrival = ValueNotifier<bool>(true);

  /// Notify when friends share new ratings.
  static final ValueNotifier<bool> notifFriends = ValueNotifier<bool>(true);

  /// JSON: {"mode":"all"|"groups"|"friends","ids":[...]} — empty = everyone.
  static final ValueNotifier<String> notifFriendsFilter =
      ValueNotifier<String>('');

  /// 'yyyy-MM' of the last month whose Wrapped was shown.
  static final ValueNotifier<String> wrappedLastShown =
      ValueNotifier<String>('');

  static Future<void> setNotifArrival(bool b) async {
    notifArrival.value = b;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notifArrivalKey, b);
  }

  static Future<void> setNotifFriends(bool b) async {
    notifFriends.value = b;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_notifFriendsKey, b);
  }

  static Future<void> setNotifFriendsFilter(String json) async {
    notifFriendsFilter.value = json;
    final p = await SharedPreferences.getInstance();
    await p.setString(_notifFilterKey, json);
  }

  static Future<void> setWrappedLastShown(String yyyyMm) async {
    wrappedLastShown.value = yyyyMm;
    final p = await SharedPreferences.getInstance();
    await p.setString(_wrappedKey, yyyyMm);
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
