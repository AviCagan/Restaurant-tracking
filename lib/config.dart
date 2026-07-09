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

  // ---- Email notifications (EmailJS) ----
  // EmailJS (emailjs.com) sends emails straight from the app on both web
  // and Android — no server needed. One-time setup:
  //   1. Create a free EmailJS account and connect the YUMS Gmail under
  //      "Email Services" (copy the Service ID).
  //   2. Create a template with fields {{to_email}} (To Email), {{subject}}
  //      (Subject), and {{message}} in the body (copy the Template ID).
  //   3. Account → General: copy the Public Key, and enable
  //      "Allow EmailJS API for non-browser applications".
  // All three values are public identifiers — safe to paste here.
  static const String emailJsServiceId = '';
  static const String emailJsTemplateId = '';
  static const String emailJsPublicKey = '';

  static bool get hasEmail =>
      emailJsServiceId.isNotEmpty &&
      emailJsTemplateId.isNotEmpty &&
      emailJsPublicKey.isNotEmpty;

  /// Play Store link for the Android app. Empty until it's published —
  /// the web version then tells Android visitors to ask for the APK.
  static const String playStoreUrl = '';
}
