import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A named group of friends ("Family", "Work crew"…) used to filter the feed
/// and the food map to just those people. Groups are private to you.
class FriendGroup {
  final String id;
  final String name;
  final String emoji;

  /// Optional local photo shown instead of the emoji.
  final String photoPath;

  /// Member usernames.
  final List<String> usernames;

  const FriendGroup({
    required this.id,
    required this.name,
    this.emoji = '👥',
    this.photoPath = '',
    this.usernames = const [],
  });

  FriendGroup copyWith(
          {String? name,
          String? emoji,
          String? photoPath,
          List<String>? usernames}) =>
      FriendGroup(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        photoPath: photoPath ?? this.photoPath,
        usernames: usernames ?? this.usernames,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'photo': photoPath,
        'usernames': usernames,
      };

  factory FriendGroup.fromJson(Map<String, dynamic> j) => FriendGroup(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Group',
        emoji: j['emoji'] as String? ?? '👥',
        photoPath: j['photo'] as String? ?? '',
        usernames: (j['usernames'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class FriendGroupStore {
  static const _key = 'friend_groups_v1';

  static final ValueNotifier<List<FriendGroup>> all =
      ValueNotifier<List<FriendGroup>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    all.value = (jsonDecode(raw) as List)
        .map((e) => FriendGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((g) => g.toJson()).toList()));
  }

  static FriendGroup? byId(String id) {
    for (final g in all.value) {
      if (g.id == id) return g;
    }
    return null;
  }

  static Future<FriendGroup> create(String name,
      {String emoji = '👥',
      String photoPath = '',
      List<String> usernames = const []}) async {
    final g = FriendGroup(
        id: const Uuid().v4(),
        name: name.trim(),
        emoji: emoji,
        photoPath: photoPath,
        usernames: usernames);
    all.value = [...all.value, g];
    await _save();
    return g;
  }

  static Future<void> update(FriendGroup g) async {
    all.value = [for (final x in all.value) x.id == g.id ? g : x];
    await _save();
  }

  static Future<void> delete(String id) async {
    all.value = all.value.where((g) => g.id != id).toList();
    await _save();
  }
}
