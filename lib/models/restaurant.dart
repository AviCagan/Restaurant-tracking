import 'dart:convert';

/// A single rated restaurant.
///
/// Designed to be sharing-ready: [ownerId], [visibility] and [groupIds]
/// are unused in Phase 1 (local-only) but let Phase 2 (Firebase sync,
/// friends/groups/public) layer on without a data migration.
class Restaurant {
  final String id;
  final String name;
  final String address;

  // Google Places linkage (optional — null if entered manually).
  final String? placeId;
  final double? lat;
  final double? lng;

  /// Network URL of the auto-fetched Google photo.
  final String? photoUrl;

  /// Local path of a user-supplied custom cover photo (overrides [photoUrl]).
  final String? customPhotoPath;

  final int foodRating; // 1..10
  final int atmosphereRating; // 1..10
  final int price; // 1..500

  final List<String> categoryKeys;

  /// Local file paths of extra photos attached to the rating.
  final List<String> mediaPaths;

  final String notes;

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
    required this.foodRating,
    required this.atmosphereRating,
    required this.price,
    this.categoryKeys = const [],
    this.mediaPaths = const [],
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
    this.ownerId,
    this.visibility = 'private',
    this.groupIds = const [],
  });

  /// Overall score shown on the card (average of food + atmosphere, 0..10).
  double get overallRating => (foodRating + atmosphereRating) / 2.0;

  /// The image to show: custom cover wins, else the Google photo.
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
    int? foodRating,
    int? atmosphereRating,
    int? price,
    List<String>? categoryKeys,
    List<String>? mediaPaths,
    String? notes,
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
      foodRating: foodRating ?? this.foodRating,
      atmosphereRating: atmosphereRating ?? this.atmosphereRating,
      price: price ?? this.price,
      categoryKeys: categoryKeys ?? this.categoryKeys,
      mediaPaths: mediaPaths ?? this.mediaPaths,
      notes: notes ?? this.notes,
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
        'foodRating': foodRating,
        'atmosphereRating': atmosphereRating,
        'price': price,
        'categoryKeys': jsonEncode(categoryKeys),
        'mediaPaths': jsonEncode(mediaPaths),
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'ownerId': ownerId,
        'visibility': visibility,
        'groupIds': jsonEncode(groupIds),
      };

  factory Restaurant.fromMap(Map<String, dynamic> m) {
    List<String> decodeList(dynamic v) {
      if (v == null) return const [];
      if (v is String && v.isNotEmpty) {
        return (jsonDecode(v) as List).map((e) => e.toString()).toList();
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
      foodRating: (m['foodRating'] as num?)?.toInt() ?? 5,
      atmosphereRating: (m['atmosphereRating'] as num?)?.toInt() ?? 5,
      price: (m['price'] as num?)?.toInt() ?? 0,
      categoryKeys: decodeList(m['categoryKeys']),
      mediaPaths: decodeList(m['mediaPaths']),
      notes: m['notes'] as String? ?? '',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch((m['createdAt'] as num).toInt()),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((m['updatedAt'] as num).toInt()),
      ownerId: m['ownerId'] as String?,
      visibility: m['visibility'] as String? ?? 'private',
      groupIds: decodeList(m['groupIds']),
    );
  }
}
