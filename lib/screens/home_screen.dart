import 'package:flutter/material.dart';

import '../data/restaurant_database.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../models/sort_option.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/sort_sheet.dart';
import 'add_rating_screen.dart';
import 'restaurant_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = RestaurantDatabase.instance;

  List<Restaurant> _all = [];
  bool _loading = true;

  SortOption _sort = SortOption.newest;
  final Set<FoodCategory> _activeFilters = {};

  // Current location cache for distance sorting.
  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _db.getAll();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
    });
  }

  Future<void> _openAdd() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRatingScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _openDetail(Restaurant r) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RestaurantDetailScreen(restaurant: r)),
    );
    if (changed == true) _load();
  }

  Future<void> _pickSort() async {
    final chosen = await SortSheet.show(context, _sort);
    if (chosen == null) return;

    if (chosen.needsLocation && (_myLat == null || _myLng == null)) {
      final pos = await LocationService.current();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Location unavailable — enable location to sort by distance.')),
          );
        }
        return;
      }
      _myLat = pos.latitude;
      _myLng = pos.longitude;
    }
    setState(() => _sort = chosen);
  }

  double? _distanceTo(Restaurant r) {
    if (_myLat == null || _myLng == null || r.lat == null || r.lng == null) {
      return null;
    }
    return LocationService.distanceMeters(_myLat!, _myLng!, r.lat!, r.lng!);
  }

  List<Restaurant> get _visible {
    var list = _all.where((r) {
      if (_activeFilters.isEmpty) return true;
      // Show restaurants that match ANY active filter.
      return r.categoryKeys
          .any((k) => _activeFilters.any((f) => f.key == k));
    }).toList();

    int byName(Restaurant a, Restaurant b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());

    switch (_sort) {
      case SortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.ratingHigh:
        list.sort((a, b) => b.overallRating.compareTo(a.overallRating));
        break;
      case SortOption.ratingLow:
        list.sort((a, b) => a.overallRating.compareTo(b.overallRating));
        break;
      case SortOption.priceLow:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHigh:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.nameAZ:
        list.sort(byName);
        break;
      case SortOption.nameZA:
        list.sort((a, b) => byName(b, a));
        break;
      case SortOption.distanceNear:
      case SortOption.distanceFar:
        list.sort((a, b) {
          final da = _distanceTo(a) ?? double.infinity;
          final db = _distanceTo(b) ?? double.infinity;
          return _sort == SortOption.distanceNear
              ? da.compareTo(db)
              : db.compareTo(da);
        });
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final showDistance = _sort.needsLocation;

    return Scaffold(
      floatingActionButton: _AddButton(onTap: _openAdd),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Restaurants',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    onPressed: _pickSort,
                    icon: const Icon(Icons.swap_vert_rounded),
                    tooltip: 'Sort',
                  ),
                ],
              ),
            ),
            _FilterBar(
              active: _activeFilters,
              onToggle: (c) {
                setState(() {
                  _activeFilters.contains(c)
                      ? _activeFilters.remove(c)
                      : _activeFilters.add(c);
                });
              },
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? _EmptyState(
                          filtered: _activeFilters.isNotEmpty || _all.isNotEmpty)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final r = visible[i];
                              return RestaurantCard(
                                restaurant: r,
                                distanceMeters:
                                    showDistance ? _distanceTo(r) : null,
                                onTap: () => _openDetail(r),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.active, required this.onToggle});

  final Set<FoodCategory> active;
  final ValueChanged<FoodCategory> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: FoodCategory.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = FoodCategory.values[i];
          final on = active.contains(c);
          return GestureDetector(
            onTap: () => onToggle(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppTheme.accent : AppTheme.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: on ? AppTheme.accent : AppTheme.line),
              ),
              child: Row(
                children: [
                  Icon(c.icon,
                      size: 15,
                      color: on ? Colors.white : AppTheme.subtle),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: on ? Colors.white : AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppTheme.accent, AppTheme.accentDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const SizedBox(
            width: 60,
            height: 60,
            child: Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ramen_dining_outlined,
                size: 64, color: AppTheme.subtle),
            const SizedBox(height: 16),
            Text(
              filtered
                  ? 'No restaurants match this filter'
                  : 'No ratings yet',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap the + button to rate your first spot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
