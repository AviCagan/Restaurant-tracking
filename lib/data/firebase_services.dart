import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart'
    show ValueNotifier, debugPrint, kIsWeb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';

import '../config.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../models/user_profile.dart';
import '../services/email_service.dart';
import '../services/notification_service.dart';
import 'app_prefs.dart';
import 'auth_service.dart';
import 'block_store.dart';
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
        // A failed profile read must NOT strand the app in a half-signed-in
        // state with the cloud layer off — retry with backoff.
        for (var attempt = 0; attempt < 3; attempt++) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users').doc(user.uid).get();
            if (snap.exists &&
                (snap.data()?.containsKey('username') ?? false)) {
              await FirebaseAuthService.loadProfile(user);
              startServices(user.uid);
            } else {
              needsSetup.value = true; // brand new — run the setup screen
            }
            return;
          } catch (e) {
            debugPrint('cloud boot attempt ${attempt + 1} failed: $e');
            await Future.delayed(Duration(seconds: 2 << attempt));
          }
        }
        debugPrint('cloud boot gave up — check network and Firestore rules');
      } else {
        needsSetup.value = false;
        _CloudSocial.stop();
        _CloudSync.stop();
        // Firebase says signed out. If a profile is still cached locally
        // (e.g. the account was deleted or the session was revoked), clear
        // it — otherwise the app looks signed in while every social
        // feature silently runs in offline mode.
        if (AuthService.user.value != null && !AppPrefs.localMode.value) {
          debugPrint('clearing stale local profile (no Firebase session)');
          await AuthService.signOut();
        }
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
    if (kIsWeb) {
      // Browsers use Firebase's own popup flow — no plugin config needed.
      final cred = await fb.FirebaseAuth.instance
          .signInWithPopup(fb.GoogleAuthProvider());
      user = cred.user;
    } else if (AppConfig.googleWebClientId.isNotEmpty) {
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
      'email': user.email ?? '',
      'emailNotifs': AppPrefs.emailNotifs.value,
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
    // Backfill the email for accounts created before email notifications.
    if ((d['email'] as String? ?? '').isEmpty &&
        (user.email ?? '').isNotEmpty) {
      _db.collection('users').doc(user.uid).set(
          {'email': user.email}, SetOptions(merge: true)).catchError((_) {});
    }
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
    if (kIsWeb) {
      try {
        await user.reauthenticateWithPopup(fb.GoogleAuthProvider());
      } catch (e) {
        debugPrint('reauth for deletion failed: $e');
        return 'Couldn\'t verify it\'s you — check your connection and '
            'try again.';
      }
    } else if (AppConfig.googleWebClientId.isNotEmpty) {
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
  static StreamSubscription? _repliesSub;
  static final Map<String, StreamSubscription> _restaurantSubs = {};
  static final Map<String, StreamSubscription> _profileSubs = {};
  static final Map<String, List<Restaurant>> _friendRestaurants = {};
  static final Map<String, Friend> _friendByUid = {};

  /// Friend uids whose acceptance *I* triggered — don't notify myself.
  static final Set<String> _selfAccepted = {};

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
    SocialService.cloudRespondInvite = _respondInvite;
    SocialService.cloudCancelPlan = _cancelPlan;
    SocialService.cloudSendReply = _sendReply;
    SocialService.cloudRefreshCategories = _refreshAllCategories;

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
        // The sender cancelled the plan: pull it from my list (if I had
        // joined), tell me, and consume the marker.
        if (data['cancelled'] == true) {
          final planId =
              data['planId'] as String? ?? d.id.split('_').first;
          final joined = PlanStore.byId(planId);
          if (joined != null) {
            PlanStore.delete(planId);
            final baseId = planId.hashCode & 0x7ffffff;
            NotificationService.cancel(baseId);
            NotificationService.cancel(baseId + 1);
            if (AppPrefs.notifPlans.value) {
              NotificationService.show(
                '${data['fromName'] ?? 'A friend'} cancelled the plan 😢',
                '${data['restaurantName'] ?? 'The restaurant'} · '
                    '${DateFormat.MMMEd().add_jm().format(when)} is off.',
                id: d.id.hashCode & 0x7fffffff,
              );
            }
          }
          d.reference.delete().catchError((_) {});
          continue;
        }
        if (when.isBefore(
            DateTime.now().subtract(const Duration(days: 1)))) {
          continue; // stale
        }
        invites.add(PlanInvite(
          id: d.id,
          // Older invites carry the plan id only in the doc id
          // ('<planId>_<fromUid>').
          planId: data['planId'] as String? ?? d.id.split('_').first,
          fromUid: data['fromUid'] as String? ?? '',
          fromName: data['fromName'] as String? ?? 'A friend',
          restaurantName: data['restaurantName'] as String? ?? 'a restaurant',
          address: data['address'] as String? ?? '',
          when: when,
        ));
      }
      invites.sort((a, b) => a.when.compareTo(b.when));
      SocialService.invites.value = invites;
      if (!invitesFirst && AppPrefs.notifPlans.value) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() ?? {};
          if (data['cancelled'] == true) continue;
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

    // RSVPs to my plans land here; apply to the local plan and consume.
    _repliesSub = _db
        .collection('users').doc(uid).collection('planReplies')
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data() ?? {};
        final planId = data['planId'] as String? ?? '';
        final username = data['username'] as String? ?? '';
        final name = data['name'] as String? ?? username;
        final going = data['going'] as bool? ?? false;
        final plan = PlanStore.byId(planId);
        await PlanStore.applyReply(planId, username, going);
        if (plan != null && AppPrefs.notifPlans.value) {
          NotificationService.show(
            going ? '$name is in! 🙌' : '$name can\'t make it 😢',
            '${plan.restaurantName} · '
                '${DateFormat.MMMEd().add_jm().format(plan.when)}',
            id: change.doc.id.hashCode & 0x7fffffff,
          );
        }
        try {
          await change.doc.reference.delete();
        } catch (_) {}
      }
    }, onError: (e) => debugPrint('plan replies listen failed: $e'));

    var friendsFirst = true;
    _friendsSub = _db
        .collection('users').doc(uid).collection('friends')
        .snapshots()
        .listen((snap) {
      _friendByUid.clear();
      for (final d in snap.docs) {
        final username = d.data()['username'] as String? ?? d.id;
        if (BlockStore.isBlocked(username)) continue; // stay hidden
        _friendByUid[d.id] = Friend(
            d.data()['name'] as String? ?? 'Friend', username);
      }
      SocialService.friends.value = _friendByUid.values.toList();
      // A new doc here that *I* didn't create means someone accepted my
      // friend request.
      if (!friendsFirst) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          if (_selfAccepted.remove(change.doc.id)) continue;
          if (!AppPrefs.notifSocial.value) continue;
          final data = change.doc.data() ?? {};
          NotificationService.show(
            '${data['name'] ?? 'A friend'} accepted your request! 🎉',
            'You\'re now friends on YUMS — check out their eats.',
            id: change.doc.id.hashCode & 0x7fffffff,
          );
        }
      }
      friendsFirst = false;
      _syncRestaurantListeners();
    });

    var requestsFirst = true;
    _requestsSub = _db
        .collection('users').doc(uid).collection('friendRequests')
        .snapshots()
        .listen((snap) {
      // Silently drop requests from people I've blocked.
      for (final d in snap.docs) {
        final username = d.data()['username'] as String? ?? d.id;
        if (BlockStore.isBlocked(username)) {
          d.reference.delete().catchError((_) {});
        }
      }
      SocialService.requests.value = [
        for (final d in snap.docs)
          if (!BlockStore.isBlocked(d.data()['username'] as String? ?? d.id))
            Friend(d.data()['name'] as String? ?? 'Someone',
                d.data()['username'] as String? ?? d.id)
      ];
      // Pop a notification for requests that arrive while signed in (not
      // for ones already waiting when the listener starts).
      if (!requestsFirst && AppPrefs.notifSocial.value) {
        for (final change in snap.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data() ?? {};
          if (BlockStore.isBlocked(data['username'] as String? ?? '')) {
            continue;
          }
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
    _repliesSub?.cancel();
    for (final s in _restaurantSubs.values) {
      s.cancel();
    }
    for (final s in _profileSubs.values) {
      s.cancel();
    }
    _restaurantSubs.clear();
    _profileSubs.clear();
    _friendRestaurants.clear();
    _friendByUid.clear();
    _selfAccepted.clear();
    _uid = null;
  }

  static void _syncRestaurantListeners() {
    // Drop listeners for removed friends.
    for (final uid in _restaurantSubs.keys.toList()) {
      if (!_friendByUid.containsKey(uid)) {
        _restaurantSubs.remove(uid)?.cancel();
        _profileSubs.remove(uid)?.cancel();
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

      // Live categories: read the friend's profile doc (any signed-in user
      // may read it — no special rules) and update whenever it changes.
      _profileSubs[uid] = _db
          .collection('users').doc(uid)
          .snapshots()
          .listen((doc) => _applyFriendCategories(uid, doc.data()),
              onError: (e) =>
                  debugPrint('friend profile listen failed ($uid): $e'));
    }
    _rebuildCaches();
  }

  /// Parse a friend's categories array off their profile doc, cache it, and
  /// auto-link same-named categories to mine.
  static void _applyFriendCategories(
      String uid, Map<String, dynamic>? data) {
    final friend = _friendByUid[uid];
    if (friend == null) return;
    final cats = <AppCategory>[
      for (final c in (data?['categories'] as List? ?? []))
        if (c is Map && (c['key'] as String? ?? '').isNotEmpty)
          AppCategory(
            key: c['key'] as String,
            label: c['label'] as String? ?? 'Category',
            iconIndex: (c['iconIndex'] as num?)?.toInt() ?? 0,
          )
    ];
    SocialService.cloudCategories[friend.name] = cats;
    CategoryMapping.autoLink(cats, CategoryStore.all.value);
    debugPrint('categories for ${friend.name}: ${cats.length} live, '
        '${CategoryMapping.map.value.length} total links');
    // Nudge open screens (compare/map) to rebuild.
    SocialService.friends.value = List.of(SocialService.friends.value);
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
          price: latest.price,
        );
        feed.add(item);
        (reviews[friend.name] ??= []).add(item);

        final visit =
            FriendVisit(friend, rating, latest.notes, price: latest.price);
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
    _emailUser(
        targetUid,
        'New friend request on YUMS 👋',
        '${me.name} (@${me.username}) wants to be friends on YUMS! '
            'Open the app to accept.');
    return true;
  }

  static Future<String?> _uidForUsername(String username) async {
    final snap =
        await _db.collection('usernames').doc(username.toLowerCase()).get();
    return snap.exists ? snap.data()!['uid'] as String : null;
  }

  /// Best-effort notification email to [uid], respecting their
  /// emailNotifs preference. Never throws.
  static Future<void> _emailUser(
      String uid, String subject, String message) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final d = doc.data() ?? {};
      if (d['emailNotifs'] == false) return;
      await EmailService.send(
        toEmail: d['email'] as String? ?? '',
        toName: d['name'] as String? ?? 'foodie',
        subject: subject,
        message: message,
      );
    } catch (e) {
      debugPrint('email skipped: $e');
    }
  }

  static Future<void> _accept(Friend f) async {
    final uid = _uid;
    final me = AuthService.user.value;
    if (uid == null || me == null) return;
    final fromUid = await _uidForUsername(f.username);
    if (fromUid == null) return;
    _selfAccepted.add(fromUid); // I accepted — don't notify myself
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
    _emailUser(
        fromUid,
        '${me.name} accepted your friend request 🎉',
        'You\'re now friends on YUMS — open the app to check out '
            '${me.name.split(' ').first}\'s eats!');
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
        'planId': plan.id,
        'fromUid': uid,
        'fromName': me.name,
        'fromUsername': me.username,
        'restaurantName': plan.restaurantName,
        'address': plan.address,
        'when': plan.when.millisecondsSinceEpoch,
        'sentAt': FieldValue.serverTimestamp(),
      });
      _emailUser(
          targetUid,
          '${me.name} invited you to ${plan.restaurantName}! 🍽️',
          '${DateFormat.MMMMEEEEd().add_jm().format(plan.when)} at '
              '${plan.restaurantName}'
              '${plan.address.isEmpty ? '' : ' (${plan.address})'}. '
              'Open YUMS to say if you\'re in!');
    } catch (_) {}
  }

  /// RSVP straight to a plan owner's inbox (true = going).
  /// [restaurantName]/[when] are only used for the notification email.
  static Future<void> _sendReply(String ownerUid, String planId, bool going,
      String restaurantName, DateTime? when) async {
    final uid = _uid;
    final me = AuthService.user.value;
    if (uid == null || me == null) return;
    if (ownerUid.isEmpty || planId.isEmpty) return;
    try {
      await _db
          .collection('users').doc(ownerUid)
          .collection('planReplies').doc('${planId}_$uid')
          .set({
        'planId': planId,
        'fromUid': uid,
        'name': me.name,
        'username': me.username,
        'going': going,
        'sentAt': FieldValue.serverTimestamp(),
      });
      final where = restaurantName.isEmpty ? 'your plan' : restaurantName;
      _emailUser(
          ownerUid,
          going
              ? '${me.name} is in for $where! 🙌'
              : '${me.name} can\'t make $where 😢',
          when == null
              ? 'Open YUMS to see who\'s coming.'
              : '${DateFormat.MMMMEEEEd().add_jm().format(when)} — open YUMS '
                  'to see who\'s coming.');
    } catch (e) {
      debugPrint('plan reply failed: $e');
    }
  }

  /// RSVP to a plan invite: tell the sender, clear the invite, and (when
  /// going) keep the plan on my own list too.
  static Future<void> _respondInvite(PlanInvite invite, bool going) async {
    final uid = _uid;
    if (uid == null) return;
    await _sendReply(invite.fromUid, invite.planId, going,
        invite.restaurantName, invite.when);
    try {
      await _db.collection('users').doc(uid)
          .collection('planInvites').doc(invite.id).delete();
    } catch (_) {}
    if (going && PlanStore.byId(invite.planId) == null) {
      await PlanStore.create(
        id: invite.planId,
        restaurantId: '',
        restaurantName: invite.restaurantName,
        address: invite.address,
        when: invite.when,
        ownerUid: invite.fromUid,
        ownerName: invite.fromName,
      );
    }
  }

  /// Cancel my plan for everyone: overwrite each invite with a cancelled
  /// marker (accepted friends get it pulled from their list + notified;
  /// pending invites disappear).
  static Future<void> _cancelPlan(Plan plan) async {
    final uid = _uid;
    final me = AuthService.user.value;
    if (uid == null || me == null) return;
    for (final username in plan.friendUsernames) {
      try {
        final targetUid = await _uidForUsername(username);
        if (targetUid == null) continue;
        await _db
            .collection('users').doc(targetUid)
            .collection('planInvites').doc('${plan.id}_$uid')
            .set({
          'planId': plan.id,
          'fromUid': uid,
          'fromName': me.name,
          'fromUsername': me.username,
          'restaurantName': plan.restaurantName,
          'address': plan.address,
          'when': plan.when.millisecondsSinceEpoch,
          'cancelled': true,
          'sentAt': FieldValue.serverTimestamp(),
        });
        _emailUser(
            targetUid,
            '${plan.restaurantName} is cancelled 😢',
            '${me.name} called off the '
                '${DateFormat.MMMMEEEEd().add_jm().format(plan.when)} plan.');
      } catch (e) {
        debugPrint('cancel push to $username failed: $e');
      }
    }
  }

  /// Re-run auto-linking over the live-cached categories (called when the
  /// compare screen opens). The profile listeners keep the data itself
  /// fresh, so this just re-matches against my current categories.
  static Future<void> _refreshAllCategories() async {
    for (final cats in SocialService.cloudCategories.values) {
      await CategoryMapping.autoLink(cats, CategoryStore.all.value);
    }
  }

  static Future<void> _removeFriend(Friend f) async {
    final uid = _uid;
    if (uid == null) return;
    // Find their uid from the local cache and purge everything of theirs
    // synchronously — reviews, pins and feed entries vanish immediately,
    // before any network round-trip.
    String? otherUid;
    _friendByUid.forEach((k, v) {
      if (v.username == f.username) otherUid = k;
    });
    if (otherUid != null) {
      _restaurantSubs.remove(otherUid)?.cancel();
      _profileSubs.remove(otherUid)?.cancel();
      _friendRestaurants.remove(otherUid);
      _friendByUid.remove(otherUid);
      SocialService.cloudCategories.remove(f.name);
      SocialService.friends.value = _friendByUid.values.toList();
      _rebuildCaches();
    }
    otherUid ??= await _uidForUsername(f.username);
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
    CategoryStore.onChanged = () {
      _pushCategories();
      // My categories changed — re-check for name matches with friends'.
      for (final cats in SocialService.cloudCategories.values) {
        CategoryMapping.autoLink(cats, CategoryStore.all.value);
      }
    };
    AppPrefs.categoriesViewable.addListener(_pushPrefs);
    AppPrefs.defaultVisibility.addListener(_pushPrefs);
    AppPrefs.emailNotifs.addListener(_pushPrefs);
    _initialPush();
  }

  static void stop() {
    _uid = null;
    RestaurantDatabase.onUpsert = null;
    RestaurantDatabase.onDelete = null;
    CategoryStore.onChanged = null;
    AppPrefs.categoriesViewable.removeListener(_pushPrefs);
    AppPrefs.defaultVisibility.removeListener(_pushPrefs);
    AppPrefs.emailNotifs.removeListener(_pushPrefs);
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

  /// Categories live as a single array on the user's profile doc. Any
  /// signed-in friend can already read the profile doc, so this needs no
  /// special rules — it's the whole sync in one write. Respects the
  /// "let friends see my categories" toggle (empty when off).
  static Future<void> _pushCategories() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'categories': AppPrefs.categoriesViewable.value
            ? [
                for (final c in CategoryStore.all.value)
                  {'key': c.key, 'label': c.label, 'iconIndex': c.iconIndex}
              ]
            : [],
      }, SetOptions(merge: true));
      debugPrint('pushed ${CategoryStore.all.value.length} categories to '
          'profile doc');
    } catch (e) {
      debugPrint('categories push failed: $e');
    }
  }

  static Future<void> _pushPrefs() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'categoriesViewable': AppPrefs.categoriesViewable.value,
        'defaultVisibility': AppPrefs.defaultVisibility.value,
        'emailNotifs': AppPrefs.emailNotifs.value,
      }, SetOptions(merge: true));
    } catch (_) {}
    // The mirrored categories list follows the privacy toggle.
    await _pushCategories();
  }
}
