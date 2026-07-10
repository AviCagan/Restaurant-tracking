import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/category.dart';
import 'category_mapping.dart';

/// The shared, global category database. Every category has one canonical
/// key (its normalized name) that is IDENTICAL for every user — so
/// everyone's "Pizza" is inherently the same category no matter what they
/// relabel it on their own device. A large built-in list ships with the
/// app; user-submitted additions live in Firestore and stream to everyone
/// instantly.
class Catalog {
  /// Canonical key for a label: "Pizzaaaa 🍕" -> "pizzaaaa". Categories
  /// with the same canonical key ARE the same category everywhere.
  static String keyFor(String label) => CategoryMapping.norm(label);

  /// User-submitted categories (live from Firestore).
  static final ValueNotifier<List<AppCategory>> extras =
      ValueNotifier<List<AppCategory>>([]);

  static StreamSubscription? _sub;

  static void start(FirebaseFirestore db) {
    _sub?.cancel();
    _sub = db.collection('catalog').snapshots().listen((snap) {
      extras.value = [
        for (final d in snap.docs)
          if ((d.data()['label'] as String? ?? '').isNotEmpty)
            AppCategory(
              key: d.id,
              label: d.data()['label'] as String,
              iconIndex: (d.data()['iconIndex'] as num?)?.toInt() ?? 16,
            )
      ];
    }, onError: (e) => debugPrint('catalog listen failed: $e'));
  }

  static void stop() {
    _sub?.cancel();
    _sub = null;
    extras.value = [];
  }

  /// Built-ins + everyone's submissions, deduped by canonical key.
  static List<AppCategory> get all {
    final seen = <String>{};
    final out = <AppCategory>[];
    for (final c in [...builtins, ...extras.value]) {
      if (seen.add(c.key)) out.add(c);
    }
    return out;
  }

  /// Case/emoji-insensitive search over the whole catalog.
  static List<AppCategory> search(String query) {
    final q = keyFor(query);
    if (q.isEmpty) return all;
    return [
      for (final c in all)
        if (c.key.contains(q) || keyFor(c.label).contains(q)) c
    ];
  }

  static AppCategory? byKey(String key) {
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }

  /// Submit a brand-new category to the shared database. Returns an error
  /// message, or null on success (it appears for everyone live).
  static Future<String?> submit(String label, int iconIndex) async {
    final clean = label.trim();
    final key = keyFor(clean);
    if (key.length < 2) return 'That name is a little too short.';
    if (clean.length > 30) return 'Keep it under 30 characters.';
    if (_inappropriate(key)) {
      return 'That name isn\'t allowed — keep it food-friendly!';
    }
    if (byKey(key) != null) return null; // already exists — that's fine
    try {
      await FirebaseFirestore.instance.collection('catalog').doc(key).set({
        'label': clean,
        'iconIndex': iconIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('catalog submit failed: $e');
      return 'Couldn\'t save it — check your connection and try again.';
    }
  }

  /// Basic decency filter for user submissions to the shared database.
  static bool _inappropriate(String normalized) {
    const blocked = [
      'fuck', 'shit', 'bitch', 'cunt', 'nigg', 'fagg', 'dick', 'cock',
      'pussy', 'asshole', 'whore', 'slut', 'retard', 'rape', 'nazi',
      'hitler', 'porn', 'penis', 'vagina', 'boob', 'titt', 'cum', 'jizz',
      'anal', 'dildo', 'kys', 'chink', 'spic', 'kike', 'wetback',
    ];
    for (final w in blocked) {
      if (normalized.contains(w)) return true;
    }
    return false;
  }

  /// The short starter set offered at signup (~15).
  static const List<AppCategory> starters = [
    AppCategory(key: 'pizza', label: 'Pizza', iconIndex: 9),
    AppCategory(key: 'burgers', label: 'Burgers', iconIndex: 13),
    AppCategory(key: 'sushi', label: 'Sushi', iconIndex: 12),
    AppCategory(key: 'chinese', label: 'Chinese', iconIndex: 6),
    AppCategory(key: 'mexican', label: 'Mexican', iconIndex: 5),
    AppCategory(key: 'italian', label: 'Italian', iconIndex: 0),
    AppCategory(key: 'fastfood', label: 'Fast Food', iconIndex: 3),
    AppCategory(key: 'breakfast', label: 'Breakfast', iconIndex: 15),
    AppCategory(key: 'cafe', label: 'Cafe', iconIndex: 10),
    AppCategory(key: 'dessert', label: 'Dessert', iconIndex: 14),
    AppCategory(key: 'bbq', label: 'BBQ', iconIndex: 5),
    AppCategory(key: 'seafood', label: 'Seafood', iconIndex: 12),
    AppCategory(key: 'vegan', label: 'Vegan', iconIndex: 7),
    AppCategory(key: 'healthy', label: 'Healthy', iconIndex: 8),
    AppCategory(key: 'fancy', label: 'Fancy', iconIndex: 4),
  ];

  /// The big built-in list. Keys are canonical (keyFor(label)).
  static const List<AppCategory> builtins = [
    ...starters,
    AppCategory(key: 'thai', label: 'Thai', iconIndex: 6),
    AppCategory(key: 'indian', label: 'Indian', iconIndex: 5),
    AppCategory(key: 'japanese', label: 'Japanese', iconIndex: 12),
    AppCategory(key: 'korean', label: 'Korean', iconIndex: 6),
    AppCategory(key: 'vietnamese', label: 'Vietnamese', iconIndex: 6),
    AppCategory(key: 'steakhouse', label: 'Steakhouse', iconIndex: 5),
    AppCategory(key: 'friedchicken', label: 'Fried Chicken', iconIndex: 3),
    AppCategory(key: 'wings', label: 'Wings', iconIndex: 3),
    AppCategory(key: 'sandwiches', label: 'Sandwiches', iconIndex: 13),
    AppCategory(key: 'deli', label: 'Deli', iconIndex: 13),
    AppCategory(key: 'bagels', label: 'Bagels', iconIndex: 11),
    AppCategory(key: 'brunch', label: 'Brunch', iconIndex: 15),
    AppCategory(key: 'coffee', label: 'Coffee', iconIndex: 10),
    AppCategory(key: 'tea', label: 'Tea', iconIndex: 10),
    AppCategory(key: 'boba', label: 'Boba', iconIndex: 10),
    AppCategory(key: 'juice', label: 'Juice', iconIndex: 7),
    AppCategory(key: 'smoothies', label: 'Smoothies', iconIndex: 7),
    AppCategory(key: 'icecream', label: 'Ice Cream', iconIndex: 1),
    AppCategory(key: 'frozenyogurt', label: 'Frozen Yogurt', iconIndex: 1),
    AppCategory(key: 'donuts', label: 'Donuts', iconIndex: 11),
    AppCategory(key: 'bakery', label: 'Bakery', iconIndex: 11),
    AppCategory(key: 'cakes', label: 'Cakes', iconIndex: 14),
    AppCategory(key: 'cookies', label: 'Cookies', iconIndex: 14),
    AppCategory(key: 'chocolate', label: 'Chocolate', iconIndex: 14),
    AppCategory(key: 'candy', label: 'Candy', iconIndex: 14),
    AppCategory(key: 'vegetarian', label: 'Vegetarian', iconIndex: 7),
    AppCategory(key: 'salads', label: 'Salads', iconIndex: 7),
    AppCategory(key: 'glutenfree', label: 'Gluten Free', iconIndex: 7),
    AppCategory(key: 'kosher', label: 'Kosher', iconIndex: 0),
    AppCategory(key: 'kosherdairy', label: 'Kosher Dairy', iconIndex: 1),
    AppCategory(key: 'koshermeat', label: 'Kosher Meat', iconIndex: 2),
    AppCategory(key: 'halal', label: 'Halal', iconIndex: 2),
    AppCategory(key: 'mediterranean', label: 'Mediterranean', iconIndex: 2),
    AppCategory(key: 'middleeastern', label: 'Middle Eastern', iconIndex: 2),
    AppCategory(key: 'greek', label: 'Greek', iconIndex: 2),
    AppCategory(key: 'turkish', label: 'Turkish', iconIndex: 2),
    AppCategory(key: 'lebanese', label: 'Lebanese', iconIndex: 2),
    AppCategory(key: 'israeli', label: 'Israeli', iconIndex: 2),
    AppCategory(key: 'falafel', label: 'Falafel', iconIndex: 2),
    AppCategory(key: 'shawarma', label: 'Shawarma', iconIndex: 2),
    AppCategory(key: 'kebab', label: 'Kebab', iconIndex: 2),
    AppCategory(key: 'ramen', label: 'Ramen', iconIndex: 6),
    AppCategory(key: 'pho', label: 'Pho', iconIndex: 6),
    AppCategory(key: 'noodles', label: 'Noodles', iconIndex: 6),
    AppCategory(key: 'dumplings', label: 'Dumplings', iconIndex: 6),
    AppCategory(key: 'dimsum', label: 'Dim Sum', iconIndex: 6),
    AppCategory(key: 'hotpot', label: 'Hot Pot', iconIndex: 5),
    AppCategory(key: 'filipino', label: 'Filipino', iconIndex: 0),
    AppCategory(key: 'indonesian', label: 'Indonesian', iconIndex: 6),
    AppCategory(key: 'malaysian', label: 'Malaysian', iconIndex: 6),
    AppCategory(key: 'taiwanese', label: 'Taiwanese', iconIndex: 6),
    AppCategory(key: 'cantonese', label: 'Cantonese', iconIndex: 6),
    AppCategory(key: 'szechuan', label: 'Szechuan', iconIndex: 5),
    AppCategory(key: 'spanish', label: 'Spanish', iconIndex: 0),
    AppCategory(key: 'tapas', label: 'Tapas', iconIndex: 4),
    AppCategory(key: 'french', label: 'French', iconIndex: 0),
    AppCategory(key: 'german', label: 'German', iconIndex: 0),
    AppCategory(key: 'british', label: 'British', iconIndex: 0),
    AppCategory(key: 'irish', label: 'Irish', iconIndex: 4),
    AppCategory(key: 'polish', label: 'Polish', iconIndex: 0),
    AppCategory(key: 'russian', label: 'Russian', iconIndex: 0),
    AppCategory(key: 'ukrainian', label: 'Ukrainian', iconIndex: 0),
    AppCategory(key: 'ethiopian', label: 'Ethiopian', iconIndex: 5),
    AppCategory(key: 'moroccan', label: 'Moroccan', iconIndex: 5),
    AppCategory(key: 'caribbean', label: 'Caribbean', iconIndex: 5),
    AppCategory(key: 'jamaican', label: 'Jamaican', iconIndex: 5),
    AppCategory(key: 'cuban', label: 'Cuban', iconIndex: 5),
    AppCategory(key: 'puertorican', label: 'Puerto Rican', iconIndex: 5),
    AppCategory(key: 'dominican', label: 'Dominican', iconIndex: 5),
    AppCategory(key: 'brazilian', label: 'Brazilian', iconIndex: 5),
    AppCategory(key: 'peruvian', label: 'Peruvian', iconIndex: 12),
    AppCategory(key: 'argentinian', label: 'Argentinian', iconIndex: 5),
    AppCategory(key: 'colombian', label: 'Colombian', iconIndex: 5),
    AppCategory(key: 'venezuelan', label: 'Venezuelan', iconIndex: 5),
    AppCategory(key: 'texmex', label: 'Tex-Mex', iconIndex: 5),
    AppCategory(key: 'tacos', label: 'Tacos', iconIndex: 5),
    AppCategory(key: 'burritos', label: 'Burritos', iconIndex: 5),
    AppCategory(key: 'quesadillas', label: 'Quesadillas', iconIndex: 5),
    AppCategory(key: 'nachos', label: 'Nachos', iconIndex: 5),
    AppCategory(key: 'american', label: 'American', iconIndex: 13),
    AppCategory(key: 'southern', label: 'Southern', iconIndex: 5),
    AppCategory(key: 'cajun', label: 'Cajun', iconIndex: 5),
    AppCategory(key: 'soulfood', label: 'Soul Food', iconIndex: 5),
    AppCategory(key: 'hawaiian', label: 'Hawaiian', iconIndex: 12),
    AppCategory(key: 'poke', label: 'Poke', iconIndex: 12),
    AppCategory(key: 'fishandchips', label: 'Fish and Chips', iconIndex: 12),
    AppCategory(key: 'oysters', label: 'Oysters', iconIndex: 12),
    AppCategory(key: 'lobster', label: 'Lobster', iconIndex: 12),
    AppCategory(key: 'crab', label: 'Crab', iconIndex: 12),
    AppCategory(key: 'shrimp', label: 'Shrimp', iconIndex: 12),
    AppCategory(key: 'finedining', label: 'Fine Dining', iconIndex: 4),
    AppCategory(key: 'casual', label: 'Casual', iconIndex: 0),
    AppCategory(key: 'diner', label: 'Diner', iconIndex: 15),
    AppCategory(key: 'foodtruck', label: 'Food Truck', iconIndex: 17),
    AppCategory(key: 'streetfood', label: 'Street Food', iconIndex: 17),
    AppCategory(key: 'buffet', label: 'Buffet', iconIndex: 0),
    AppCategory(key: 'allyoucaneat', label: 'All You Can Eat', iconIndex: 0),
    AppCategory(key: 'latenight', label: 'Late Night', iconIndex: 4),
    AppCategory(key: 'bar', label: 'Bar', iconIndex: 4),
    AppCategory(key: 'sportsbar', label: 'Sports Bar', iconIndex: 4),
    AppCategory(key: 'pub', label: 'Pub', iconIndex: 4),
    AppCategory(key: 'brewery', label: 'Brewery', iconIndex: 4),
    AppCategory(key: 'winery', label: 'Winery', iconIndex: 4),
    AppCategory(key: 'cocktails', label: 'Cocktails', iconIndex: 4),
    AppCategory(key: 'rooftop', label: 'Rooftop', iconIndex: 4),
    AppCategory(key: 'datenight', label: 'Date Night', iconIndex: 4),
    AppCategory(key: 'familyfriendly', label: 'Family Friendly', iconIndex: 0),
    AppCategory(key: 'kidfriendly', label: 'Kid Friendly', iconIndex: 0),
    AppCategory(key: 'petfriendly', label: 'Pet Friendly', iconIndex: 7),
    AppCategory(key: 'outdoorseating', label: 'Outdoor Seating', iconIndex: 7),
    AppCategory(key: 'waterfront', label: 'Waterfront', iconIndex: 12),
    AppCategory(key: 'livemusic', label: 'Live Music', iconIndex: 4),
    AppCategory(key: 'karaoke', label: 'Karaoke', iconIndex: 4),
    AppCategory(key: 'cheapeats', label: 'Cheap Eats', iconIndex: 3),
    AppCategory(key: 'splurge', label: 'Splurge', iconIndex: 4),
    AppCategory(key: 'hiddengem', label: 'Hidden Gem', iconIndex: 8),
    AppCategory(key: 'holeinthewall', label: 'Hole in the Wall', iconIndex: 8),
    AppCategory(key: 'comfortfood', label: 'Comfort Food', iconIndex: 13),
    AppCategory(key: 'soup', label: 'Soup', iconIndex: 6),
    AppCategory(key: 'macandcheese', label: 'Mac and Cheese', iconIndex: 13),
    AppCategory(key: 'pasta', label: 'Pasta', iconIndex: 0),
    AppCategory(key: 'lasagna', label: 'Lasagna', iconIndex: 0),
    AppCategory(key: 'calzones', label: 'Calzones', iconIndex: 9),
    AppCategory(key: 'flatbread', label: 'Flatbread', iconIndex: 9),
    AppCategory(key: 'wraps', label: 'Wraps', iconIndex: 13),
    AppCategory(key: 'gyros', label: 'Gyros', iconIndex: 2),
    AppCategory(key: 'paninis', label: 'Paninis', iconIndex: 13),
    AppCategory(key: 'subs', label: 'Subs', iconIndex: 13),
    AppCategory(key: 'cheesesteaks', label: 'Cheesesteaks', iconIndex: 13),
    AppCategory(key: 'hotdogs', label: 'Hot Dogs', iconIndex: 3),
    AppCategory(key: 'pretzels', label: 'Pretzels', iconIndex: 11),
    AppCategory(key: 'empanadas', label: 'Empanadas', iconIndex: 5),
    AppCategory(key: 'arepas', label: 'Arepas', iconIndex: 5),
    AppCategory(key: 'ceviche', label: 'Ceviche', iconIndex: 12),
    AppCategory(key: 'tamales', label: 'Tamales', iconIndex: 5),
    AppCategory(key: 'crepes', label: 'Crepes', iconIndex: 11),
    AppCategory(key: 'waffles', label: 'Waffles', iconIndex: 11),
    AppCategory(key: 'pancakes', label: 'Pancakes', iconIndex: 11),
    AppCategory(key: 'frenchtoast', label: 'French Toast', iconIndex: 11),
    AppCategory(key: 'omelettes', label: 'Omelettes', iconIndex: 15),
    AppCategory(key: 'acaibowls', label: 'Acai Bowls', iconIndex: 7),
    AppCategory(key: 'avocadotoast', label: 'Avocado Toast', iconIndex: 7),
    AppCategory(key: 'charcuterie', label: 'Charcuterie', iconIndex: 4),
    AppCategory(key: 'cheese', label: 'Cheese', iconIndex: 1),
    AppCategory(key: 'schnitzel', label: 'Schnitzel', iconIndex: 2),
    AppCategory(key: 'curry', label: 'Curry', iconIndex: 5),
    AppCategory(key: 'tandoori', label: 'Tandoori', iconIndex: 5),
    AppCategory(key: 'biryani', label: 'Biryani', iconIndex: 5),
    AppCategory(key: 'samosas', label: 'Samosas', iconIndex: 5),
    AppCategory(key: 'teriyaki', label: 'Teriyaki', iconIndex: 12),
    AppCategory(key: 'tempura', label: 'Tempura', iconIndex: 12),
    AppCategory(key: 'katsu', label: 'Katsu', iconIndex: 12),
    AppCategory(key: 'bento', label: 'Bento', iconIndex: 12),
    AppCategory(key: 'mochi', label: 'Mochi', iconIndex: 14),
    AppCategory(key: 'matcha', label: 'Matcha', iconIndex: 10),
    AppCategory(key: 'espresso', label: 'Espresso', iconIndex: 10),
    AppCategory(key: 'coldbrew', label: 'Cold Brew', iconIndex: 10),
    AppCategory(key: 'milkshakes', label: 'Milkshakes', iconIndex: 1),
    AppCategory(key: 'lemonade', label: 'Lemonade', iconIndex: 7),
    AppCategory(key: 'winebar', label: 'Wine Bar', iconIndex: 4),
    AppCategory(key: 'beergarden', label: 'Beer Garden', iconIndex: 4),
    AppCategory(key: 'speakeasy', label: 'Speakeasy', iconIndex: 4),
    AppCategory(key: 'gastropub', label: 'Gastropub', iconIndex: 4),
  ];
}
