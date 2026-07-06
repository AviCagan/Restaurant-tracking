import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import 'app_prefs.dart';
import 'auth_service.dart';
import 'category_mapping.dart';
import 'category_store.dart';
import 'friend_group_store.dart';
import 'plan_store.dart';
import 'restaurant_database.dart';
import 'social_service.dart';

/// Boots the cloud layer: watches Firebase auth state and starts/stops the
/// live sync. Call once from main() after Firebase.initializeApp.
class CloudBoot {
  static StreamSubscription? _authSub;

  /// True when a Google account is signed in but hasn't finished the quick
  /// profile setup (name / username / categories) yet.
  static final ValueNotifier<bool> needsSetup = ValueNotifier<bool>(false);

  static void init() {
    _authSub?.cancel();
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users').doc(user.uid).get();
        if (snap.exists && (snap.data()?.containsKey('username') ?? false)) {
          await FirebaseAuthService.loadProfile(user);
          startServices(user.uid);
        } else {
          needsSetup.value = true; // brand new — run the setup screen
        }
      } else {
        needsSetup.value = false;
        _CloudSocial.stop();
        _CloudSync.stop();
      }
    });
  }

  static void startServices(String uid) {
    _CloudSocial.start(uid);
    _CloudSync.start(uid);
  }
}

class FirebaseAuthService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Google sign-in. Prefers the native account-picker flow (reliable, no
  /// browser); falls back to the browser redirect flow if no web client id
  /// is configured.
  static Future<UserProfile?> signInWithGoogle() async {
    fb.User? user;
    if (AppConfig.googleWebClientId.isNotEmpty) {
      final googleUser = await GoogleSignIn(
              serverClientId: AppConfig.googleWebClientId)
          .signIn();
      if (googleUser == null) return null; // user cancelled
      final auth = await googleUser.authentication;
      final cred = fb.GoogleAuthProvider.credential(
          accessToken: auth.accessToken, idToken: auth.idToken);
      user = (await fb.FirebaseAuth.instance.signInWithCredential(cred)).user;
    } else {
      final cred = await fb.FirebaseAuth.instance
          .signInWithProvider(fb.GoogleAuthProvider());
      user = cred.user;
    }
    if (user == null) return null;
    final snap = await _db.collection('users').doc(user.uid).get();
    if (snap.exists && (snap.data()?.containsKey('username') ?? false)) {
      return loadProfile(user);
    }
    CloudBoot.needsSetup.value = true; // new user -> quick setup screen
    return null;
  }

  /// Suggested username for the setup screen, derived from the account email.
  static String suggestedUsername() {
    final user = fb.FirebaseAuth.instance.currentUser;
    var base = (user?.email ?? 'foodie').split('@').first.toLowerCase();
    base = base.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    return base.isEmpty ? 'foodie' : base;
  }

  static String suggestedName() =>
      fb.FirebaseAuth.instance.currentUser?.displayName ?? '';

  /// Finishes first-time setup: claims the chosen username and creates the
  /// profile. Returns an error message, or null on success.
  static Future<String?> completeSetup(String name, String username) async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) return 'Not signed in.';
    final clean =
        username.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.length < 3) return 'Username needs at least 3 characters.';

    final ref = _db.collection('usernames').doc(clean);
    try {
      await _db.runTransaction((tx) async {
        final s = await tx.get(ref);
        if (s.exists && s.data()!['uid'] != user.uid) {
          throw Exception('taken');
        }
        tx.set(ref, {'uid': user.uid});
      });
    } catch (_) {
      return 'That username is taken — try another.';
    }

    final profile = UserProfile(
        id: user.uid,
        name: name.trim().isEmpty ? (user.displayName ?? 'You') : name.trim(),
        username: clean);
    await _db.collection('users').doc(user.uid).set({
      'name': profile.name,
      'username': profile.username,
      'bio': '',
      'categoriesViewable': AppPrefs.categoriesViewable.value,
      'defaultVisibility': AppPrefs.defaultVisibility.value,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    AuthService.onProfileChanged = null;
    await AuthService.updateProfile(profile);
    AuthService.onProfileChanged = _pushProfile;
    CloudBoot.startServices(user.uid);
    CloudBoot.needsSetup.value = false;
    return null;
  }

  /// Loads an existing Firestore profile and mirrors it locally.
  static Future<UserProfile> loadProfile(fb.User user) async {
    final snap = await _db.collection('users').doc(user.uid).get();
    final d = snap.data() ?? {};
    final profile = UserProfile(
      id: user.uid,
      name: d['name'] as String? ?? user.displayName ?? 'You',
      username: d['username'] as String? ?? 'you',
      bio: d['bio'] as String? ?? '',
    );
    // Mirror into the local auth (drives every screen). Avoid feedback loop:
    AuthService.onProfileChanged = null;
    await AuthService.updateProfile(profile);
    AuthService.onProfileChanged = _pushProfile;
    return profile;
  }

  static Future<void> _pushProfile(UserProfile p) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'name': p.name,
      'username': p.username,
      'bio': p.bio,
    }, SetOptions(merge: true));
    // Best-effort username claim for the (possibly new) handle.
    try {
      await _db.collection('usernames').doc(p.username.toLowerCase()).set(
          {'uid': uid});
    } catch (_) {}
  }

  static Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await fb.FirebaseAuth.instance.signOut();
    await AuthService.signOut();
    SocialService.resetLocal();
  }

  /// Permanently deletes the cloud account: re-verifies with Google, removes
  /// you from every friend's list, frees the username, wipes the user's
  /// Firestore data and uploaded photos, then deletes the Firebase Auth
  /// user. Local data stays on this device. Returns an error message, or
  /// null on success.
  static Future<String?> deleteAccount() async {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Local/demo account — nothing in the cloud to remove.
      await AuthService.signOut();
      SocialService.resetLocal();
      return null;
    }

    // Re-authenticate FIRST. Firebase refuses account deletion on a stale
    // session (requires-recent-login); doing it up front means we can't end
    // up wiping the data and then failing to remove the sign-in.
    if (AppConfig.googleWebClientId.isNotEmpty) {
      try {
        final googleUser = await GoogleSignIn(
                serverClientId: AppConfig.googleWebClientId)
            .signIn();
        if (googleUser == null) return 'Deletion cancelled.';
        final auth = await googleUser.authentication;
        await user.reauthenticateWithCredential(
            fb.GoogleAuthProvider.credential(
                accessToken: auth.accessToken, idToken: auth.idToken));
      } catch (e) {
        debugPrint('reauth for deletion failed: $e');
        return 'Couldn\'t verify it\'s you — check your connection and '
            'try again.';
      }
    }

    final uid = user.uid;

    // Who are my friends? (Needed to remove myself from their lists.)
    var friendUids = const <String>[];
    try {
      final snap =
          await _db.collection('users').doc(uid).collection('friends').get();
      friendUids = [for (final d in snap.docs) d.id];
    } catch (_) {}

    _CloudSocial.stop();
    _CloudSync.stop();

    // Unfriend everyone — delete my entry from each friend's list so I
    // don't linger in their app after I'm gone.
    for (var i = 0; i < friendUids.length; i += 400) {
      try {
        final batch = _db.batch();
        for (final f in friendUids.skip(i).take(400)) {
          batch.delete(
              _db.collection('users').doc(f).collection('friends').doc(uid));
        }
        await batch.commit();
      } catch (_) {}
    }

    // Free the username reservation.
    final username = AuthService.user.value?.username;
    if (username != null && username.isNotEmpty) {
      try {
        await _db.collection('usernames').doc(username.toLowerCase()).delete();
      } catch (_) {}
    }

    // Wipe subcollections (best effort — batches max out at 500 writes).
    for (final sub in [
      'restaurants',
      'categories',
      'friends',
      'friendRequests',
      'planInvites',
    ]) {
      try {
        final snap =
            await _db.collection('users').doc(uid).collection(sub).get();
        for (var i = 0; i < snap.docs.length; i += 400) {
          final batch = _db.batch();
          for (final d in snap.docs.skip(i).take(400)) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      } catch (_) {}
    }

    // Uploaded photos.
    try {
      final list =
          await FirebaseStorage.instance.ref('users/$uid/photos').listAll();
      for (final item in list.items) {
        try {
          await item.delete();
        } catch (_) {}
      }
    } catch (_) {}

    try {
      await _db.collection('users').doc(uid).delete();
    } catch (_) {}

    // Remove the sign-in itself, then clear every trace locally so the app
    // returns to the welcome screen and a fresh sign-in redoes setup.
    String? error;
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      error = e.code == 'requires-recent-login'
          ? 'Your data was removed, but the sign-in needs a fresh login to '
              'delete — sign in once more and delete again.'
          : (e.message ?? 'Could not remove the sign-in.');
    } catch (e) {
      error = 'Could not remove the sign-in: $e';
    }

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await fb.FirebaseAuth.instance.signOut();
    } catch (_) {}
    CloudBoot.needsSetup.value = false;
    await AuthService.signOut();
    SocialService.resetLocal();
    return error;
  }

  static bool get isCloudSignedIn =>
      fb.FirebaseAuth.instance.currentUser != null;
}

/// Live friends / requests / shared-restaurant data -> SocialService caches.
class _CloudSocial {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static String? _uid;
  static StreamSubscription? _friendsSub;
  static StreamSubscription? _requestsSub;
  static StreamSubscription? _invitesSub;
  static final Map<String, StreamSubscription> _restaurantSubs = {};
  static final Map<String, List<Restaurant>> _friendRestaurants = {};
  static final Map<String, Friend> _friendByUid = {};

  static void start(String uid) {
    stop();
    _uid = uid;
    SocialService.cloudMode = true;
    SocialService.friends.value = [];
    SocialService.requests.value = [];
    SocialService.cloudAddFriend = _sendRequest;
    SocialService.cloudRemoveFriend = _removeFriend;
    SocialService.cloudAcceptRequest = _accept;
    SocialService.cloudDeclineRequest = _decline;
    SocialService.cloudSendInvite = _sendPlanInvite;

    var invitesFirst = true;
    _invitesSub = _db
        .collection('users').doc(uid).collection('planInvites')
        .snapshots()
        .listen((snap) {
      final invites = <PlanInvite>[];
      for (final d in snap.docs) {
        final data = d.data();
        final when = DateTime.fromMillisecondsSinceEpoch(
            (data['when'] as num?)?.toInt() ?? 0);
        if (when.isBefore(
            DateTime.now().subtract(const Duration(days: 1)))) {
          continue; // stale
        }
        invites.add(PlanInvite(
          id: d.id,
          fromName: data['fromName'] as String? ?? 'A friend',
          restaurantName: data['restaurantName'] as String? ?? 'a restaurant',
          address: data['address'] as String? ?? '',
          when: when,
        ));
      }
      invites.sort((a, b) => a.when.compareTo(b.when));
      SocialService.invites.value = invites;
      if (!invitesFirst) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() ?? {};
          final when = DateTime.fromMillisecondsSinceEpoch(
              (data['when'] as num?)?.toInt() ?? 0);
          NotificationService.show(
            '${data['fromName'] ?? 'A friend'} invited you! 🎉',
            '${data['restaurantName'] ?? 'A restaurant'} · '
                '${DateFormat.MMMEd().add_jm().format(when)}',
            id: change.doc.id.hashCode & 0x7fffffff,
          );
          break;
        }
      }
      invitesFirst = false;
    }, onError: (_) {});

    _friendsSub = _db
        .collection('users').doc(uid).collection('friends')
        .snapshots()
        .listen((snap) {
      _friendByUid.clear();
      for (final d in snap.docs) {
        _friendByUid[d.id] = Friend(
            d.data()['name'] as String? ?? 'Friend',
            d.data()['username'] as String? ?? d.id);
      }
      SocialService.friends.value = _friendByUid.values.toList();
      _syncRestaurantListeners();
    });

    var requestsFirst = true;
    _requestsSub = _db
        .collection('users').doc(uid).collection('friendRequests')
        .snapshots()
        .listen((snap) {
      SocialService.requests.value = [
        for (final d in snap.docs)
          Friend(d.data()['name'] as String? ?? 'Someone',
              d.data()['username'] as String? ?? d.id)
      ];
      // Pop a notification for requests that arrive while signed in (not
      // for ones already waiting when the listener starts).
      if (!requestsFirst) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() ?? {};
          NotificationService.show(
            'New friend request 👋',
            '${data['name'] ?? 'Someone'} (@${data['username'] ?? '?'}) '
                'wants to be friends on YUMS!',
            id: change.doc.id.hashCode & 0x7fffffff,
          );
        }
      }
      requestsFirst = false;
    }, onError: (e) => debugPrint('friend requests listen failed: $e'));
  }

  static void stop() {
    _friendsSub?.cancel();
    _requestsSub?.cancel();
    _invitesSub?.cancel();
    for (final s in _restaurantSubs.values) {
      s.cancel();
    }
    _restaurantSubs.clear();
    _friendRestaurants.clear();
    _friendByUid.clear();
    _uid = null;
  }

  static void _syncRestaurantListeners() {
    // Drop listeners for removed friends.
    for (final uid in _restaurantSubs.keys.toList()) {
      if (!_friendByUid.containsKey(uid)) {
        _restaurantSubs.remove(uid)?.cancel();
        _friendRestaurants.remove(uid);
      }
    }
    // Add listeners for new friends.
    for (final uid in _friendByUid.keys) {
      if (_restaurantSubs.containsKey(uid)) continue;
      var firstSnapshot = true;
      _restaurantSubs[uid] = _db
          .collection('users').doc(uid).collection('restaurants')
          .where('visibility', isEqualTo: 'friends')
          .snapshots()
          .listen((snap) {
        _friendRestaurants[uid] = [
          for (final d in snap.docs)
            if (_tryParse(d.data()) case final r?) r
        ];
        // Notify on newly shared ratings (not the initial load).
        if (!firstSnapshot) {
          final friend = _friendByUid[uid];
          if (friend != null) _notifyNewRatings(friend, snap);
        }
        firstSnapshot = false;
        _rebuildCaches();
      }, onError: (e) =>
          debugPrint('friend restaurants listen failed ($uid): $e'));
      _fetchCategories(uid);
    }
    _rebuildCaches();
  }

  static void _notifyNewRatings(
      Friend friend, QuerySnapshot<Map<String, dynamic>> snap) {
    // Which groups are selected in the notification filter?
    final selectedGroups = <List<String>>[];
    try {
      final raw = AppPrefs.notifFriendsFilter.value;
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        if (decoded['mode'] == 'groups') {
          final ids =
              (decoded['ids'] as List? ?? []).map((e) => e.toString());
          for (final id in ids) {
            final g = FriendGroupStore.byId(id);
            if (g != null) selectedGroups.add(g.usernames);
          }
        }
      }
    } catch (_) {}
    if (!NotificationService.friendPassesFilter(
        friend.username, selectedGroups)) {
      return;
    }
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added &&
          change.type != DocumentChangeType.modified) {
        continue;
      }
      final r = _tryParse(change.doc.data() ?? {});
      if (r == null || r.visits.isEmpty) continue;
      NotificationService.show(
        '${friend.name} rated ${r.name} ⭐',
        '${r.overallRating.toStringAsFixed(1)}/10 — check it out on YUMS!',
        id: change.doc.id.hashCode & 0x7fffffff,
      );
      break; // don't spam on bulk syncs
    }
  }

  static Restaurant? _tryParse(Map<String, dynamic> data) {
    try {
      return Restaurant.fromMap(data);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _fetchCategories(String uid) async {
    final friend = _friendByUid[uid];
    if (friend == null) return;
    try {
      final snap = await _db
          .collection('users').doc(uid).collection('categories').get();
      final cats = [
        for (final d in snap.docs)
          AppCategory(
            key: d.data()['key'] as String? ?? d.id,
            label: d.data()['label'] as String? ?? 'Category',
            iconIndex: (d.data()['iconIndex'] as num?)?.toInt() ?? 0,
          )
      ];
      SocialService.cloudCategories[friend.name] = cats;
      // Same category, same name? Link them automatically — no manual
      // "your Chinese = my Chinese" step.
      await CategoryMapping.autoLink(cats, CategoryStore.all.value);
    } catch (_) {
      // Friend keeps categories private — rules deny the read.
      SocialService.cloudCategories[friend.name] = const [];
    }
  }

  static void _rebuildCaches() {
    final feed = <FeedItem>[];
    final places = <MapPlace>[];
    final at = <String, List<FriendVisit>>{};
    final favorites = <String, List<String>>{};
    final reviews = <String, List<FeedItem>>{};

    _friendRestaurants.forEach((uid, restaurants) {
      final friend = _friendByUid[uid];
      if (friend == null) return;
      for (final r in restaurants) {
        final sharedVisits =
            r.visits.where((v) => v.visibility == 'friends').toList();
        if (sharedVisits.isEmpty) continue;
        sharedVisits.sort((a, b) => b.date.compareTo(a.date));
        final latest = sharedVisits.first;
        final rating =
            sharedVisits.fold<double>(0, (s, v) => s + v.overall) /
                sharedVisits.length;
        final location = r.locationDescriptor ?? r.address;

        final item = FeedItem(
          friendName: friend.name,
          restaurantName: r.name,
          location: location,
          rating: rating,
          when: latest.date,
          note: latest.notes,
        );
        feed.add(item);
        (reviews[friend.name] ??= []).add(item);

        final visit = FriendVisit(friend, rating, latest.notes);
        (at[r.name.trim().toLowerCase()] ??= []).add(visit);

        if (r.isFavorite) (favorites[friend.name] ??= []).add(r.name);

        if (r.lat != null && r.lng != null) {
          places.add(MapPlace(
            id: '$uid-${r.id}',
            name: r.name,
            address: r.address,
            lat: r.lat!,
            lng: r.lng!,
            categoryKeys: r.categoryKeys,
            visits: [visit],
          ));
        }
      }
    });

    SocialService.cloudFeed = feed;
    SocialService.cloudPlaces = places;
    SocialService.cloudAt = at;
    SocialService.cloudFavorites = favorites;
    SocialService.cloudReviews = reviews;
    // Nudge listeners so open screens rebuild.
    SocialService.friends.value = List.of(SocialService.friends.value);
  }

  // ---- Actions ----

  static Future<bool> _sendRequest(String username) async {
    final me = AuthService.user.value;
    final uid = _uid;
    if (me == null || uid == null) return false;
    final lookup =
        await _db.collection('usernames').doc(username.toLowerCase()).get();
    if (!lookup.exists) return false;
    final targetUid = lookup.data()!['uid'] as String;
    if (targetUid == uid) return false;
    await _db
        .collection('users').doc(targetUid)
        .collection('friendRequests').doc(uid)
        .set({
      'name': me.name,
      'username': me.username,
      'sentAt': FieldValue.serverTimestamp(),
    });
    return true;
  }

  static Future<String?> _uidForUsername(String username) async {
    final snap =
        await _db.collection('usernames').doc(username.toLowerCase()).get();
    return snap.exists ? snap.data()!['uid'] as String : null;
  }

  static Future<void> _accept(Friend f) async {
    final uid = _uid;
    final me = AuthService.user.value;
    if (uid == null || me == null) return;
    final fromUid = await _uidForUsername(f.username);
    if (fromUid == null) return;
    final batch = _db.batch();
    batch.set(
        _db.collection('users').doc(uid).collection('friends').doc(fromUid),
        {'name': f.name, 'username': f.username,
         'since': FieldValue.serverTimestamp()});
    batch.set(
        _db.collection('users').doc(fromUid).collection('friends').doc(uid),
        {'name': me.name, 'username': me.username,
         'since': FieldValue.serverTimestamp()});
    batch.delete(_db.collection('users').doc(uid)
        .collection('friendRequests').doc(fromUid));
    await batch.commit();
  }

  static Future<void> _decline(Friend f) async {
    final uid = _uid;
    if (uid == null) return;
    final fromUid = await _uidForUsername(f.username);
    if (fromUid == null) return;
    await _db.collection('users').doc(uid)
        .collection('friendRequests').doc(fromUid).delete();
  }

  /// Writes a plan invite into a friend's inbox (they get notified live).
  static Future<void> _sendPlanInvite(String username, Plan plan) async {
    final uid = _uid;
    final me = AuthService.user.value;
    if (uid == null || me == null) return;
    final targetUid = await _uidForUsername(username);
    if (targetUid == null) return;
    try {
      await _db
          .collection('users').doc(targetUid)
          .collection('planInvites').doc('${plan.id}_$uid')
          .set({
        'fromUid': uid,
        'fromName': me.name,
        'fromUsername': me.username,
        'restaurantName': plan.restaurantName,
        'address': plan.address,
        'when': plan.when.millisecondsSinceEpoch,
        'sentAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> _removeFriend(Friend f) async {
    final uid = _uid;
    if (uid == null) return;
    final otherUid = await _uidForUsername(f.username);
    if (otherUid == null) return;
    final batch = _db.batch();
    batch.delete(
        _db.collection('users').doc(uid).collection('friends').doc(otherUid));
    batch.delete(
        _db.collection('users').doc(otherUid).collection('friends').doc(uid));
    await batch.commit();
  }
}

/// Pushes your local data (restaurants, categories, prefs) to Firestore.
class _CloudSync {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static FirebaseStorage get _storage => FirebaseStorage.instance;
  static String? _uid;

  static void start(String uid) {
    _uid = uid;
    RestaurantDatabase.onUpsert = (r) => _pushRestaurant(r);
    RestaurantDatabase.onDelete = (id) => _deleteRestaurant(id);
    CategoryStore.onChanged = _pushCategories;
    AppPrefs.categoriesViewable.addListener(_pushPrefs);
    AppPrefs.defaultVisibility.addListener(_pushPrefs);
    _initialPush();
  }

  static void stop() {
    _uid = null;
    RestaurantDatabase.onUpsert = null;
    RestaurantDatabase.onDelete = null;
    CategoryStore.onChanged = null;
    AppPrefs.categoriesViewable.removeListener(_pushPrefs);
    AppPrefs.defaultVisibility.removeListener(_pushPrefs);
  }

  static Future<void> _initialPush() async {
    try {
      final all = await RestaurantDatabase.instance.getAll();
      for (final r in all) {
        await _pushRestaurant(r);
      }
      await _pushCategories();
      await _pushPrefs();
    } catch (_) {
      // Offline — Firestore's queue will catch writes when back online.
    }
  }

  static Future<void> _pushRestaurant(Restaurant r) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final map = r.toMap();
      map['visibility'] = r.visits.any((v) => v.visibility == 'friends')
          ? 'friends'
          : 'private';
      // Upload the cover once so friends can see it. Strictly best-effort:
      // if Storage isn't set up, the restaurant must still sync — a missing
      // photo is cosmetic, a missing doc means friends see nothing at all.
      final cover = r.customPhotoPath;
      if (cover != null && cover.isNotEmpty && File(cover).existsSync()) {
        try {
          final ref = _storage.ref('users/$uid/photos/${r.id}-cover.jpg');
          try {
            await ref.getMetadata(); // already uploaded
          } catch (_) {
            await ref.putFile(File(cover));
          }
          map['photoUrl'] = await ref.getDownloadURL();
        } catch (e) {
          debugPrint('cover upload skipped (${r.name}): $e');
        }
      }
      map.remove('customPhotoPath'); // local path is meaningless to others
      await _db.collection('users').doc(uid)
          .collection('restaurants').doc(r.id).set(map);
    } catch (e) {
      debugPrint('restaurant push failed (${r.name}): $e');
    }
  }

  static Future<void> _deleteRestaurant(String id) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid)
          .collection('restaurants').doc(id).delete();
    } catch (_) {}
  }

  static Future<void> _pushCategories() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final batch = _db.batch();
      for (final c in CategoryStore.all.value) {
        batch.set(
            _db.collection('users').doc(uid).collection('categories').doc(c.key),
            {'key': c.key, 'label': c.label, 'iconIndex': c.iconIndex});
      }
      await batch.commit();
    } catch (_) {}
  }

  static Future<void> _pushPrefs() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'categoriesViewable': AppPrefs.categoriesViewable.value,
        'defaultVisibility': AppPrefs.defaultVisibility.value,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
