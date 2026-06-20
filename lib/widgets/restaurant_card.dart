import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// A single row in the list: photo (left), name + address (middle),
/// rating (right).
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.distanceMeters,
  });

  final Restaurant restaurant;
  final VoidCallback? onTap;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _Cover(restaurant: restaurant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.subtle,
                          height: 1.25,
                        ),
                      ),
                      if (distanceMeters != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDistance(distanceMeters!),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _RatingBadge(value: restaurant.overallRating),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m away';
    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    const size = 74.0;
    Widget child;

    final cover = restaurant.coverImage;
    if (cover == null || cover.isEmpty) {
      child = Container(
        color: AppTheme.background,
        child: const Icon(Icons.restaurant, color: AppTheme.subtle),
      );
    } else if (restaurant.coverIsLocalFile) {
      child = Image.file(File(cover), fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _broken());
    } else {
      child = CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppTheme.background),
        errorWidget: (_, __, ___) => _broken(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _broken() => Container(
        color: AppTheme.background,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppTheme.subtle),
      );
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    // Color shifts from amber to green as the score rises.
    final t = (value / 10).clamp(0.0, 1.0);
    final color = Color.lerp(const Color(0xFFF5A623), const Color(0xFF34C759), t)!;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 19,
          ),
        ),
      ),
    );
  }
}
