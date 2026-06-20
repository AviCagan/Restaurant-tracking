import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/models/restaurant.dart';
import 'package:restaurant_tracker/models/category.dart';

void main() {
  test('Restaurant survives a toMap/fromMap round-trip', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final original = Restaurant(
      id: 'abc-123',
      name: 'Green Bowl',
      address: '1 Market St',
      placeId: 'place_xyz',
      lat: 40.5,
      lng: -74.1,
      photoUrl: 'https://example.com/p.jpg',
      foodRating: 9,
      atmosphereRating: 7,
      price: 80,
      categoryKeys: [FoodCategory.vegan.key, FoodCategory.healthy.key],
      mediaPaths: ['/a/1.jpg', '/a/2.jpg'],
      notes: 'Loved the salad',
      createdAt: now,
      updatedAt: now,
      visibility: 'private',
    );

    final restored = Restaurant.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.address, original.address);
    expect(restored.lat, original.lat);
    expect(restored.lng, original.lng);
    expect(restored.foodRating, 9);
    expect(restored.atmosphereRating, 7);
    expect(restored.overallRating, 8.0);
    expect(restored.price, 80);
    expect(restored.categoryKeys, original.categoryKeys);
    expect(restored.mediaPaths, original.mediaPaths);
    expect(restored.notes, 'Loved the salad');
    expect(restored.createdAt, now);
  });

  test('Empty lists and nulls round-trip safely', () {
    final now = DateTime.now();
    final r = Restaurant(
      id: 'x',
      name: 'Plain',
      address: '',
      foodRating: 5,
      atmosphereRating: 5,
      price: 0,
      createdAt: now,
      updatedAt: now,
    );
    final restored = Restaurant.fromMap(r.toMap());
    expect(restored.categoryKeys, isEmpty);
    expect(restored.mediaPaths, isEmpty);
    expect(restored.placeId, isNull);
    expect(restored.coverImage, isNull);
  });
}
