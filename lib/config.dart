/// App-wide configuration.
///
/// The Google Maps / Places API key is read at build time from a
/// `--dart-define`, so it never has to be committed to git.
///
/// Run the app like this:
///   flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY_HERE
///
/// (or add it to a launch config in your IDE).
class AppConfig {
  static const String googleMapsApiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  /// Whether Google Places features (address autocomplete + auto photos)
  /// are available. If no key is supplied the app still works — you just
  /// type the address manually and add your own photo.
  static bool get hasPlacesKey => googleMapsApiKey.isNotEmpty;

  /// The Firebase project's *Web client ID* (a public identifier), used by
  /// native Google sign-in to mint Firebase-compatible tokens.
  /// Found in Firebase console → Authentication → Sign-in method → Google →
  /// "Web SDK configuration". Empty = fall back to the browser redirect flow.
  static const String googleWebClientId =
      '16020027451-jdh3n8fra7ev1m9h5i6teu3mcnujsr3h.apps.googleusercontent.com';
}
