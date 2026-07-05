import 'package:flutter/foundation.dart';

import '../models/category.dart';

/// A place on the food map that friends have rated.
class MapPlace {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;

  /// Category keys as the friends tagged them (may be named differently from
  /// the current user's categories — resolved via CategoryMapping).
  final List<String> categoryKeys;
  final List<FriendVisit> visits;

  const MapPlace({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.categoryKeys,
    required this.visits,
  });

  /// Weighted (here: average) rating across friends' visits, 0..10.
  double get rating {
    if (visits.isEmpty) return 0;
    return visits.fold<double>(0, (s, v) => s + v.rating) / visits.length;
  }
}

/// A friend / follow.
class Friend {
  final String name;
  final String username;
  const Friend(this.name, this.username);

  String get initials {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (p.isEmpty) return '?';
    if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
    return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
  }
}

/// A rating shared by a friend, shown in the social feed.
class FeedItem {
  final String friendName;
  final String restaurantName;
  final String location;
  final double rating;
  final DateTime when;
  final String note;
  const FeedItem({
    required this.friendName,
    required this.restaurantName,
    required this.location,
    required this.rating,
    required this.when,
    this.note = '',
  });
}

/// A friend's visit to a specific restaurant (their rating + short review).
class FriendVisit {
  final Friend friend;
  final double rating;
  final String review;
  const FriendVisit(this.friend, this.rating, this.review);

  bool get liked => rating >= 7;
}

/// Social backend. In demo mode it serves mock data; when the Firebase layer
/// signs in it flips [cloudMode] on, keeps these same notifiers/getters
/// populated from Firestore, and delegates all actions to the cloud.
class SocialService {
  // ---- Cloud plumbing (set by lib/data/firebase_services.dart) ----
  static bool cloudMode = false;
  static Future<bool> Function(String username)? cloudAddFriend;
  static Future<void> Function(Friend f)? cloudRemoveFriend;
  static Future<void> Function(Friend f)? cloudAcceptRequest;
  static Future<void> Function(Friend f)? cloudDeclineRequest;
  static List<FeedItem> cloudFeed = [];
  static List<MapPlace> cloudPlaces = [];
  static Map<String, List<FriendVisit>> cloudAt = {}; // by lowercased name
  static Map<String, List<String>> cloudFavorites = {}; // by friend name
  static Map<String, List<FeedItem>> cloudReviews = {}; // by friend name
  static Map<String, List<AppCategory>> cloudCategories = {}; // by friend name

  static final ValueNotifier<List<Friend>> friends = ValueNotifier([
    const Friend('Maya Cohen', 'mayaeats'),
    const Friend('Daniel Roth', 'danroth'),
    const Friend('Sara Levi', 'saralevi'),
  ]);

  static final ValueNotifier<List<Friend>> requests = ValueNotifier([
    const Friend('Avi Friedman', 'avif'),
    const Friend('Noa Bar', 'noab'),
  ]);

  /// Called by the cloud layer on sign-out to restore the demo data.
  static void resetToDemo() {
    cloudMode = false;
    cloudFeed = [];
    cloudPlaces = [];
    cloudAt = {};
    cloudFavorites = {};
    cloudReviews = {};
    cloudCategories = {};
    friends.value = [
      const Friend('Maya Cohen', 'mayaeats'),
      const Friend('Daniel Roth', 'danroth'),
      const Friend('Sara Levi', 'saralevi'),
    ];
    requests.value = [
      const Friend('Avi Friedman', 'avif'),
      const Friend('Noa Bar', 'noab'),
    ];
  }

  static List<FeedItem> feed() {
    if (cloudMode) {
      return [...cloudFeed]..sort((a, b) => b.when.compareTo(a.when));
    }
    final now = DateTime.now();
    return [
      FeedItem(
        friendName: 'Maya Cohen',
        restaurantName: 'Taco Bell',
        location: 'Richmond Ave, Staten Island',
        rating: 6.5,
        when: now.subtract(const Duration(hours: 3)),
        note: 'Late night run — solid as always.',
      ),
      FeedItem(
        friendName: 'Daniel Roth',
        restaurantName: 'Holy Schnitzel',
        location: 'Nome Ave',
        rating: 8.0,
        when: now.subtract(const Duration(days: 1)),
        note: 'Best schnitzel on the island.',
      ),
      FeedItem(
        friendName: 'Sara Levi',
        restaurantName: 'KAIFENG',
        location: 'Jewett Ave',
        rating: 7.5,
        when: now.subtract(const Duration(days: 2)),
      ),
      FeedItem(
        friendName: 'Maya Cohen',
        restaurantName: 'Dairy Palace',
        location: 'Victory Blvd',
        rating: 9.0,
        when: now.subtract(const Duration(days: 3)),
        note: 'Obsessed with the milkshakes.',
      ),
    ];
  }

  /// A friend's favorite restaurants.
  static List<String> favoritesFor(String friendName) {
    if (cloudMode) return cloudFavorites[friendName] ?? const [];
    switch (friendName) {
      case 'Maya Cohen':
        return ['Dairy Palace', 'Taco Bell', 'Holy Schnitzel'];
      case 'Daniel Roth':
        return ['Holy Schnitzel', 'KAIFENG'];
      case 'Sara Levi':
        return ['KAIFENG', 'Sweetgreen', 'Dairy Palace'];
      default:
        return const [];
    }
  }

  /// A friend's reviews shared with friends — newest first.
  static List<FeedItem> reviewsFor(String friendName) {
    if (cloudMode) {
      return [...(cloudReviews[friendName] ?? const [])]
        ..sort((a, b) => b.when.compareTo(a.when));
    }
    return feed().where((f) => f.friendName == friendName).toList()
      ..sort((a, b) => b.when.compareTo(a.when));
  }

  static const _reviewSnippets = [
    'Would 100% go back!',
    'Pretty solid all around.',
    'Not really my vibe.',
    'Absolutely loved it.',
    'Service was a little slow.',
    'Great value for what you get.',
    'Honestly a bit overrated.',
    'So good, came back twice.',
    'Cozy spot, great for groups.',
    'Expected more, sadly.',
  ];

  /// Friends who have been to [restaurantName] (mock, deterministic from the
  /// friends list so it stays stable per restaurant).
  static List<FriendVisit> friendsAtRestaurant(String restaurantName) {
    if (cloudMode) {
      return cloudAt[restaurantName.trim().toLowerCase()] ?? const [];
    }
    final out = <FriendVisit>[];
    for (final f in friends.value) {
      final h = '${f.username}|$restaurantName'.hashCode.abs();
      if (h % 3 == 2) continue; // most friends went
      final rating = (h % 10) + 1;
      out.add(FriendVisit(
        f,
        rating.toDouble(),
        _reviewSnippets[h % _reviewSnippets.length],
      ));
    }
    // Always show at least one if we have friends, so the section isn't empty.
    if (out.isEmpty && friends.value.isNotEmpty) {
      final f = friends.value.first;
      final h = '${f.username}|$restaurantName'.hashCode.abs();
      out.add(FriendVisit(
          f, ((h % 10) + 1).toDouble(), _reviewSnippets[h % _reviewSnippets.length]));
    }
    return out;
  }

  /// Categories your friends use — some named differently from yours, to
  /// demo the compare/import flow. (Mock.)
  static List<AppCategory> friendCategories() => const [
        AppCategory(key: 'f_dairy', label: 'Dairy 🧀', iconIndex: 1),
        AppCategory(key: 'f_meat', label: 'Fleishig 🍖', iconIndex: 2),
        AppCategory(key: 'f_mex', label: 'Tex-Mex', iconIndex: 5),
        AppCategory(key: 'f_chinese', label: 'Chinese', iconIndex: 6),
        AppCategory(key: 'f_sushi', label: 'Sushi', iconIndex: 12),
        AppCategory(key: 'f_cafe', label: 'Coffee & Cafe', iconIndex: 15),
      ];

  /// A specific friend's categories.
  static List<AppCategory> categoriesFor(String friendName) {
    if (cloudMode) return cloudCategories[friendName] ?? const [];
    final all = [...friendCategories()];
    all.sort((a, b) => '${a.key}$friendName'
        .hashCode
        .compareTo('${b.key}$friendName'.hashCode));
    return all.take(4).toList();
  }

  /// Friend-rated places for the food map.
  static List<MapPlace> mapPlaces() {
    if (cloudMode) return cloudPlaces;
    const data = [
      ('Taco Bell', '2259 Richmond Ave', 40.5827, -74.1648, ['f_mex']),
      ('KAIFENG', '951 Jewett Ave', 40.6193, -74.1206, ['f_chinese']),
      ('Holy Schnitzel', '438 Nome Ave', 40.5469, -74.1735, ['f_meat']),
      ('Dairy Palace', '2216 Victory Blvd', 40.6098, -74.1330, ['f_dairy']),
      ('Sushi Nakazawa', '1080 Bay St', 40.6149, -74.0712, ['f_sushi']),
      ('Joe & Pat\'s', '1758 Victory Blvd', 40.6147, -74.1099, ['f_dairy']),
      ('Mason\'s Coffee', '76 Lincoln Ave', 40.5983, -74.0908, ['f_cafe']),
      ('Beans & Leaves', '1115 Richmond Rd', 40.5806, -74.0967, ['f_cafe']),
      ('El Patron', '345 New Dorp Ln', 40.5732, -74.1158, ['f_mex']),
    ];
    return [
      for (final d in data)
        MapPlace(
          id: d.$1,
          name: d.$1,
          address: '${d.$2}, Staten Island, NY',
          lat: d.$3,
          lng: d.$4,
          categoryKeys: List<String>.from(d.$5),
          visits: friendsAtRestaurant(d.$1),
        ),
    ];
  }

  static void addFriend(String username) {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty) return;
    if (cloudMode) {
      cloudAddFriend?.call(clean); // sends a friend request
      return;
    }
    friends.value = [
      ...friends.value,
      Friend(clean, clean.toLowerCase()),
    ];
  }

  static void removeFriend(Friend f) {
    if (cloudMode) {
      cloudRemoveFriend?.call(f);
      return;
    }
    friends.value = friends.value.where((x) => x.username != f.username).toList();
  }

  static void acceptRequest(Friend f) {
    if (cloudMode) {
      cloudAcceptRequest?.call(f);
      return;
    }
    requests.value =
        requests.value.where((x) => x.username != f.username).toList();
    friends.value = [...friends.value, f];
  }

  static void declineRequest(Friend f) {
    if (cloudMode) {
      cloudDeclineRequest?.call(f);
      return;
    }
    requests.value =
        requests.value.where((x) => x.username != f.username).toList();
  }
}
