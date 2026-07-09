import 'package:flutter/foundation.dart';

import '../models/category.dart';
import 'block_store.dart';
import 'plan_store.dart';

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

  /// Price tier they rated (1..4, 0 = unknown).
  final int price;

  const FeedItem({
    required this.friendName,
    required this.restaurantName,
    required this.location,
    required this.rating,
    required this.when,
    this.note = '',
    this.price = 0,
  });
}

/// A friend's visit to a specific restaurant (their rating + short review).
class FriendVisit {
  final Friend friend;
  final double rating;
  final String review;

  /// Price tier they rated (1..4, 0 = unknown).
  final int price;

  const FriendVisit(this.friend, this.rating, this.review, {this.price = 0});

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

  /// Plan invites friends sent you (live from the cloud).
  static final ValueNotifier<List<PlanInvite>> invites =
      ValueNotifier<List<PlanInvite>>([]);

  /// Set by the cloud layer: sends a plan invite to a friend by username.
  static Future<void> Function(String username, Plan plan)? cloudSendInvite;

  /// Set by the cloud layer: RSVP to a plan invite (true = going).
  static Future<void> Function(PlanInvite invite, bool going)?
      cloudRespondInvite;

  /// Set by the cloud layer: cancel my plan for every invited friend.
  static Future<void> Function(Plan plan)? cloudCancelPlan;

  /// Set by the cloud layer: RSVP directly to a plan owner (used to back
  /// out of a plan I previously joined). Restaurant name + time are for
  /// the notification email.
  static Future<void> Function(String ownerUid, String planId, bool going,
      String restaurantName, DateTime? when)? cloudSendReply;

  /// Set by the cloud layer: re-fetch every friend's categories (and
  /// auto-link matching ones).
  static Future<void> Function()? cloudRefreshCategories;

  /// Accept or decline a plan invite.
  static Future<void> respondInvite(PlanInvite invite, bool going) async {
    await cloudRespondInvite?.call(invite, going);
  }

  static final ValueNotifier<List<Friend>> friends =
      ValueNotifier<List<Friend>>([]);

  static final ValueNotifier<List<Friend>> requests =
      ValueNotifier<List<Friend>>([]);

  /// Called by the cloud layer on sign-out / account deletion: back to a
  /// clean, empty local state.
  static void resetLocal() {
    cloudMode = false;
    cloudFeed = [];
    cloudPlaces = [];
    cloudAt = {};
    cloudFavorites = {};
    cloudReviews = {};
    cloudCategories = {};
    invites.value = [];
    friends.value = [];
    requests.value = [];
  }

  static List<FeedItem> feed() {
    if (cloudMode) {
      return [...cloudFeed]..sort((a, b) => b.when.compareTo(a.when));
    }
    return const [];
  }

  /// A friend's favorite restaurants.
  static List<String> favoritesFor(String friendName) {
    if (cloudMode) return cloudFavorites[friendName] ?? const [];
    return const [];
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

  /// Friends who have been to [restaurantName].
  static List<FriendVisit> friendsAtRestaurant(String restaurantName) {
    if (cloudMode) {
      return cloudAt[restaurantName.trim().toLowerCase()] ?? const [];
    }
    return const [];
  }

  /// A specific friend's categories.
  static List<AppCategory> categoriesFor(String friendName) {
    if (cloudMode) return cloudCategories[friendName] ?? const [];
    return const [];
  }

  /// Friend-rated places for the food map.
  static List<MapPlace> mapPlaces() {
    if (cloudMode) return cloudPlaces;
    return const [];
  }

  /// Sends a friend request. Returns a user-facing error message, or null
  /// when the request went out.
  static Future<String?> addFriend(String username) async {
    final clean = username.trim().replaceAll('@', '');
    if (clean.isEmpty) return 'Type a username first.';
    if (!cloudMode) {
      return 'Sign in with Google to add friends.';
    }
    final sent = await cloudAddFriend?.call(clean) ?? false;
    return sent ? null : 'No user found with that username.';
  }

  static void removeFriend(Friend f) {
    if (cloudMode) {
      cloudRemoveFriend?.call(f);
      return;
    }
    friends.value = friends.value.where((x) => x.username != f.username).toList();
  }

  /// Block someone: drop the friendship and hide them everywhere. Their
  /// pending request (if any) is dismissed too.
  static Future<void> block(Friend f) async {
    await BlockStore.block(f.username);
    if (cloudMode) {
      cloudRemoveFriend?.call(f);
      cloudDeclineRequest?.call(f);
    }
    friends.value =
        friends.value.where((x) => x.username != f.username).toList();
    requests.value =
        requests.value.where((x) => x.username != f.username).toList();
  }

  static Future<void> unblock(String username) => BlockStore.unblock(username);

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
