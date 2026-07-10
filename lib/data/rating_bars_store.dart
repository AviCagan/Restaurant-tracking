import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// One rating bar shown in the visit form.
class BarDef {
  final String id; // 'food' / 'atmosphere' are built-in
  final String emoji;
  final String title;
  final String subtitle;
  final bool builtin;

  const BarDef({
    required this.id,
    required this.emoji,
    required this.title,
    this.subtitle = '',
    this.builtin = false,
  });

  BarDef copyWith({String? emoji, String? title, String? subtitle}) => BarDef(
        id: id,
        emoji: emoji ?? this.emoji,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'emoji': emoji,
        'title': title,
        'subtitle': subtitle,
        'builtin': builtin,
      };

  factory BarDef.fromJson(Map<String, dynamic> j) => BarDef(
        id: j['id'] as String,
        emoji: j['emoji'] as String? ?? '⭐',
        title: j['title'] as String? ?? 'Rating',
        subtitle: j['subtitle'] as String? ?? '',
        builtin: j['builtin'] as bool? ?? false,
      );
}

const _defaults = [
  BarDef(
      id: 'food',
      emoji: '🍔',
      title: 'Food',
      subtitle: 'How good was the food? (1–10)',
      builtin: true),
  BarDef(
      id: 'atmosphere',
      emoji: '✨',
      title: 'Atmosphere',
      subtitle: 'Service, vibe, seating…',
      builtin: true),
];

/// User-customizable rating bars (edited in Settings → Customize).
class RatingBarsStore {
  static const _key = 'rating_bars_v1';

  static final ValueNotifier<List<BarDef>> all =
      ValueNotifier<List<BarDef>>(List.of(_defaults));

  /// Back to just the built-in Food + Atmosphere bars (full reset).
  static void resetToDefaults() {
    all.value = List.of(_defaults);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => BarDef.fromJson(e as Map<String, dynamic>))
        .toList();
    // Built-ins must always exist.
    if (!list.any((b) => b.id == 'food')) list.insert(0, _defaults[0]);
    if (!list.any((b) => b.id == 'atmosphere')) list.insert(1, _defaults[1]);
    all.value = list;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((b) => b.toJson()).toList()));
  }

  static BarDef? byId(String id) {
    for (final b in all.value) {
      if (b.id == id) return b;
    }
    return null;
  }

  static List<BarDef> get customBars =>
      all.value.where((b) => !b.builtin).toList();

  static Future<void> add(String emoji, String title, String subtitle) async {
    all.value = [
      ...all.value,
      BarDef(
          id: const Uuid().v4(),
          emoji: emoji,
          title: title.trim(),
          subtitle: subtitle.trim()),
    ];
    await _save();
  }

  static Future<void> update(BarDef b) async {
    all.value = [for (final x in all.value) x.id == b.id ? b : x];
    await _save();
  }

  static Future<void> delete(String id) async {
    final b = byId(id);
    if (b == null || b.builtin) return;
    all.value = all.value.where((x) => x.id != id).toList();
    await _save();
  }
}
