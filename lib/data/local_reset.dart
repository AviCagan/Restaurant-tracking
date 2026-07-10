import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_controller.dart';
import 'app_prefs.dart';
import 'catalog.dart';
import 'block_store.dart';
import 'category_store.dart';
import 'folder_store.dart';
import 'friend_group_store.dart';
import 'plan_store.dart';
import 'rating_bars_store.dart';
import 'restaurant_database.dart';

/// Factory-resets everything stored on this device. Used by account
/// deletion so "delete my account" really means delete EVERYTHING — the
/// next sign-in starts from a truly blank slate instead of silently
/// re-uploading the old local data to the fresh account.
class LocalReset {
  static Future<void> wipeAll() async {
    // 1. Nuke every persisted preference/store in one shot (folders,
    //    groups, plans, blocks, rating bars, digests, prefs, theme…).
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. The restaurant list lives outside prefs on mobile (SQLite).
    await RestaurantDatabase.instance.wipeAll();

    // 3. Reset the in-memory state the UI is watching — clearing storage
    //    alone leaves the old values live until a restart.
    CategoryStore.all.value = List.of(Catalog.starters);
    FolderStore.all.value = [];
    FriendGroupStore.all.value = [];
    PlanStore.all.value = [];
    BlockStore.blocked.value = {};
    RatingBarsStore.resetToDefaults();
    ThemeController.mode.value = ThemeMode.system;

    AppPrefs.defaultVisibility.value = 'friends';
    AppPrefs.categoriesViewable.value = true;
    AppPrefs.localMode.value = false;
    AppPrefs.hapticStrength.value = 3;
    AppPrefs.tourSeen.value = false;
    AppPrefs.notifArrival.value = true;
    AppPrefs.notifFriends.value = true;
    AppPrefs.notifFriendsFilter.value = '';
    AppPrefs.notifSocial.value = true;
    AppPrefs.notifPlans.value = true;
    AppPrefs.emailNotifs.value = true;
    AppPrefs.ratingEmailFreq.value = 'daily';
    AppPrefs.calendarProvider.value = '';
    AppPrefs.a2hsSeen.value = false;
    AppPrefs.wrappedLastShown.value = '';
    AppPrefs.themeAccent.value = 0;
  }
}
