import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../config.dart';

/// One autocomplete suggestion.
class PlacePrediction {
  final String placeId;
  final String mainText; // usually the restaurant name
  final String secondaryText; // usually the address

  PlacePrediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });

  String get description =>
      secondaryText.isEmpty ? mainText : '$mainText, $secondaryText';
}

/// Resolved details for a selected place.
class PlaceDetails {
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? photoUrl;

  PlaceDetails({
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.photoUrl,
  });
}

/// Thin wrapper over the Google Places REST API.
///
/// Uses a session token across autocomplete -> details to get the
/// cheaper "per session" billing.
class PlacesService {
  static const _base = 'https://maps.googleapis.com/maps/api/place';
  final String _apiKey = AppConfig.googleMapsApiKey;

  String _sessionToken = const Uuid().v4();

  /// Start a fresh autocomplete session (call when opening the field).
  void newSession() => _sessionToken = const Uuid().v4();

  bool get enabled => AppConfig.hasPlacesKey;

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (!enabled || input.trim().isEmpty) return [];

    final uri = Uri.parse('$_base/autocomplete/json').replace(
      queryParameters: {
        'input': input,
        'key': _apiKey,
        'sessiontoken': _sessionToken,
        // Bias toward restaurants/places but still allow address text.
        'types': 'establishment',
      },
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return [];

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final status = body['status'] as String?;
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      // Surface API errors during development.
      // ignore: avoid_print
      print('Places autocomplete error: $status ${body['error_message']}');
      return [];
    }

    final preds = (body['predictions'] as List? ?? []);
    return preds.map((p) {
      final structured = p['structured_formatting'] as Map<String, dynamic>?;
      return PlacePrediction(
        placeId: p['place_id'] as String,
        mainText: structured?['main_text'] as String? ??
            p['description'] as String? ??
            '',
        secondaryText: structured?['secondary_text'] as String? ?? '',
      );
    }).toList();
  }

  Future<PlaceDetails?> details(String placeId) async {
    if (!enabled) return null;

    final uri = Uri.parse('$_base/details/json').replace(
      queryParameters: {
        'place_id': placeId,
        'key': _apiKey,
        'sessiontoken': _sessionToken,
        'fields': 'name,formatted_address,geometry,photos',
      },
    );

    final res = await http.get(uri);
    // Selecting a place ends the billing session.
    newSession();

    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 'OK') return null;

    final result = body['result'] as Map<String, dynamic>;
    final geometry = result['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;

    String? photoUrl;
    final photos = result['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final ref = photos.first['photo_reference'] as String?;
      if (ref != null) photoUrl = photoUrlFor(ref);
    }

    return PlaceDetails(
      name: result['name'] as String? ?? '',
      address: result['formatted_address'] as String? ?? '',
      lat: (location?['lat'] as num?)?.toDouble(),
      lng: (location?['lng'] as num?)?.toDouble(),
      photoUrl: photoUrl,
    );
  }

  /// Build a directly-loadable Place Photo URL.
  String photoUrlFor(String photoReference, {int maxWidth = 800}) {
    return '$_base/photo?maxwidth=$maxWidth'
        '&photo_reference=$photoReference&key=$_apiKey';
  }
}
