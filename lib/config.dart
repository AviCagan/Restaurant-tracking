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
}
