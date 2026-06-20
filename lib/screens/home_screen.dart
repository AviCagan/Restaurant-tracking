import 'package:flutter/material.dart';

import '../data/category_store.dart';
import '../data/restaurant_database.dart';
import '../models/restaurant.dart';
import '../models/sort_option.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/category_filter_sheet.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/sort_sheet.dart';
import 'add_restaurant_screen.dart';
import 'add_visit_screen.dart';
import 'restaurant_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = RestaurantDatabase.instance;
  final _searchCtrl = TextEditingController();

  List<Restaurant> _all = [];
  bool _loading = true;

  SortOption _sort = SortOption.newest;
  final Set<String> _activeFilters = {};
  String _query = '';

  double? _myLat;
  double? _myLng;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      MaterialPageRoute(builder: (_) => const AddRestaurantScreen()),
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

  Future<void> _quickAddVisit(Restaurant r) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddVisitScreen(restaurant: r)),
    );
    if (added == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Visit added to ${r.name}')),
        );
      }
    }
  }

  Future<void> _openFilter() async {
    final result = await CategoryFilterSheet.show(context, _activeFilters);
    if (result == null) return;
    setState(() {
      _activeFilters
        ..clear()
        ..addAll(result);
    });
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
                content: Text(
                    'Location unavailable — enable location to sort by distance.')),
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
    final q = _query.trim().toLowerCase();
    var list = _all.where((r) {
      final matchesFilter = _activeFilters.isEmpty ||
          r.categoryKeys.any(_activeFilters.contains);
      final matchesQuery = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q);
      return matchesFilter && matchesQuery;
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
        list.sort((a, b) => a.avgPrice.compareTo(b.avgPrice));
        break;
      case SortOption.priceHigh:
        list.sort((a, b) => b.avgPrice.compareTo(a.avgPrice));
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
    final colors = context.colors;
    final visible = _visible;
    final showDistance = _sort.needsLocation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButton: _AddButton(onTap: _openAdd),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Restaurants',
                        style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w800)),
                  ),
                  _FilterButton(
                    count: _activeFilters.length,
                    onTap: _openFilter,
                  ),
                  IconButton(
                    onPressed: () => ThemeController.toggle(context),
                    icon: Icon(isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined),
                    tooltip: 'Toggle theme',
                  ),
                  IconButton(
                    onPressed: _pickSort,
                    icon: const Icon(Icons.swap_vert_rounded),
                    tooltip: 'Sort',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search your restaurants…',
                  prefixIcon: Icon(Icons.search, color: colors.subtle),
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
            ),
            if (_activeFilters.isNotEmpty)
              _ActiveFilters(
                active: _activeFilters,
                onRemove: (c) => setState(() => _activeFilters.remove(c)),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                      ? _EmptyState(filtered: _all.isNotEmpty)
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
                                onLongPress: () => _quickAddVisit(r),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Filter',
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.active, required this.onRemove});

  final Set<String> active;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final cats = CategoryStore.fromKeys(active.toList());
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: cats
            .map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onRemove(c.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          Icon(c.icon, size: 14, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text(c.label,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent)),
                          const SizedBox(width: 4),
                          const Icon(Icons.close,
                              size: 13, color: AppTheme.accent),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
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
            color: AppTheme.accent.withValues(alpha: 0.45),
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
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.ramen_dining_outlined, size: 64, color: colors.subtle),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matches' : 'No ratings yet',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try a different search or filter.'
                  : 'Tap the + button to rate your first spot.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.subtle),
            ),
          ],
        ),
      ),
    );
  }
}
