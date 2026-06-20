import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/category_store.dart';
import '../data/restaurant_database.dart';
import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../models/visit.dart';
import '../theme/app_theme.dart';
import 'add_restaurant_screen.dart';
import 'add_visit_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final _db = RestaurantDatabase.instance;
  late Restaurant _r = widget.restaurant;
  bool _changed = false;

  Future<void> _reload() async {
    final fresh = await _db.getById(_r.id);
    if (fresh != null && mounted) {
      setState(() {
        _r = fresh;
        _changed = true;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final updated = _r.copyWith(isFavorite: !_r.isFavorite);
    await _db.upsert(updated);
    if (mounted) {
      setState(() {
        _r = updated;
        _changed = true;
      });
    }
  }

  Future<void> _editIdentity() async {
    final updated = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => AddRestaurantScreen(existing: _r)));
    if (updated == true) _reload();
  }

  Future<void> _addVisit() async {
    final added = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => AddVisitScreen(restaurant: _r)));
    if (added == true) _reload();
  }

  Future<void> _editVisit(Visit v) async {
    final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => AddVisitScreen(restaurant: _r, visit: v)));
    if (updated == true) _reload();
  }

  Future<void> _deleteVisit(Visit v) async {
    final confirm = await _confirm('Delete this visit?',
        'This removes one visit and recalculates the averages.');
    if (confirm != true) return;
    final visits = _r.visits.where((e) => e.id != v.id).toList();
    await _db.upsert(_r.copyWith(visits: visits));
    _reload();
  }

  Future<void> _deleteRestaurant() async {
    final confirm = await _confirm(
        'Delete restaurant?', 'Remove "${_r.name}" and all its visits?');
    if (confirm == true) {
      await _db.delete(_r.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<bool?> _confirm(String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cover = _r.coverImage;
    final cats = CategoryStore.fromKeys(_r.categoryKeys);
    final visits = [..._r.visits]..sort((a, b) => b.date.compareTo(a.date));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addVisit,
          backgroundColor: AppTheme.accent,
          icon: const Icon(Icons.add),
          label: const Text('Add visit',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: cover != null ? 240 : 0,
                pinned: true,
                backgroundColor: colors.background,
                actions: [
                  IconButton(
                    onPressed: _toggleFavorite,
                    icon: Icon(
                      _r.isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _r.isFavorite ? AppTheme.accent : null,
                    ),
                  ),
                  IconButton(
                      onPressed: _editIdentity,
                      icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                      onPressed: _deleteRestaurant,
                      icon: const Icon(Icons.delete_outline)),
                ],
                flexibleSpace: cover == null
                    ? null
                    : FlexibleSpaceBar(
                        background: _r.coverIsLocalFile
                            ? Image.file(File(cover), fit: BoxFit.cover)
                            : CachedNetworkImage(
                                imageUrl: cover, fit: BoxFit.cover),
                      ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_r.name,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      if (_r.isChain) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (_r.locationDescriptor != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.place,
                                        size: 14, color: AppTheme.accent),
                                    const SizedBox(width: 5),
                                    Text(
                                      _r.locationDescriptor!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.accent),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.storefront_outlined,
                                size: 14, color: colors.subtle),
                            const SizedBox(width: 5),
                            Text('Part of ${_r.chainName ?? _r.name}',
                                style: TextStyle(
                                    fontSize: 12.5, color: colors.subtle)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(_r.address,
                          style: TextStyle(color: colors.subtle, fontSize: 14)),
                      const SizedBox(height: 20),
                      _SummaryCard(restaurant: _r),
                      if (cats.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: cats
                              .map((c) => Chip(
                                    avatar: Icon(c.icon, size: 16),
                                    label: Text(c.label),
                                  ))
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 26),
                      Text('Visits',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: colors.ink)),
                      const SizedBox(height: 12),
                      if (visits.isEmpty)
                        Text('No visits yet — tap "Add visit".',
                            style: TextStyle(color: colors.subtle))
                      else
                        ...visits.map((v) => _VisitCard(
                              visit: v,
                              onEdit: () => _editVisit(v),
                              onDelete: () => _deleteVisit(v),
                            )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Redesigned aggregate header: a hero overall score + metric bars.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.restaurant});
  final Restaurant restaurant;

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = restaurant;
    final overall = r.overallRating;
    final t = (overall / 10).clamp(0.0, 1.0);
    final heroColor =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF34C759), t)!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: heroColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      r.visits.isEmpty ? '–' : _fmt(overall),
                      style: TextStyle(
                          fontSize: 32,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          color: heroColor),
                    ),
                    const SizedBox(height: 2),
                    Text('Overall',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: heroColor)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _MetricBar(
                        label: 'Food',
                        value: r.avgFood,
                        text: _fmt(r.avgFood)),
                    const SizedBox(height: 12),
                    _MetricBar(
                        label: 'Atmosphere',
                        value: r.avgAtmosphere,
                        text: _fmt(r.avgAtmosphere)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: colors.line, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _FootStat(
                  label: 'Avg price',
                  value: r.visits.isEmpty
                      ? '–'
                      : PriceTier.signs(r.avgPrice.round())),
              _Sep(color: colors.line),
              _FootStat(
                  label: 'Visits', value: r.visitCount.toString()),
              _Sep(color: colors.line),
              _FootStat(
                label: 'Last visit',
                value: r.visits.isEmpty
                    ? '–'
                    : DateFormat.MMMd().format(
                        r.visits
                            .reduce((a, b) => a.date.isAfter(b.date) ? a : b)
                            .date,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar(
      {required this.label, required this.value, required this.text});
  final String label;
  final double value; // 0..10
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.subtle)),
            const Spacer(),
            Text(text,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
            Text('  /10',
                style: TextStyle(fontSize: 11, color: colors.subtle)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / 10).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          ),
        ),
      ],
    );
  }
}

class _FootStat extends StatelessWidget {
  const _FootStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, color: colors.subtle)),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: color);
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.onEdit,
    required this.onDelete,
  });

  final Visit visit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = DateFormat.yMMMd().format(visit.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(date,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 8),
              Icon(visit.isPrivate ? Icons.lock_outline : Icons.group_outlined,
                  size: 13, color: colors.subtle),
              const Spacer(),
              _MiniStat(label: 'Food', value: '${visit.foodRating}'),
              _MiniStat(label: 'Atmos', value: '${visit.atmosphereRating}'),
              _MiniStat(label: 'Price', value: PriceTier.signs(visit.price)),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
                icon: Icon(Icons.more_horiz, color: colors.subtle),
              ),
            ],
          ),
          if (visit.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...visit.items.map((it) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 5, color: colors.subtle),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(it.name,
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                      if (it.price != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Text('\$${it.price}',
                              style: TextStyle(
                                  fontSize: 12.5, color: colors.subtle)),
                        ),
                      if (it.rating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${it.rating}/10',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent)),
                        ),
                    ],
                  ),
                )),
          ],
          if (visit.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(visit.notes,
                style: TextStyle(
                    fontSize: 13, color: colors.subtle, height: 1.35)),
          ],
          if (visit.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visit.photoPaths
                  .map((p) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(p),
                            width: 72, height: 72, fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: TextStyle(fontSize: 10, color: colors.subtle)),
        ],
      ),
    );
  }
}
