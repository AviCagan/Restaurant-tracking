import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'app_prefs.dart';

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

  /// Set by the cloud layer to mirror profile edits to Firestore.
  static Future<void> Function(UserProfile profile)? onProfileChanged;

  static Future<void> updateProfile(UserProfile profile) async {
    user.value = profile;
    await _save();
    await onProfileChanged?.call(profile);
  }

  static Future<void> signOut() async {
    user.value = null;
    await _save();
    // Return to the welcome screen rather than a signed-out shell.
    await AppPrefs.setLocalMode(false);
  }
}
