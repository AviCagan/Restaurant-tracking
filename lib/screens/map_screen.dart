import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/category_mapping.dart';
import '../data/filter_state.dart';
import '../data/social_service.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/feed_card.dart';
import 'compare_categories_screen.dart';
import 'place_web_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  // Default to Staten Island (matches the mock data).
  static const _defaultCenter = LatLng(40.5900, -74.1200);

  List<MapPlace> get _places {
    final active = FilterState.categories;
    final all = SocialService.mapPlaces();
    if (active.isEmpty) return all;
    return all.where((p) {
      final resolved = CategoryMapping.resolveAll(p.categoryKeys).toSet();
      return resolved.any(active.contains);
    }).toList();
  }

  Set<Marker> _markers() {
    return _places.map((p) {
      final hue = (((p.rating - 1) / 9) * 120).clamp(0.0, 120.0);
      return Marker(
        markerId: MarkerId(p.id),
        position: LatLng(p.lat, p.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
            title: p.name, snippet: '${p.rating.toStringAsFixed(1)} ★'),
        onTap: () => _showPlace(p),
      );
    }).toSet();
  }

  Future<void> _recenter() async {
    final pos = await LocationService.current();
    final target =
        pos == null ? _defaultCenter : LatLng(pos.latitude, pos.longitude);
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 13));
  }

  Future<void> _openFilter() async {
    final result = await FilterSheet.show(
      context,
      categories: FilterState.categories,
      chains: FilterState.chains,
      availableChains: const [],
    );
    if (result == null) return;
    setState(() {
      FilterState.categories
        ..clear()
        ..addAll(result.categories);
      FilterState.chains
        ..clear()
        ..addAll(result.chains);
    });
  }

  void _showPlace(MapPlace p) {
    final colors = context.colors;
    final liked = p.visits.where((v) => v.liked).toList();
    final disliked = p.visits.where((v) => !v.liked).toList();
    final t = (p.rating / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF3FB55D), t)!;

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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: AppTheme.heading(22, color: colors.ink)),
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
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(p.rating.toStringAsFixed(1),
                        style: AppTheme.heading(20, color: color)),
                  ),
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlaceWebScreen(
                        query: '${p.name} ${p.address}', title: p.name),
                  ),
                ),
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
            Text('Friends who went', style: AppTheme.heading(18, color: colors.ink)),
            const SizedBox(height: 10),
            if (liked.isNotEmpty) ...[
              _group('👍 Liked it', const Color(0xFF3FB55D)),
              ...liked.map(_friendRow),
            ],
            if (disliked.isNotEmpty) ...[
              const SizedBox(height: 8),
              _group('👎 Not for them', const Color(0xFFE0795A)),
              ...disliked.map(_friendRow),
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

  Widget _friendRow(FriendVisit v) {
    final colors = context.colors;
    final t = (v.rating / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF3FB55D), t)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.panel(context, radius: 16),
      child: Row(
        children: [
          PersonAvatar(name: v.friend.name, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.friend.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14)),
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10)),
            child: Text(v.rating.toStringAsFixed(0),
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
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              const CameraPosition(target: _defaultCenter, zoom: 12),
          onMapCreated: (c) {
            _controller = c;
            _recenter();
          },
          markers: _markers(),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Row(
            children: [
              _MapButton(
                icon: Icons.tune_rounded,
                label: filterCount > 0 ? 'Filters ($filterCount)' : 'Filter',
                onTap: _openFilter,
              ),
              const SizedBox(width: 8),
              _MapButton(
                icon: Icons.compare_arrows_rounded,
                label: 'Compare',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CompareCategoriesScreen()),
                ).then((_) => setState(() {})),
              ),
            ],
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
  const _MapButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: colors.ink.withValues(alpha: 0.13), width: 1.5),
          boxShadow: AppTheme.shadow(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppTheme.accent),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
