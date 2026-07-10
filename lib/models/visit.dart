import 'item.dart';
import 'price_tier.dart';

/// One visit to a restaurant. A restaurant accumulates many of these, and
/// the restaurant's headline ratings are averaged across all its visits.
class Visit {
  final String id;
  final DateTime date;
  final int foodRating; // 1..10
  final int atmosphereRating; // 1..10
  final int price; // price tier 1..4 ($ to $$$$)
  final String notes;
  final List<Item> items;
  final List<String> photoPaths;

  /// 'private' (only you), 'friends' (all friends), or 'group' (only the
  /// friends listed in [audience]).
  final String visibility;

  /// Usernames allowed to see this visit when [visibility] == 'group'
  /// (a snapshot of the group's members at rating time).
  final List<String> audience;

  /// Display name of the group chosen when [visibility] == 'group'.
  final String groupName;

  /// True when this was delivery/takeout — no atmosphere to rate.
  final bool isTakeout;

  /// Scores for user-defined custom rating bars (barId -> 1..10).
  final Map<String, int> extraRatings;

  const Visit({
    required this.id,
    required this.date,
    required this.foodRating,
    required this.atmosphereRating,
    required this.price,
    this.notes = '',
    this.items = const [],
    this.photoPaths = const [],
    this.visibility = 'friends',
    this.audience = const [],
    this.groupName = '',
    this.isTakeout = false,
    this.extraRatings = const {},
  });

  bool get isPrivate => visibility == 'private';

  /// Anyone besides me can see it (all friends, or a group of them).
  bool get isShared => visibility == 'friends' || visibility == 'group';

  /// Whether the friend with [username] is allowed to see this visit.
  bool visibleTo(String username) =>
      visibility == 'friends' ||
      (visibility == 'group' && audience.contains(username.toLowerCase()));

  /// A takeout visit's score is food only; dine-in averages food+atmosphere.
  double get overall =>
      isTakeout ? foodRating.toDouble() : (foodRating + atmosphereRating) / 2.0;

  Visit copyWith({
    DateTime? date,
    int? foodRating,
    int? atmosphereRating,
    int? price,
    String? notes,
    List<Item>? items,
    List<String>? photoPaths,
    String? visibility,
    List<String>? audience,
    String? groupName,
    bool? isTakeout,
    Map<String, int>? extraRatings,
  }) =>
      Visit(
        id: id,
        date: date ?? this.date,
        foodRating: foodRating ?? this.foodRating,
        atmosphereRating: atmosphereRating ?? this.atmosphereRating,
        price: price ?? this.price,
        notes: notes ?? this.notes,
        items: items ?? this.items,
        photoPaths: photoPaths ?? this.photoPaths,
        visibility: visibility ?? this.visibility,
        audience: audience ?? this.audience,
        groupName: groupName ?? this.groupName,
        isTakeout: isTakeout ?? this.isTakeout,
        extraRatings: extraRatings ?? this.extraRatings,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.millisecondsSinceEpoch,
        'foodRating': foodRating,
        'atmosphereRating': atmosphereRating,
        'price': price,
        'notes': notes,
        'items': items.map((e) => e.toJson()).toList(),
        'photoPaths': photoPaths,
        'visibility': visibility,
        if (audience.isNotEmpty) 'audience': audience,
        if (groupName.isNotEmpty) 'groupName': groupName,
        'takeout': isTakeout,
        'extras': extraRatings,
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(
            (j['date'] as num).toInt()),
        foodRating: (j['foodRating'] as num?)?.toInt() ?? 5,
        atmosphereRating: (j['atmosphereRating'] as num?)?.toInt() ?? 5,
        price: PriceTier.fromStored((j['price'] as num?)?.toInt() ?? 2),
        notes: j['notes'] as String? ?? '',
        items: (j['items'] as List? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        photoPaths: (j['photoPaths'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        visibility: j['visibility'] as String? ?? 'friends',
        audience: (j['audience'] as List? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList(),
        groupName: j['groupName'] as String? ?? '',
        isTakeout: j['takeout'] as bool? ?? false,
        extraRatings: (j['extras'] as Map? ?? {}).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
}
