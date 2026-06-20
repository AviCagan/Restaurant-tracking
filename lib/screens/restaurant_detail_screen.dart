import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/restaurant_database.dart';
import '../models/category.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';
import 'add_rating_screen.dart';

class RestaurantDetailScreen extends StatefulWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  late Restaurant _r = widget.restaurant;
  bool _changed = false;

  Future<void> _edit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddRatingScreen(existing: _r)),
    );
    if (updated == true) {
      // Reload the freshest copy.
      final all = await RestaurantDatabase.instance.getAll();
      Restaurant? fresh;
      for (final e in all) {
        if (e.id == _r.id) {
          fresh = e;
          break;
        }
      }
      if (fresh != null && mounted) {
        setState(() {
          _r = fresh!;
          _changed = true;
        });
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete rating?'),
        content: Text('Remove "${_r.name}" from your list?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await RestaurantDatabase.instance.delete(_r.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cover = _r.coverImage;
    final cats = FoodCategory.fromKeys(_r.categoryKeys);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _changed);
      },
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: cover != null ? 240 : 0,
                pinned: true,
                backgroundColor: AppTheme.background,
                actions: [
                  IconButton(
                      onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                      onPressed: _delete,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_r.name,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(_r.address,
                          style: const TextStyle(
                              color: AppTheme.subtle, fontSize: 14)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _Stat(
                              label: 'Food',
                              value: '${_r.foodRating}/10'),
                          _Stat(
                              label: 'Atmosphere',
                              value: '${_r.atmosphereRating}/10'),
                          _Stat(label: 'Price', value: '\$${_r.price}'),
                          _Stat(
                              label: 'Overall',
                              value: _r.overallRating
                                  .toStringAsFixed(
                                      _r.overallRating == _r.overallRating.roundToDouble()
                                          ? 0
                                          : 1)),
                        ],
                      ),
                      if (cats.isNotEmpty) ...[
                        const SizedBox(height: 22),
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
                      if (_r.notes.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Notes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_r.notes,
                            style: const TextStyle(height: 1.4, fontSize: 14)),
                      ],
                      if (_r.mediaPaths.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Photos',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _r.mediaPaths.map((path) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(File(path),
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover),
                            );
                          }).toList(),
                        ),
                      ],
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

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.subtle)),
        ],
      ),
    );
  }
}
