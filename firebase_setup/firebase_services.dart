// READY-TO-DROP Firebase services for Phase 2.
//
// After running `flutterfire configure` and adding the packages listed in
// FIREBASE_SETUP.md, copy this file to lib/data/firebase_services.dart.
//
// WIRE-UP (4 edits):
//  1. main.dart:  before runApp ->
//       await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//  2. sign_in_prompt.dart / settings_screen.dart: replace
//       AuthService.signInDemo()  with  FirebaseAuthService.signInWithGoogle()
//  3. After sign-in succeeds call:  SyncService.start();
//  4. social_screen/map/feed: replace SocialService mock reads with
//       SyncService.friendRestaurants / FriendService streams (same shapes).

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/restaurant.dart';
import '../models/user_profile.dart';
import 'auth_service.dart';
import 'restaurant_database.dart';

class FirebaseAuthService {
  static final _auth = fb.FirebaseAuth.instance;
  static final _db = FirebaseFirestore.instance;

  /// Google sign-in -> creates/loads the Firestore profile and mirrors it
  /// into the existing local AuthService so every screen keeps working.
  static Future<UserProfile?> signInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final cred = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final user = (await _auth.signInWithCredential(cred)).user!;

    final doc = _db.collection('users').doc(user.uid);
    final snap = await doc.get();
    UserProfile profile;
    if (snap.exists) {
      profile = UserProfile.fromJson(snap.data()!..['id'] = user.uid);
    } else {
      final username = await _claimUsername(user);
      profile = UserProfile(
          id: user.uid, name: user.displayName ?? 'You', username: username);
      await doc.set({
        ...profile.toJson(),
        'categoriesViewable': true,
        'defaultVisibility': 'friends',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await AuthService.updateProfile(profile);
    return profile;
  }

  static Future<String> _claimUsername(fb.User user) async {
    var base = (user.email ?? 'user').split('@').first.toLowerCase();
    base = base.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    var candidate = base;
    var i = 0;
    while (true) {
      final ref = _db.collection('usernames').doc(candidate);
      try {
        await _db.runTransaction((tx) async {
          final s = await tx.get(ref);
          if (s.exists) throw Exception('taken');
          tx.set(ref, {'uid': user.uid});
        });
        return candidate;
      } catch (_) {
        i++;
        candidate = '$base$i';
      }
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
    await AuthService.signOut();
  }
}

class FriendService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => fb.FirebaseAuth.instance.currentUser!.uid;

  static Future<bool> sendRequest(String username) async {
    final lookup =
        await _db.collection('usernames').doc(username.toLowerCase()).get();
    if (!lookup.exists) return false;
    final targetUid = lookup.data()!['uid'] as String;
    final me = AuthService.user.value!;
    await _db
        .collection('users').doc(targetUid)
        .collection('friendRequests').doc(_uid)
        .set({'name': me.name, 'username': me.username,
              'sentAt': FieldValue.serverTimestamp()});
    return true;
  }

  static Future<void> accept(String fromUid, String name, String username) async {
    final me = AuthService.user.value!;
    final batch = _db.batch();
    batch.set(
        _db.collection('users').doc(_uid).collection('friends').doc(fromUid),
        {'name': name, 'username': username,
         'since': FieldValue.serverTimestamp()});
    batch.set(
        _db.collection('users').doc(fromUid).collection('friends').doc(_uid),
        {'name': me.name, 'username': me.username,
         'since': FieldValue.serverTimestamp()});
    batch.delete(_db.collection('users').doc(_uid)
        .collection('friendRequests').doc(fromUid));
    await batch.commit();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> friends() =>
      _db.collection('users').doc(_uid).collection('friends').snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> requests() =>
      _db.collection('users').doc(_uid).collection('friendRequests').snapshots();
}

class SyncService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;
  static String get _uid => fb.FirebaseAuth.instance.currentUser!.uid;

  /// Push all local restaurants up (photos to Storage), then listen for
  /// friends' shared restaurants. Call once after sign-in.
  static Future<void> start() async {
    await pushAll();
  }

  static Future<void> pushAll() async {
    final all = await RestaurantDatabase.instance.getAll();
    for (final r in all) {
      await pushOne(r);
    }
  }

  static Future<void> pushOne(Restaurant r) async {
    final map = r.toMap();
    // Upload the local cover once and store the URL.
    if (r.customPhotoPath != null && r.customPhotoPath!.isNotEmpty) {
      final ref = _storage.ref('users/$_uid/photos/${r.id}-cover.jpg');
      // Skip re-upload if it already exists (cheap metadata check).
      try {
        await ref.getMetadata();
      } catch (_) {
        await ref.putFile(File(r.customPhotoPath!));
      }
      map['photoUrl'] = await ref.getDownloadURL();
    }
    map['visibility'] =
        r.visits.any((v) => v.visibility == 'friends') ? 'friends' : 'private';
    await _db.collection('users').doc(_uid)
        .collection('restaurants').doc(r.id).set(map);
  }

  /// Friends' restaurants shared with friends (rules enforce visibility).
  static Stream<QuerySnapshot<Map<String, dynamic>>> friendRestaurants(
          String friendUid) =>
      _db.collection('users').doc(friendUid)
          .collection('restaurants')
          .where('visibility', isEqualTo: 'friends')
          .snapshots();
}
