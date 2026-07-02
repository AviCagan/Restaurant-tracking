# Phase 2 — Firebase Setup (do this when you're back)

Everything code-side is prepared. These are the only steps that need **your**
Google account. Total time: ~15 minutes.

## 1. Create the Firebase project (5 min)
1. Go to https://console.firebase.google.com/ → **Add project**.
2. Name it `restaurant-tracker` → you can disable Analytics → **Create**.
3. In the project, enable these products (left sidebar → Build):
   - **Authentication** → Get started → Sign-in method → enable **Google**.
   - **Firestore Database** → Create database → *production mode* → nearest region.
   - **Storage** → Get started (this may ask you to enable the Blaze
     pay-as-you-go plan; it has a free monthly allowance, set a budget alert).

## 2. Connect the app (5 min, on your PC)
In a terminal at the project root:
```bash
dart pub global activate flutterfire_cli
npm install -g firebase-tools     # if you don't have the Firebase CLI
firebase login
flutterfire configure
```
Pick your `restaurant-tracker` project and the **android** platform.
This generates `lib/firebase_options.dart` and `android/app/google-services.json`
automatically (both are already git-ignored).

**Google sign-in also needs your app's SHA-1:**
```bash
cd android && ./gradlew signingReport
```
Copy the `SHA1` from the `debug` variant → Firebase console → Project settings
→ Your Android app → **Add fingerprint**. Then re-download nothing —
`flutterfire configure` again or just save.

## 3. Add the packages
In `pubspec.yaml` under `dependencies:` add:
```yaml
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.0
  firebase_storage: ^12.3.7
  google_sign_in: ^6.2.2
```
Then `flutter pub get`.

## 4. Paste the security rules
Firebase console → Firestore → **Rules** tab → replace with the contents of
[`firebase_setup/firestore.rules`](firebase_setup/firestore.rules) → Publish.

## 5. Drop in the prepared code
Copy `firebase_setup/firebase_services.dart` into `lib/data/` and follow the
`WIRE-UP` comments at the top of that file (it lists the 4 small edits:
initialize Firebase in `main()`, swap the demo sign-in for
`FirebaseAuthService.signInWithGoogle()`, and start the sync services after
sign-in). The Firestore schema it implements is documented in
[`firebase_setup/SCHEMA.md`](firebase_setup/SCHEMA.md).

## 6. Run it
```bash
flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
```
Sign in with Google on two phones with two accounts, add each other by
username, and ratings marked "Friends" will appear in each other's feed & map.
