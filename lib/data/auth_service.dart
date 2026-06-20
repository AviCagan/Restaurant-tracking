import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/user_profile.dart';

/// Local mock auth for the Phase 2 preview. Phase 2 proper will replace this
/// with Firebase Auth (Google sign-in) while keeping the same surface.
class AuthService {
  static const _key = 'user_profile_v1';
  static final ValueNotifier<UserProfile?> user =
      ValueNotifier<UserProfile?>(null);

  static bool get isSignedIn => user.value != null;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      user.value =
          UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    if (user.value == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(user.value!.toJson()));
    }
  }

  /// Demo sign-in (no real provider yet). Creates a local profile.
  static Future<void> signInDemo() async {
    user.value = UserProfile(
      id: const Uuid().v4(),
      name: 'You',
      username: 'you',
    );
    await _save();
  }

  static Future<void> updateProfile(UserProfile profile) async {
    user.value = profile;
    await _save();
  }

  static Future<void> signOut() async {
    user.value = null;
    await _save();
  }
}
