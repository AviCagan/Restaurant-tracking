import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// A planned visit to a restaurant, optionally with invited friends.
class Plan {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String address;
  final DateTime when;
  final List<String> friendUsernames;

  const Plan({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.address,
    required this.when,
    this.friendUsernames = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'address': address,
        'when': when.millisecondsSinceEpoch,
        'friendUsernames': friendUsernames,
      };

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        id: j['id'] as String,
        restaurantId: j['restaurantId'] as String? ?? '',
        restaurantName: j['restaurantName'] as String? ?? 'Restaurant',
        address: j['address'] as String? ?? '',
        when: DateTime.fromMillisecondsSinceEpoch((j['when'] as num).toInt()),
        friendUsernames: (j['friendUsernames'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// An invite a friend sent you.
class PlanInvite {
  final String id;
  final String fromName;
  final String restaurantName;
  final String address;
  final DateTime when;

  const PlanInvite({
    required this.id,
    required this.fromName,
    required this.restaurantName,
    required this.address,
    required this.when,
  });
}

/// Your own upcoming plans, stored locally.
class PlanStore {
  static const _key = 'plans_v1';

  static final ValueNotifier<List<Plan>> all = ValueNotifier<List<Plan>>([]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => Plan.fromJson(e as Map<String, dynamic>))
        .toList();
    // Keep plans until a day after they happen.
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    all.value = list.where((p) => p.when.isAfter(cutoff)).toList();
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(all.value.map((p) => p.toJson()).toList()));
  }

  static Future<Plan> create({
    required String restaurantId,
    required String restaurantName,
    required String address,
    required DateTime when,
    List<String> friendUsernames = const [],
  }) async {
    final plan = Plan(
      id: const Uuid().v4(),
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      address: address,
      when: when,
      friendUsernames: friendUsernames,
    );
    all.value = [...all.value, plan]
      ..sort((a, b) => a.when.compareTo(b.when));
    await _save();
    return plan;
  }

  static Future<void> delete(String id) async {
    all.value = all.value.where((p) => p.id != id).toList();
    await _save();
  }
}

/// Google Calendar "add event" link — opens the calendar app/site with the
/// plan pre-filled (no extra permissions needed).
Uri googleCalendarUrl(Plan p) {
  String fmt(DateTime d) {
    final u = d.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${u.year}${two(u.month)}${two(u.day)}T${two(u.hour)}${two(u.minute)}00Z';
  }

  final start = fmt(p.when);
  final end = fmt(p.when.add(const Duration(hours: 2)));
  return Uri.parse('https://calendar.google.com/calendar/render').replace(
    queryParameters: {
      'action': 'TEMPLATE',
      'text': '🍽️ ${p.restaurantName}',
      'dates': '$start/$end',
      'location': p.address,
      'details': 'Planned with YUMS — don\'t forget to rate it after!',
    },
  );
}
