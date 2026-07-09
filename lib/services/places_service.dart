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
  final String? placeId;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? photoUrl;

  /// All of the place's Google Maps photos (loadable URLs, first = cover).
  final List<String> photoUrls;

  // Structured address parts (for chain location labels).
  final String? streetNumber;
  final String? route; // street name
  final String? city;

  PlaceDetails({
    this.placeId,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.photoUrl,
    this.photoUrls = const [],
    this.streetNumber,
    this.route,
    this.city,
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

  double? _biasLat;
  double? _biasLng;

  /// Bias autocomplete results toward this location (the user's position), so
  /// the nearest matching restaurant ranks first.
  void setLocationBias(double? lat, double? lng) {
    _biasLat = lat;
    _biasLng = lng;
  }

  /// Start a fresh autocomplete session (call when opening the field).
  void newSession() => _sessionToken = const Uuid().v4();

  bool get enabled => AppConfig.hasPlacesKey;

  Future<List<PlacePrediction>> autocomplete(String input) async {
    if (!enabled || input.trim().isEmpty) return [];
    try {
      return await _autocomplete(input);
    } catch (e) {
      // Network/CORS hiccup — degrade to manual entry.
      // ignore: avoid_print
      print('Places autocomplete error: $e');
      return [];
    }
  }

  Future<List<PlacePrediction>> _autocomplete(String input) async {
    final uri = Uri.parse('$_base/places:autocomplete');
    final reqBody = <String, dynamic>{
      'input': input,
      'sessionToken': _sessionToken,
    };
    if (_biasLat != null && _biasLng != null) {
      // Bias (not restrict) toward the user's location, ~30km radius, and set
      // the origin so closer results are favored.
      reqBody['locationBias'] = {
        'circle': {
          'center': {'latitude': _biasLat, 'longitude': _biasLng},
          'radius': 30000.0,
        }
      };
      reqBody['origin'] = {'latitude': _biasLat, 'longitude': _biasLng};
    }
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': _apiKey,
      },
      body: jsonEncode(reqBody),
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
    try {
      return await _details(placeId);
    } catch (e) {
      // ignore: avoid_print
      print('Places details error: $e');
      return null;
    }
  }

  Future<PlaceDetails?> _details(String placeId) async {
    final uri = Uri.parse('$_base/places/$placeId').replace(
      queryParameters: {'sessionToken': _sessionToken},
    );
    final res = await http.get(uri, headers: {
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask':
          'id,displayName,formattedAddress,location,photos,addressComponents',
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

    final photoUrls = <String>[];
    final photos = body['photos'] as List?;
    if (photos != null) {
      for (final p in photos.take(10)) {
        final name = (p as Map<String, dynamic>)['name'] as String?;
        if (name != null) photoUrls.add(photoUrlForName(name));
      }
    }
    final photoUrl = photoUrls.isEmpty ? null : photoUrls.first;

    // Parse structured address components.
    final comps = body['addressComponents'] as List?;
    String? findComp(String type) {
      if (comps == null) return null;
      for (final c in comps) {
        final types = ((c as Map<String, dynamic>)['types'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];
        if (types.contains(type)) {
          return c['longText'] as String? ?? c['shortText'] as String?;
        }
      }
      return null;
    }

    final streetNumber = findComp('street_number');
    final route = findComp('route');
    // For NYC boroughs the borough is the sublocality; otherwise locality.
    final city = findComp('sublocality_level_1') ??
        findComp('locality') ??
        findComp('postal_town') ??
        findComp('administrative_area_level_2');

    return PlaceDetails(
      placeId: body['id'] as String? ?? placeId,
      name: (body['displayName']
              as Map<String, dynamic>?)?['text'] as String? ??
          '',
      address: body['formattedAddress'] as String? ?? '',
      lat: (location?['latitude'] as num?)?.toDouble(),
      lng: (location?['longitude'] as num?)?.toDouble(),
      photoUrl: photoUrl,
      photoUrls: photoUrls,
      streetNumber: streetNumber,
      route: route,
      city: city,
    );
  }

  /// Fetch just the photo URLs for a place (for the cover-photo chooser when
  /// the place was picked earlier and its photos weren't kept around).
  Future<List<String>> photos(String placeId) async {
    if (!enabled || placeId.isEmpty) return [];
    final uri = Uri.parse('$_base/places/$placeId');
    final res = await http.get(uri, headers: {
      'X-Goog-Api-Key': _apiKey,
      'X-Goog-FieldMask': 'photos',
    });
    if (res.statusCode != 200) return [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final out = <String>[];
    for (final p in (body['photos'] as List? ?? []).take(10)) {
      final name = (p as Map<String, dynamic>)['name'] as String?;
      if (name != null) out.add(photoUrlForName(name));
    }
    return out;
  }

  /// Build a directly-loadable Place Photo URL from a photo resource name
  /// like `places/PLACE_ID/photos/PHOTO_REF`.
  String photoUrlForName(String photoName, {int maxWidth = 800}) {
    return '$_base/$photoName/media?maxWidthPx=$maxWidth&key=$_apiKey';
  }
}
