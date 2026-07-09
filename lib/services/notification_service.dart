import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_prefs.dart';
import '../data/restaurant_database.dart';
import 'location_service.dart';

/// Local notifications: friend-rating alerts, plan-a-visit reminders, and
/// "looks like you're at a restaurant" nudges (while the app is running).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'yums_main',
    'YUMS',
    channelDescription: 'Reminders and friend activity',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (kIsWeb) return; // no local notifications in the browser
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {}
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      // Notifications unavailable — the app works fine without them.
    }
  }

  static Future<void> show(String title, String body, {int? id}) async {
    await init();
    if (!_ready) return;
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch & 0x7fffffff,
      title,
      body,
      const NotificationDetails(android: _channel),
    );
  }

  static Future<void> scheduleAt(
      DateTime when, String title, String body, int id) async {
    await init();
    if (!_ready) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      const NotificationDetails(android: _channel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// Cancel a scheduled notification (e.g. plan reminders when the plan is
  /// cancelled).
  static Future<void> cancel(int id) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  // ---- Arrival nudges (checked while the app is open) ----

  /// If you're within ~80m of a place you track and haven't been nudged for
  /// it today, send a "don't forget to rate" notification.
  static Future<void> checkArrival() async {
    if (!AppPrefs.notifArrival.value) return;
    final pos = await LocationService.lastKnown() ??
        await LocationService.current();
    if (pos == null) return;
    final all = await RestaurantDatabase.instance.getAll();
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    for (final r in all) {
      if (r.lat == null || r.lng == null) continue;
      final d = LocationService.distanceMeters(
          pos.latitude, pos.longitude, r.lat!, r.lng!);
      if (d > 80) continue;
      final key = 'arrival_${r.id}';
      if (prefs.getString(key) == today) continue; // already nudged today
      await prefs.setString(key, today);
      await show('Enjoy ${r.name}! 😋',
          'Looks like you\'re there — rate your visit afterwards!');
      break; // one nudge at a time
    }
  }

  // ---- Friend-rating notification filter ----

  /// Should a rating by [username] trigger a notification, per the user's
  /// customization (all / specific groups / specific friends)?
  static bool friendPassesFilter(
      String username, List<List<String>> groupMemberships) {
    if (!AppPrefs.notifFriends.value) return false;
    final raw = AppPrefs.notifFriendsFilter.value;
    if (raw.isEmpty) return true; // everyone
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final mode = decoded['mode'] as String? ?? 'all';
      if (mode == 'all') return true;
      final ids = (decoded['ids'] as List? ?? []).map((e) => e.toString());
      if (mode == 'friends') return ids.contains(username);
      if (mode == 'groups') {
        // groupMemberships: list of member-username lists for selected ids.
        for (final members in groupMemberships) {
          if (members.contains(username)) return true;
        }
      }
    } catch (_) {}
    return true;
  }
}
