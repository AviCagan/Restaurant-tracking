# 🍽️ Restaurant Tracker

A sleek, fast restaurant rating app. Built with **Flutter** (Android first,
iOS-ready). Rate places in seconds with satisfying haptic sliders, auto-fetched
Google Maps photos, and powerful sorting/filtering.

> **Status:** Phase 1 (core app) is complete and runs locally/offline.
> Phase 2 (Firebase sign-in + friends/groups/public sharing) is planned next —
> the data model is already built to support it.

---

## ✨ Features (Phase 1)

- **List of ratings** — Google Maps photo on the left, name in big text,
  address below, overall score on the right.
- **Sort** by newest, rating (high/low), price (low/high), name (A–Z / Z–A),
  and **distance** (nearest/farthest, uses your location).
- **Filter** by category: Kosher (Dairy / Meat), Fast Food, Fancy, Mexican,
  Chinese, Vegan, Healthy.
- **Add rating** via a clean form:
  - Restaurant name
  - **Google Places address autocomplete** → auto-fills the photo (swappable
    for a custom photo)
  - **3 haptic sliders:**
    - **Food** (1–10) — heavy haptic tick on each number
    - **Atmosphere** (1–10) — heavy haptic tick (service, style, seating…)
    - **Price** (1–500, steps of 10) — light haptic tick + an exact-amount box
  - Photo upload
  - Notes
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

Planned: Google sign-in, cloud sync, and sharing via **friends/follow**,
**groups**, and a **public feed**. The `Restaurant` model already carries
`ownerId`, `visibility`, and `groupIds` so this layers on without a data
migration. Setup will use `flutterfire configure`.
