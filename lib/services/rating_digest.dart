import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One of my shared ratings waiting to go out in a digest email.
class DigestEntry {
  final String visitId;
  final String name;
  final double score;
  final int ms;

  const DigestEntry(this.visitId, this.name, this.score, this.ms);

  Map<String, dynamic> toJson() =>
      {'id': visitId, 'name': name, 'score': score, 'ms': ms};

  factory DigestEntry.fromJson(Map<String, dynamic> j) => DigestEntry(
        j['id'] as String,
        j['name'] as String? ?? 'a restaurant',
        (j['score'] as num?)?.toDouble() ?? 0,
        (j['ms'] as num?)?.toInt() ?? 0,
      );
}

/// Outbox for rating digest emails. Ratings I share queue up here; once a
/// friend's digest period (day/week) has fully passed, everything queued in
/// that period goes out as ONE email to them — no blasting per rating.
/// Sending happens next time this app is open after the period ends (there
/// is no server to fire at midnight).
class RatingDigestStore {
  static const _outboxKey = 'rating_digest_outbox_v1';
  static const _flushedKey = 'rating_digest_flushed_v1';

  static List<DigestEntry>? _cache;
  static Map<String, int>? _flushed;

  static Future<List<DigestEntry>> _entries() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_outboxKey);
    _cache = raw == null || raw.isEmpty
        ? <DigestEntry>[]
        : [
            for (final m in jsonDecode(raw) as List)
              DigestEntry.fromJson((m as Map).cast<String, dynamic>())
          ];
    return _cache!;
  }

  static Future<Map<String, int>> _lastFlushes() async {
    if (_flushed != null) return _flushed!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_flushedKey);
    _flushed = raw == null || raw.isEmpty
        ? <String, int>{}
        : (jsonDecode(raw) as Map)
            .map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    return _flushed!;
  }

  static Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_outboxKey,
        jsonEncode([for (final e in _cache ?? <DigestEntry>[]) e.toJson()]));
    await prefs.setString(_flushedKey, jsonEncode(_flushed ?? {}));
  }

  /// Queue (or refresh) a shared rating. Deduped by visit id, so editing a
  /// visit updates its digest line instead of duplicating it.
  static Future<void> record({
    required String visitId,
    required String restaurantName,
    required double score,
  }) async {
    final entries = await _entries();
    final i = entries.indexWhere((e) => e.visitId == visitId);
    if (i >= 0) {
      entries[i] =
          DigestEntry(visitId, restaurantName, score, entries[i].ms);
    } else {
      entries.add(DigestEntry(visitId, restaurantName, score,
          DateTime.now().millisecondsSinceEpoch));
    }
    await _save();
  }

  /// Entries for [friendUid]'s next digest: newer than their last one and
  /// from a period that has fully ended ([beforeMs]).
  static Future<List<DigestEntry>> pendingFor(
      String friendUid, int beforeMs) async {
    final entries = await _entries();
    final last = (await _lastFlushes())[friendUid] ?? 0;
    return [
      for (final e in entries)
        if (e.ms > last && e.ms < beforeMs) e
    ];
  }

  static Future<void> markFlushed(String friendUid) async {
    await _entries();
    final flushes = await _lastFlushes();
    flushes[friendUid] = DateTime.now().millisecondsSinceEpoch;
    // Prune anything old enough that every frequency has covered it.
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 9))
        .millisecondsSinceEpoch;
    _cache!.removeWhere((e) => e.ms < cutoff);
    await _save();
  }
}
