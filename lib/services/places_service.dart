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

/// Wrapper over the **Places API (New)** — `places.googleapis.com/v1`.
///
/// Uses a session token across autocomplete -> details for the cheaper
/// "per session" billing.
class PlacesService {
  static const _base = 'https://places.googleapis.com/v1';
  final String _apiKey = AppConfig.googleMapsApiKey;

  String _sessionToken = const Uuid().v4();

  /// Start a fresh autocomplete session (call when opening the field).
  void newSession() => _sessionToken = const Uuid().v4();

  bool get enabled => AppConfig.hasPlacesKey;

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (!enabled || input.trim().isEmpty) return [];

    final uri = Uri.parse('$_base/places:autocomplete');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: jsonEncode({
        'input': input,
        'sessionToken': _sessionToken,
      }),
    );

    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('Places autocomplete error ${res.statusCode}: ${res.body}');
      return [];
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final suggestions = body['suggestions'] as List? ?? [];

    final out = <PlacePrediction>[];
    for (final s in suggestions) {
      final pp = (s as Map<String, dynamic>)['placePrediction']
          as Map<String, dynamic>?;
      if (pp == null) continue;
      final structured = pp['structuredFormat'] as Map<String, dynamic>?;
      final mainText = (structured?['mainText']
              as Map<String, dynamic>?)?['text'] as String? ??
          (pp['text'] as Map<String, dynamic>?)?['text'] as String? ??
          '';
      final secondaryText = (structured?['secondaryText']
              as Map<String, dynamic>?)?['text'] as String? ??
          '';
      out.add(PlacePrediction(
        placeId: pp['placeId'] as String? ?? '',
        mainText: mainText,
        secondaryText: secondaryText,
      ));
    }
    return out;
  }

  Future<PlaceDetails?> details(String placeId) async {
    if (!enabled || placeId.isEmpty) return null;

    final uri = Uri.parse('$_base/places/$placeId').replace(
      queryParameters: {'sessionToken': _sessionToken},
    );
    final res = await http.get(uri, headers: {
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'id,displayName,formattedAddress,location,photos',
    });

    // Selecting a place ends the billing session.
    newSession();

    if (res.statusCode != 200) {
      // ignore: avoid_print
      print('Places details error ${res.statusCode}: ${res.body}');
      return null;
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final location = body['location'] as Map<String, dynamic>?;

    String? photoUrl;
    final photos = body['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final name = (photos.first as Map<String, dynamic>)['name'] as String?;
      if (name != null) photoUrl = photoUrlForName(name);
    }

    return PlaceDetails(
      name: (body['displayName']
              as Map<String, dynamic>?)?['text'] as String? ??
          '',
      address: body['formattedAddress'] as String? ?? '',
      lat: (location?['latitude'] as num?)?.toDouble(),
      lng: (location?['longitude'] as num?)?.toDouble(),
      photoUrl: photoUrl,
    );
  }

  /// Build a directly-loadable Place Photo URL from a photo resource name
  /// like `places/PLACE_ID/photos/PHOTO_REF`.
  String photoUrlForName(String photoName, {int maxWidth = 800}) {
    return '$_base/$photoName/media?maxWidthPx=$maxWidth&key=$_apiKey';
  }
}
