# Setup details

## Getting your Google Maps / Places API key

1. Go to https://console.cloud.google.com/ and sign in.
2. Create a project (top bar → project dropdown → **New Project**).
3. **APIs & Services → Library** → enable:
   - **Places API (New)** — required (the app uses the new `places.googleapis.com/v1` API)
   - **Maps SDK for Android** (only needed if we add a real map later)
4. **APIs & Services → Credentials → Create Credentials → API key** → copy it.
5. **Billing**: link a billing account when prompted. There's a large free
   monthly tier; personal use is effectively free. Set a budget alert to be safe.
6. (Recommended) Restrict the key to the Places API.

Run the app with the key:
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

To avoid typing it every time, add it to your IDE launch config, or create a
`run.sh` (already git-ignored via the secrets rules) :
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
```

---

## Android permissions

After `flutter create .`, open `android/app/src/main/AndroidManifest.xml` and add
these **inside the `<manifest>` tag, above `<application>`**:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<!-- Android 13+ photo picker -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
<!-- Older Android -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32"/>
```

In `android/app/build.gradle`, make sure `minSdkVersion` is at least **23**
(required by geolocator / modern plugins):
```gradle
defaultConfig {
    minSdkVersion 23
}
```

### Food Map — Maps SDK key (required for the map to render)

The Food Map uses the **Maps SDK for Android** (already enabled on your key).
The map renders blank until you add the key to the manifest. Inside the
`<application>` tag in `android/app/src/main/AndroidManifest.xml` add:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_KEY_HERE"/>
```

(This is the same Google key. Unlike the Places features it can't be passed
via `--dart-define`, so it does live in the manifest — keep the manifest out
of public repos or restrict the key to your app's package + SHA-1.)

For iOS later, add the key in `ios/Runner/AppDelegate.swift` via
`GMSServices.provideAPIKey("YOUR_KEY")`.

---

## iOS permissions (for the later port)

In `ios/Runner/Info.plist` add:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to sort your restaurants by distance.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to attach photos to your ratings.</string>
<key>NSCameraUsageDescription</key>
<string>Used to take photos of restaurants.</string>
```

---

## Troubleshooting

- **Autocomplete returns nothing / photos don't load** → the API key is missing,
  the Places API isn't enabled, or billing isn't linked. Check the run console
  for `Places autocomplete error: ...`.
- **Distance sort does nothing** → grant location permission when prompted, and
  make sure the restaurant was added via Places (so it has coordinates).
- **Fonts look like the default** → `google_fonts` downloads on first run; needs
  internet the first time.
