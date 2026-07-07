import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/category_mapping.dart';
import '../data/filter_state.dart';
import '../data/friend_group_store.dart';
import '../data/restaurant_database.dart';
import '../data/social_service.dart';
import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/feed_card.dart';
import '../widgets/group_sheets.dart';
import 'compare_categories_screen.dart';

/// One person's rating of a place.
class _Rater {
  final String name;
  final double rating;
  final String review;
  final bool isYou;

  /// Price tier they rated (1..4, 0 = unknown).
  final int price;

  const _Rater(this.name, this.rating, this.review, this.isYou,
      {this.price = 0});
  bool get liked => rating >= 7;
}

/// A place on the map, with everyone (you + friends) who rated it.
class _Pin {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final List<String> categoryKeys;
  final List<_Rater> raters;
  _Pin(this.name, this.address, this.lat, this.lng, this.categoryKeys,
      this.raters);
}

Color ratingColor(double r) {
  final t = (r / 10).clamp(0.0, 1.0);
  const red = Color(0xFFE53935);
  const amber = Color(0xFFF9A825);
  const green = Color(0xFF2E9E5B);
  return t < 0.5
      ? Color.lerp(red, amber, t / 0.5)!
      : Color.lerp(amber, green, (t - 0.5) / 0.5)!;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  static const _defaultCenter = LatLng(40.5900, -74.1200);

  Set<Marker> _markers = {};
  final Map<int, BitmapDescriptor> _pinCache = {};

  List<Restaurant> _myPlaces = [];
  // Selected people to filter by (empty = everyone).
  final Set<String> _people = {};

  // Resolved before the map is built so it opens right where you are —
  // no flying across the city on load.
  LatLng? _start;
  bool _startResolved = false;

  @override
  void initState() {
    super.initState();
    _resolveStart();
    _loadMine();
  }

  Future<void> _resolveStart() async {
    // Last known position is instant when available.
    final last = await LocationService.lastKnown();
    if (last != null) {
      _start = LatLng(last.latitude, last.longitude);
    } else {
      final pos = await LocationService.current();
      if (pos != null) _start = LatLng(pos.latitude, pos.longitude);
    }
    if (mounted) setState(() => _startResolved = true);
  }

  /// Zoom/pan so every visible pin fits on screen.
  Future<void> _fitToMarkers() async {
    if (_controller == null || _markers.isEmpty) return;
    if (_markers.length == 1) {
      await _controller!.animateCamera(
          CameraUpdate.newLatLngZoom(_markers.first.position, 14));
      return;
    }
    var minLat = double.infinity, maxLat = -double.infinity;
    var minLng = double.infinity, maxLng = -double.infinity;
    for (final m in _markers) {
      final p = m.position;
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng)),
      70,
    ));
  }

  Future<void> _loadMine() async {
    final all = await RestaurantDatabase.instance.getAll();
    _myPlaces = all.where((r) => r.lat != null && r.lng != null).toList();
    await _buildMarkers();
  }

  List<String> get _peopleList =>
      ['You', ...SocialService.friends.value.map((f) => f.name)];

  /// All map pins, merging friends' rated places with your own (by name).
  List<_Pin> _allPins() {
    final byName = <String, _Pin>{};

    _Pin acc(String name, String address, double lat, double lng) =>
        byName.putIfAbsent(
            name.toLowerCase(), () => _Pin(name, address, lat, lng, [], []));

    for (final mp in SocialService.mapPlaces()) {
      final p = acc(mp.name, mp.address, mp.lat, mp.lng);
      p.categoryKeys.addAll(mp.categoryKeys);
      for (final v in mp.visits) {
        p.raters.add(
            _Rater(v.friend.name, v.rating, v.review, false, price: v.price));
      }
    }
    for (final r in _myPlaces) {
      final p = acc(r.name, r.address, r.lat!, r.lng!);
      p.categoryKeys.addAll(r.categoryKeys);
      p.raters.add(_Rater('You', r.overallRating, '', true,
          price: r.visits.isEmpty ? 0 : r.avgPrice.round()));
    }
    return byName.values.toList();
  }

  /// Visible pins after applying category + people filters; returns the pin,
  /// its visible raters and the resulting average rating.
  List<(_Pin, List<_Rater>, double)> _visible() {
    final cats = FilterState.categories;
    final out = <(_Pin, List<_Rater>, double)>[];
    for (final pin in _allPins()) {
      var raters = pin.raters;
      if (_people.isNotEmpty) {
        raters = raters.where((r) => _people.contains(r.name)).toList();
      }
      if (raters.isEmpty) continue;
      if (cats.isNotEmpty) {
        final resolved = CategoryMapping.resolveAll(pin.categoryKeys).toSet();
        if (!resolved.any(cats.contains)) continue;
      }
      final rating =
          raters.fold<double>(0, (s, r) => s + r.rating) / raters.length;
      out.add((pin, raters, rating));
    }
    return out;
  }

  Future<BitmapDescriptor> _pin(double rating) async {
    final key = rating.round().clamp(0, 10);
    final cached = _pinCache[key];
    if (cached != null) return cached;

    const s = 3.0;
    const cx = 39.0 * s, cy = 33.0 * s, r = 30.0 * s;
    const w = 78.0 * s, h = 96.0 * s;
    final color = ratingColor(rating);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    void shape(Paint paint, double dy) {
      canvas.save();
      canvas.translate(0, dy);
      final tail = Path()
        ..moveTo(cx - 13 * s, cy + 21 * s)
        ..lineTo(cx, h - 2 * s)
        ..lineTo(cx + 13 * s, cy + 21 * s)
        ..close();
      canvas.drawPath(tail, paint);
      canvas.drawCircle(const Offset(cx, cy), r, paint);
      canvas.restore();
    }

    // Soft shadow.
    shape(
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        3 * s);
    // Fill + white ring.
    shape(Paint()..color = color..isAntiAlias = true, 0);
    canvas.drawCircle(
        const Offset(cx, cy),
        r,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * s
          ..isAntiAlias = true);

    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: rating == 0 ? '–' : rating.toStringAsFixed(1),
        style: const TextStyle(
            color: Colors.white,
            fontSize: 23 * s,
            fontWeight: FontWeight.w800),
      ),
    )..layout();
    tp.paint(canvas, const Offset(cx, cy) - Offset(tp.width / 2, tp.height / 2));

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final desc = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(),
        imagePixelRatio: s);
    _pinCache[key] = desc;
    return desc;
  }

  Future<void> _buildMarkers() async {
    final markers = <Marker>{};
    for (final entry in _visible()) {
      final pin = entry.$1;
      final raters = entry.$2;
      final rating = entry.$3;
      markers.add(Marker(
        markerId: MarkerId(pin.name),
        position: LatLng(pin.lat, pin.lng),
        icon: await _pin(rating),
        onTap: () => _showPlace(pin, raters, rating),
      ));
    }
    if (mounted) setState(() => _markers = markers);
  }

  Future<void> _recenter({bool animate = true}) async {
    final pos = await LocationService.current();
    final target =
        pos == null ? _defaultCenter : LatLng(pos.latitude, pos.longitude);
    final update = CameraUpdate.newLatLngZoom(target, 13);
    if (animate) {
      await _controller?.animateCamera(update);
    } else {
      await _controller?.moveCamera(update);
    }
    if (pos == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Turn on location to see where you are.')));
    }
  }

  Future<void> _openFilter() async {
    final result = await FilterSheet.show(
      context,
      categories: FilterState.categories,
      chains: FilterState.chains,
      availableChains: const [],
    );
    if (result == null) return;
    FilterState.categories
      ..clear()
      ..addAll(result.categories);
    await _buildMarkers();
    _fitToMarkers();
  }

  void _openPeople() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void toggle(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
            _buildMarkers().then((_) => _fitToMarkers());
          }

          final colors = context.colors;
          // Map group usernames -> display names used by the people filter.
          final usernameToName = {
            for (final f in SocialService.friends.value) f.username: f.name
          };
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Text('Whose ratings?',
                          style: AppTheme.heading(18, color: colors.ink)),
                      const Spacer(),
                      if (_people.isNotEmpty)
                        TextButton(
                          onPressed: () => toggle(_people.clear),
                          child: const Text('Everyone'),
                        ),
                    ],
                  ),
                ),
                if (FriendGroupStore.all.value.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FriendGroupStore.all.value.map((g) {
                        final members = g.usernames
                            .map((u) => usernameToName[u])
                            .whereType<String>()
                            .toSet();
                        final on = members.isNotEmpty &&
                            _people.length == members.length &&
                            _people.containsAll(members);
                        return FilterChip(
                          selected: on,
                          selectedColor:
                              AppTheme.accent.withValues(alpha: 0.18),
                          checkmarkColor: AppTheme.accent,
                          avatar: GroupAvatar(group: g, size: 18),
                          label: Text(g.name),
                          onSelected: (_) => toggle(() {
                            _people.clear();
                            if (!on) _people.addAll(members);
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ..._peopleList.map((name) {
                  final on = _people.isEmpty || _people.contains(name);
                  return CheckboxListTile(
                    value: on,
                    activeColor: AppTheme.accent,
                    secondary: PersonAvatar(name: name, size: 38),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    onChanged: (_) => toggle(() {
                      // Move from "everyone" to an explicit set on first tap.
                      if (_people.isEmpty) {
                        _people.addAll(_peopleList);
                      }
                      _people.contains(name)
                          ? _people.remove(name)
                          : _people.add(name);
                      if (_people.length == _peopleList.length) {
                        _people.clear(); // back to "everyone"
                      }
                    }),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openInMaps(_Pin p) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${p.name} ${p.address}')}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok) await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _showPlace(_Pin p, List<_Rater> raters, double rating) {
    final colors = context.colors;
    final liked = raters.where((v) => v.liked).toList();
    final disliked = raters.where((v) => !v.liked).toList();
    final color = ratingColor(rating);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: colors.line,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name,
                          style: AppTheme.heading(22, color: colors.ink)),
                      const SizedBox(height: 2),
                      Text(p.address,
                          style: TextStyle(color: colors.subtle, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                      child: Text(rating.toStringAsFixed(1),
                          style: AppTheme.heading(20, color: color))),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _openInMaps(p);
                },
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Google Maps',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
            Text('Call, website, order & reserve are on the Maps page',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: colors.subtle)),
            const SizedBox(height: 20),
            Text('Who rated it',
                style: AppTheme.heading(18, color: colors.ink)),
            const SizedBox(height: 10),
            if (liked.isNotEmpty) ...[
              _group('👍 Liked it', const Color(0xFF2E9E5B)),
              ...liked.map(_raterRow),
            ],
            if (disliked.isNotEmpty) ...[
              const SizedBox(height: 8),
              _group('👎 Not for them', const Color(0xFFE0795A)),
              ...disliked.map(_raterRow),
            ],
          ],
        ),
      ),
    );
  }

  Widget _group(String label, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      );

  Widget _raterRow(_Rater v) {
    final colors = context.colors;
    final color = ratingColor(v.rating);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.panel(context, radius: 16),
      child: Row(
        children: [
          PersonAvatar(name: v.name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(v.isYou ? 'You' : v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                    ),
                    if (v.price > 0) ...[
                      const SizedBox(width: 6),
                      Text(PriceTier.signs(v.price),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colors.subtle)),
                    ],
                  ],
                ),
                if (v.review.isNotEmpty)
                  Text('“${v.review}”',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: colors.subtle,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10)),
            child: Text(v.rating.toStringAsFixed(1),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filterCount = FilterState.categories.length;
    final peopleActive = _people.isNotEmpty;
    if (!_startResolved) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _start ?? _defaultCenter, zoom: 13),
          onMapCreated: (c) {
            _controller = c;
            // Only jump if we opened without a known position.
            if (_start == null) _recenter(animate: false);
          },
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer()),
          },
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MapButton(
                  icon: Icons.tune_rounded,
                  label: filterCount > 0 ? 'Filters ($filterCount)' : 'Filter',
                  active: filterCount > 0,
                  onTap: _openFilter,
                ),
                const SizedBox(width: 8),
                _MapButton(
                  icon: Icons.people_alt_rounded,
                  label: peopleActive ? 'People (${_people.length})' : 'People',
                  active: peopleActive,
                  onTap: _openPeople,
                ),
                const SizedBox(width: 8),
                _MapButton(
                  icon: Icons.compare_arrows_rounded,
                  label: 'Compare',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CompareCategoriesScreen()),
                  ).then((_) => _buildMarkers()),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'recenter',
            backgroundColor: colors.surface,
            foregroundColor: AppTheme.accent,
            onPressed: _recenter,
            child: const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: active
                  ? AppTheme.accent
                  : colors.ink.withValues(alpha: 0.13),
              width: 1.5),
          boxShadow: AppTheme.shadow(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: active ? Colors.white : AppTheme.accent),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: active ? Colors.white : colors.ink)),
          ],
        ),
      ),
    );
  }
}
