/// App-wide configuration.
class AppConfig {
  /// Google Maps / Places key. Client keys are public identifiers (this
  /// same key ships in web/index.html and the Android manifest); restrict
  /// it by app/domain in the Google Cloud console. A `--dart-define` can
  /// still override it, but plain `flutter build` now just works.
  static const String googleMapsApiKey = String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: 'AIzaSyDxz50GD0TCXHmP61WJf7hsxBHWADXP0sw');

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
  static const String emailJsServiceId = 'service_z61oizl';
  static const String emailJsTemplateId = 'template_rzqagkc';
  static const String emailJsPublicKey = 'k4Ows-VVCo694ZqQ7';

  static bool get hasEmail =>
      emailJsServiceId.isNotEmpty &&
      emailJsTemplateId.isNotEmpty &&
      emailJsPublicKey.isNotEmpty;

  /// Play Store link for the Android app. Empty until it's published —
  /// the web version then tells Android visitors to ask for the APK.
  static const String playStoreUrl = '';

  /// Shown on the welcome screen + Settings → About, so "which build am I
  /// actually running?" is answerable at a glance (browser caches lie).
  static const String buildTag = 'v14';
}
