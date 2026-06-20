import 'item.dart';

/// One visit to a restaurant. A restaurant accumulates many of these, and
/// the restaurant's headline ratings are averaged across all its visits.
class Visit {
  final String id;
  final DateTime date;
  final int foodRating; // 1..10
  final int atmosphereRating; // 1..10
  final int price; // dollars (custom, not capped)
  final String notes;
  final List<Item> items;
  final List<String> photoPaths;

  const Visit({
    required this.id,
    required this.date,
    required this.foodRating,
    required this.atmosphereRating,
    required this.price,
    this.notes = '',
    this.items = const [],
    this.photoPaths = const [],
  });

  double get overall => (foodRating + atmosphereRating) / 2.0;

  Visit copyWith({
    DateTime? date,
    int? foodRating,
    int? atmosphereRating,
    int? price,
    String? notes,
    List<Item>? items,
    List<String>? photoPaths,
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
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        id: j['id'] as String,
        date: DateTime.fromMillisecondsSinceEpoch(
            (j['date'] as num).toInt()),
        foodRating: (j['foodRating'] as num?)?.toInt() ?? 5,
        atmosphereRating: (j['atmosphereRating'] as num?)?.toInt() ?? 5,
        price: (j['price'] as num?)?.toInt() ?? 0,
        notes: j['notes'] as String? ?? '',
        items: (j['items'] as List? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        photoPaths: (j['photoPaths'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}
