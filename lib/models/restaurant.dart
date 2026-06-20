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

  /// Marked as a favorite (shown on your profile).
  final bool isFavorite;

  // ---- Chain support ----
  /// Whether this is one location of a multi-location chain.
  final bool isChain;

  /// The chain's name (also auto-added as a shared category), e.g. "Chipotle".
  final String? chainName;

  /// A short label clarifying *which* location this is (e.g. "Times Square"),
  /// so different locations of the same chain are easy to tell apart.
  final String? locationLabel;

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
    this.isFavorite = false,
    this.isChain = false,
    this.chainName,
    this.locationLabel,
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

  /// A short location descriptor for chains: the user's [locationLabel] if set,
  /// otherwise the first part of the address (e.g. the street).
  String? get locationDescriptor {
    if (locationLabel != null && locationLabel!.trim().isNotEmpty) {
      return locationLabel!.trim();
    }
    if (address.trim().isEmpty) return null;
    return address.split(',').first.trim();
  }

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
    bool? isFavorite,
    bool? isChain,
    String? chainName,
    String? locationLabel,
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
      isFavorite: isFavorite ?? this.isFavorite,
      isChain: isChain ?? this.isChain,
      chainName: chainName ?? this.chainName,
      locationLabel: locationLabel ?? this.locationLabel,
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
        'isFavorite': isFavorite ? 1 : 0,
        'isChain': isChain ? 1 : 0,
        'chainName': chainName,
        'locationLabel': locationLabel,
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
      isFavorite: (m['isFavorite'] as num?)?.toInt() == 1,
      isChain: (m['isChain'] as num?)?.toInt() == 1,
      chainName: m['chainName'] as String?,
      locationLabel: m['locationLabel'] as String?,
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
