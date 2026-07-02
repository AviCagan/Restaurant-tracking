import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A user-made group of restaurants ("Date nights", "Pizza tour", …).
class Folder {
  final String id;
  final String name;
  final String emoji;
  final List<String> restaurantIds;

  const Folder({
    required this.id,
    required this.name,
    this.emoji = '📁',
    this.restaurantIds = const [],
  });

  Folder copyWith({String? name, String? emoji, List<String>? restaurantIds}) =>
      Folder(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        restaurantIds: restaurantIds ?? this.restaurantIds,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'emoji': emoji, 'restaurantIds': restaurantIds};

  factory Folder.fromJson(Map<String, dynamic> j) => Folder(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Folder',
        emoji: j['emoji'] as String? ?? '📁',
        restaurantIds: (j['restaurantIds'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Persisted store of the user's folders.
class FolderStore {
  static const _key = 'folders_v1';

  static final ValueNotifier<List<Folder>> all =
      ValueNotifier<List<Folder>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    all.value = (jsonDecode(raw) as List)
        .map((e) => Folder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((f) => f.toJson()).toList()));
  }

  static Folder? byId(String id) {
    for (final f in all.value) {
      if (f.id == id) return f;
    }
    return null;
  }

  static Future<Folder> create(String name, {String emoji = '📁'}) async {
    final folder =
        Folder(id: const Uuid().v4(), name: name.trim(), emoji: emoji);
    all.value = [...all.value, folder];
    await _save();
    return folder;
  }

  static Future<void> rename(String id, String name, String emoji) async {
    all.value = [
      for (final f in all.value)
        f.id == id ? f.copyWith(name: name.trim(), emoji: emoji) : f
    ];
    await _save();
  }

  static Future<void> delete(String id) async {
    all.value = all.value.where((f) => f.id != id).toList();
    await _save();
  }

  /// Add/remove a restaurant from a folder.
  static Future<void> toggle(String folderId, String restaurantId) async {
    all.value = [
      for (final f in all.value)
        if (f.id == folderId)
          f.copyWith(
            restaurantIds: f.restaurantIds.contains(restaurantId)
                ? (List.of(f.restaurantIds)..remove(restaurantId))
                : [...f.restaurantIds, restaurantId],
          )
        else
          f
    ];
    await _save();
  }

  static bool contains(String folderId, String restaurantId) =>
      byId(folderId)?.restaurantIds.contains(restaurantId) ?? false;
}

/// Emoji choices offered when creating/renaming a folder.
const List<String> folderEmojis = [
  '📁', '❤️', '⭐', '🍕', '🍣', '🌮', '🍔', '☕', //
  '🍰', '🥗', '🍜', '🎉', '👨‍👩‍👧', '💑', '✈️', '🏝️',
];
