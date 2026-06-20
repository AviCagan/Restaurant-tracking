/// A single thing ordered on a visit ("what did you get").
/// Price and rating are both optional.
class Item {
  final String name;
  final int? price; // dollars, optional
  final int? rating; // 1..10, optional

  const Item({required this.name, this.price, this.rating});

  Item copyWith({String? name, int? price, int? rating, bool clearPrice = false, bool clearRating = false}) =>
      Item(
        name: name ?? this.name,
        price: clearPrice ? null : (price ?? this.price),
        rating: clearRating ? null : (rating ?? this.rating),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'rating': rating,
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        name: j['name'] as String? ?? '',
        price: (j['price'] as num?)?.toInt(),
        rating: (j['rating'] as num?)?.toInt(),
      );
}
