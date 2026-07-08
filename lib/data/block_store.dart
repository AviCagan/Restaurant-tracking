import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Usernames the user has blocked. Blocked people are dropped as friends,
/// their incoming requests are auto-declined, and their ratings/pins are
/// hidden from the feed and map.
class BlockStore {
  static const _key = 'blocked_users_v1';

  static final ValueNotifier<Set<String>> blocked =
      ValueNotifier<Set<String>>({});

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    blocked.value =
        (jsonDecode(raw) as List).map((e) => e.toString()).toSet();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(blocked.value.toList()));
  }

  static bool isBlocked(String username) =>
      blocked.value.contains(username.trim().toLowerCase());

  static Future<void> block(String username) async {
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty) return;
    blocked.value = {...blocked.value, clean};
    await _save();
  }

  static Future<void> unblock(String username) async {
    final clean = username.trim().toLowerCase();
    blocked.value = blocked.value.where((u) => u != clean).toSet();
    await _save();
  }
}
