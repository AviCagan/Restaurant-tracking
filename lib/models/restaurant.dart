import 'dart:convert';

import 'visit.dart';

/// A restaurant the user tracks. Holds identity (name/address/place/photo/
/// categories) plus a list of [Visit]s. Headline ratings are averaged across
/// visits.
///
/// Sharing-ready: [ownerId], [visibility] and [groupIds] are unused in
/// Phase 1 but let Phase 2 (Firebase sync) layer on without a migration.
class Restaurant {
  final String id;
  final String name;
  final String address;

  final String? placeId;
  final double? lat;
  final double? lng;

  final String? photoUrl;
  final String? customPhotoPath;

  final List<String> categoryKeys;
  final List<Visit> visits;

  final DateTime createdAt;
  final DateTime updatedAt;

  // ---- Sharing fields (Phase 2) ----
  final String? ownerId;
  final String visibility; // 'private' | 'public'
  final List<String> groupIds;

  const Restaurant({
    required this.id,
    required this.name,
    required this.address,
    this.placeId,
    this.lat,
    this.lng,
    this.photoUrl,
    this.customPhotoPath,
    this.categoryKeys = const [],
    this.visits = const [],
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.visibility = 'private',
    this.groupIds = const [],
  });

  int get visitCount => visits.length;

  double _avg(int Function(Visit) f) {
    if (visits.isEmpty) return 0;
    final total = visits.fold<int>(0, (s, v) => s + f(v));
    return total / visits.length;
  }

  double get avgFood => _avg((v) => v.foodRating);
  double get avgAtmosphere => _avg((v) => v.atmosphereRating);
  double get avgPrice => _avg((v) => v.price);

  /// Overall = average of (food+atmosphere) across visits, 0..10.
  double get overallRating => (avgFood + avgAtmosphere) / 2.0;

  String? get coverImage =>
      (customPhotoPath != null && customPhotoPath!.isNotEmpty)
          ? customPhotoPath
          : photoUrl;

  bool get coverIsLocalFile =>
      customPhotoPath != null && customPhotoPath!.isNotEmpty;

  Restaurant copyWith({
    String? name,
    String? address,
    String? placeId,
    double? lat,
    double? lng,
    String? photoUrl,
    String? customPhotoPath,
    List<String>? categoryKeys,
    List<Visit>? visits,
    DateTime? updatedAt,
    String? ownerId,
    String? visibility,
    List<String>? groupIds,
  }) {
    return Restaurant(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photoUrl: photoUrl ?? this.photoUrl,
      customPhotoPath: customPhotoPath ?? this.customPhotoPath,
      categoryKeys: categoryKeys ?? this.categoryKeys,
      visits: visits ?? this.visits,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      ownerId: ownerId ?? this.ownerId,
      visibility: visibility ?? this.visibility,
      groupIds: groupIds ?? this.groupIds,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'placeId': placeId,
        'lat': lat,
        'lng': lng,
        'photoUrl': photoUrl,
        'customPhotoPath': customPhotoPath,
        'categoryKeys': jsonEncode(categoryKeys),
        'visits': jsonEncode(visits.map((v) => v.toJson()).toList()),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'ownerId': ownerId,
        'visibility': visibility,
        'groupIds': jsonEncode(groupIds),
      };

  factory Restaurant.fromMap(Map<String, dynamic> m) {
    List<String> decodeStrings(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return (jsonDecode(v) as List).map((e) => e.toString()).toList();
      }
      return const [];
    }

    List<Visit> decodeVisits(dynamic v) {
      if (v is String && v.isNotEmpty) {
        return (jsonDecode(v) as List)
            .map((e) => Visit.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return const [];
    }

    return Restaurant(
      id: m['id'] as String,
      name: m['name'] as String,
      address: m['address'] as String? ?? '',
      placeId: m['placeId'] as String?,
      lat: (m['lat'] as num?)?.toDouble(),
      lng: (m['lng'] as num?)?.toDouble(),
      photoUrl: m['photoUrl'] as String?,
      customPhotoPath: m['customPhotoPath'] as String?,
      categoryKeys: decodeStrings(m['categoryKeys']),
      visits: decodeVisits(m['visits']),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num).toInt()),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((m['updatedAt'] as num).toInt()),
      ownerId: m['ownerId'] as String?,
      visibility: m['visibility'] as String? ?? 'private',
      groupIds: decodeStrings(m['groupIds']),
    );
  }
}
