# 🍽️ Restaurant Tracker

A sleek, fast restaurant rating app. Built with **Flutter** (Android first,
iOS-ready). Rate places in seconds with satisfying haptic sliders, auto-fetched
Google Maps photos, and powerful sorting/filtering.

> **Status:** Phase 1 (core app) is complete and runs locally/offline.
> Phase 2 (Firebase sign-in + friends/groups/public sharing) is planned next —
> the data model is already built to support it.

---

## ✨ Features (Phase 1)

- **Light & dark mode** — follows the system, with a manual toggle (remembered).
- **List of restaurants** — Google Maps photo on the left, name in big text,
  address below, **averaged** overall score on the right, plus visit-count &
  average-price pills.
- **Search** your restaurants by name/address.
- **Sort** by newest, rating (high/low), price (low/high), name (A–Z / Z–A),
  and **distance** (nearest/farthest, uses your location).
- **Filter** by category: Kosher (Dairy / Meat), Fast Food, Fancy, Mexican,
  Chinese, Vegan, Healthy.
- **Name-first add flow** — type the restaurant name, pick the matching place
  to confirm/lock in the address + auto-fetched photo (swap for a custom one).
- **Visits** — each restaurant holds many visits; the headline Food /
  Atmosphere / Price / Overall are **averaged across all visits**. Quick-add a
  visit by long-pressing a card or tapping **Add visit** on the detail page.
- **Per-visit rating form:**
  - **3 haptic sliders** — Food (1–10, heavy tick), Atmosphere (1–10, heavy
    tick), Price (1–500 quick-pick, light tick) + an **unlocked exact-amount**
    box for any number.
  - **"What did you get?"** — add items, each with an optional price and an
    optional 1–10 rating.
  - Photos + notes.
- **Local, offline storage** (SQLite). No account required.

---

## 🚀 Getting it running

### 1. Install Flutter
Follow https://docs.flutter.dev/get-started/install (you'll want Android Studio
+ an Android device/emulator). Verify with:
```bash
flutter doctor
```

### 2. Generate the native Android/iOS shells
This repo contains the Dart source + `pubspec.yaml`. Generate the platform
folders once, in the project root:
```bash
flutter create . --org com.yourname --platforms=android,ios
```
This adds `android/` and `ios/` **without** touching the existing `lib/` or
`pubspec.yaml`.

### 3. Install dependencies
```bash
flutter pub get
```

### 4. Add the platform permissions
See **[SETUP.md](SETUP.md)** for the exact lines to add to
`AndroidManifest.xml` (internet, location, photos) and iOS `Info.plist`.

### 5. Run with your Google Maps API key
The key is passed at build time (never committed):
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```
> No key yet? The app still runs — you just type the address manually and pick
> your own photo. See SETUP.md for how to get a key.

---

## 🗂️ Project structure

```
lib/
  config.dart                  # API key (via --dart-define)
  main.dart
  theme/app_theme.dart         # sleek modern theme
  models/
    restaurant.dart            # data model (sharing-ready)
    category.dart              # the fixed category list
    sort_option.dart
  data/
    restaurant_database.dart   # local SQLite store
  services/
    places_service.dart        # Google Places REST (autocomplete/details/photo)
    location_service.dart      # current location + distance
  widgets/
    restaurant_card.dart       # list row
    haptic_slider.dart         # slider with per-step haptics
    category_selector.dart
    sort_sheet.dart
    place_autocomplete_field.dart
  screens/
    home_screen.dart
    add_rating_screen.dart
    restaurant_detail_screen.dart
```

---

## 🔜 Phase 2 — Sharing (Firebase)

Everything code-side is prepared: security rules, the Firestore schema, and
ready-to-drop auth/friends/sync services live in [`firebase_setup/`](firebase_setup/).
The only remaining steps need the owner's Google account — follow
**[FIREBASE_SETUP.md](FIREBASE_SETUP.md)** (~15 minutes).
