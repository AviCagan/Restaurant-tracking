import 'package:flutter/foundation.dart';

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

/// Mock social backend for the Phase 2 preview. Phase 2 proper replaces this
/// with Firestore (friends, follows, groups, public feed).
class SocialService {
  static final ValueNotifier<List<Friend>> friends = ValueNotifier([
    const Friend('Maya Cohen', 'mayaeats'),
    const Friend('Daniel Roth', 'danroth'),
    const Friend('Sara Levi', 'saralevi'),
  ]);

  static final ValueNotifier<List<Friend>> requests = ValueNotifier([
    const Friend('Avi Friedman', 'avif'),
    const Friend('Noa Bar', 'noab'),
  ]);

  static List<FeedItem> feed() {
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

  /// A friend's favorite restaurants (mock).
  static List<String> favoritesFor(String friendName) {
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

  /// A friend's reviews shared with friends (mock) — newest first.
  static List<FeedItem> reviewsFor(String friendName) {
    return feed().where((f) => f.friendName == friendName).toList()
      ..sort((a, b) => b.when.compareTo(a.when));
  }

  static void addFriend(String username) {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty) return;
    friends.value = [
      ...friends.value,
      Friend(clean, clean.toLowerCase()),
    ];
  }

  static void removeFriend(Friend f) {
    friends.value = friends.value.where((x) => x.username != f.username).toList();
  }

  static void acceptRequest(Friend f) {
    requests.value =
        requests.value.where((x) => x.username != f.username).toList();
    friends.value = [...friends.value, f];
  }

  static void declineRequest(Friend f) {
    requests.value =
        requests.value.where((x) => x.username != f.username).toList();
  }
}
