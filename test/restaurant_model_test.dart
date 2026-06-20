import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_tracker/models/restaurant.dart';
import 'package:restaurant_tracker/models/visit.dart';
import 'package:restaurant_tracker/models/item.dart';
import 'package:restaurant_tracker/models/price_tier.dart';

void main() {
  test('Restaurant with visits survives toMap/fromMap round-trip', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final original = Restaurant(
      id: 'abc-123',
      name: 'Green Bowl',
      address: '1 Market St',
      placeId: 'place_xyz',
      lat: 40.5,
      lng: -74.1,
      photoUrl: 'https://example.com/p.jpg',
      categoryKeys: const ['vegan', 'healthy'],
      createdAt: now,
      updatedAt: now,
      visits: [
        Visit(
          id: 'v1',
          date: now,
          foodRating: 9,
          atmosphereRating: 7,
          price: 3, // tier $$$
          notes: 'Loved the salad',
          items: const [
            Item(name: 'Kale Salad', price: 14, rating: 9),
            Item(name: 'Water'),
          ],
          photoPaths: const ['/a/1.jpg'],
        ),
      ],
    );

    final restored = Restaurant.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.name, original.name);
    expect(restored.categoryKeys, original.categoryKeys);
    expect(restored.visits.length, 1);
    final v = restored.visits.first;
    expect(v.foodRating, 9);
    expect(v.atmosphereRating, 7);
    expect(v.price, 3);
    expect(v.notes, 'Loved the salad');
    expect(v.items.length, 2);
    expect(v.items.first.name, 'Kale Salad');
    expect(v.items.first.price, 14);
    expect(v.items.first.rating, 9);
    expect(v.items[1].price, isNull);
    expect(v.items[1].rating, isNull);
    expect(v.photoPaths, ['/a/1.jpg']);
  });

  test('Averages are weighted across visits', () {
    final now = DateTime.now();
    Visit mk(int f, int a, int p) => Visit(
        id: '$f-$a-$p',
        date: now,
        foodRating: f,
        atmosphereRating: a,
        price: p);

    final r = Restaurant(
      id: 'x',
      name: 'Spot',
      address: '',
      createdAt: now,
      updatedAt: now,
      visits: [mk(10, 8, 4), mk(6, 6, 2)], // price tiers $$$$ and $$
    );

    expect(r.visitCount, 2);
    expect(r.avgFood, 8.0); // (10+6)/2
    expect(r.avgAtmosphere, 7.0); // (8+6)/2
    expect(r.avgPrice, 3.0); // ($$$$ + $$)/2
    expect(r.overallRating, 7.5); // (8+7)/2
  });

  test('PriceTier maps legacy dollar amounts onto tiers', () {
    expect(PriceTier.fromStored(3), 3); // already a tier
    expect(PriceTier.fromStored(15), 1); // < $20
    expect(PriceTier.fromStored(40), 2); // < $50
    expect(PriceTier.fromStored(90), 3); // < $100
    expect(PriceTier.fromStored(250), 4); // $100+
    expect(PriceTier.signs(2), '\$\$');
  });

  test('Chain fields round-trip and locationDescriptor falls back to address',
      () {
    final now = DateTime.now();
    final chain = Restaurant(
      id: 'c1',
      name: 'Chipotle',
      address: '123 Broadway, New York, NY',
      isChain: true,
      chainName: 'Chipotle',
      locationLabel: 'Times Square',
      createdAt: now,
      updatedAt: now,
    );
    final restored = Restaurant.fromMap(chain.toMap());
    expect(restored.isChain, true);
    expect(restored.chainName, 'Chipotle');
    expect(restored.locationLabel, 'Times Square');
    expect(restored.locationDescriptor, 'Times Square');

    // With no explicit label, descriptor falls back to first address part.
    final noLabel = Restaurant(
      id: 'c2',
      name: 'Chipotle',
      address: '123 Broadway, New York, NY',
      isChain: true,
      chainName: 'Chipotle',
      createdAt: now,
      updatedAt: now,
    );
    expect(noLabel.locationDescriptor, '123 Broadway');
  });

  test('Empty visits give zeroed aggregates and null cover', () {
    final now = DateTime.now();
    final r = Restaurant(
      id: 'e',
      name: 'Empty',
      address: '',
      createdAt: now,
      updatedAt: now,
    );
    expect(r.visitCount, 0);
    expect(r.overallRating, 0);
    expect(r.avgPrice, 0);
    expect(r.coverImage, isNull);
  });
}
