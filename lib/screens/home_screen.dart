import 'package:flutter/material.dart';

import '../data/category_store.dart';
import '../data/filter_state.dart';
import '../data/restaurant_database.dart';
import '../models/restaurant.dart';
import '../models/sort_option.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
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
  Set<String> get _activeFilters => FilterState.categories;
  Set<String> get _activeChains => FilterState.chains;
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

  Future<bool> _confirmDelete(Restaurant r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete restaurant?'),
        content: Text('Remove "${r.name}" and all its visits?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.accent))),
        ],
      ),
    );
    return ok ?? false;
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

  List<String> get _availableChains {
    final names = <String>{};
    for (final r in _all) {
      if (r.isChain && (r.chainName?.trim().isNotEmpty ?? false)) {
        names.add(r.chainName!.trim());
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  Future<void> _openFilter() async {
    final result = await FilterSheet.show(
      context,
      categories: _activeFilters,
      chains: _activeChains,
      availableChains: _availableChains,
    );
    if (result == null) return;
    setState(() {
      _activeFilters
        ..clear()
        ..addAll(result.categories);
      _activeChains
        ..clear()
        ..addAll(result.chains);
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
      final matchesChain = _activeChains.isEmpty ||
          (r.isChain &&
              r.chainName != null &&
              _activeChains.contains(r.chainName!.trim()));
      final matchesQuery = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q);
      return matchesFilter && matchesChain && matchesQuery;
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

    return Scaffold(
      floatingActionButton: _AddButton(onTap: _openAdd),
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search your spots…',
                        prefixIcon:
                            Icon(Icons.search, color: colors.subtle),
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
                  const SizedBox(width: 8),
                  _ToolButton(
                    icon: Icons.tune_rounded,
                    onTap: _openFilter,
                    badge: _activeFilters.length + _activeChains.length,
                  ),
                  const SizedBox(width: 8),
                  _ToolButton(
                      icon: Icons.swap_vert_rounded, onTap: _pickSort),
                ],
              ),
            ),
            if (_activeFilters.isNotEmpty || _activeChains.isNotEmpty)
              _ActiveFilters(
                active: _activeFilters,
                chains: _activeChains,
                onRemove: (c) => setState(() => _activeFilters.remove(c)),
                onRemoveChain: (c) => setState(() => _activeChains.remove(c)),
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
                              return Dismissible(
                                key: ValueKey(r.id),
                                background: const _SwipeBackground(
                                  alignment: Alignment.centerLeft,
                                  color: Color(0xFFE0484D),
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                ),
                                secondaryBackground: const _SwipeBackground(
                                  alignment: Alignment.centerRight,
                                  color: Color(0xFF34C759),
                                  icon: Icons.add,
                                  label: 'Add visit',
                                ),
                                confirmDismiss: (dir) async {
                                  if (dir == DismissDirection.startToEnd) {
                                    final ok = await _confirmDelete(r);
                                    if (ok) await _db.delete(r.id);
                                    return ok;
                                  } else {
                                    await _quickAddVisit(r);
                                    return false;
                                  }
                                },
                                onDismissed: (_) => setState(() =>
                                    _all.removeWhere((x) => x.id == r.id)),
                                child: RestaurantCard(
                                  restaurant: r,
                                  distanceMeters:
                                      showDistance ? _distanceTo(r) : null,
                                  onTap: () => _openDetail(r),
                                  onLongPress: () => _quickAddVisit(r),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
    );
  }
}


class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.onTap, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.line),
            ),
            child: Icon(icon, color: colors.ink),
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 1.5),
              ),
              child: Text('$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }
}


class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.active,
    required this.chains,
    required this.onRemove,
    required this.onRemoveChain,
  });

  final Set<String> active;
  final Set<String> chains;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onRemoveChain;

  @override
  Widget build(BuildContext context) {
    final cats = CategoryStore.fromKeys(active.toList());
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...cats.map((c) => _RemovableChip(
                icon: c.icon,
                label: c.label,
                onTap: () => onRemove(c.key),
              )),
          ...chains.map((chain) => _RemovableChip(
                icon: Icons.storefront_outlined,
                label: chain,
                onTap: () => onRemoveChain(chain),
              )),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent)),
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 13, color: AppTheme.accent),
            ],
          ),
        ),
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
            Text(filtered ? '🔍' : '🍽️', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              filtered ? 'No matches' : 'Let\'s eat!',
              style: AppTheme.heading(22, color: context.colors.ink),
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
