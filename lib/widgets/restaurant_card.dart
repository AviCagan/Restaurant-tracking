import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// A single row in the list: photo (left), name + address + visit count
/// (middle), averaged rating (right).
class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.onLongPress,
    this.distanceMeters,
  });

  final Restaurant restaurant;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
        boxShadow: AppTheme.shadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Cover(restaurant: restaurant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              restaurant.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (restaurant.isFavorite) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.favorite,
                                size: 14, color: AppTheme.accent),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        restaurant.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, color: colors.subtle, height: 1.25),
                      ),
                      if (restaurant.isChain &&
                          restaurant.locationDescriptor != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place,
                                size: 12, color: AppTheme.accent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                restaurant.locationDescriptor!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    height: 1.2,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Pill(
                            icon: Icons.event_repeat_outlined,
                            label: restaurant.visitCount == 1
                                ? '1 visit'
                                : '${restaurant.visitCount} visits',
                          ),
                          if (restaurant.avgPrice > 0)
                            _Pill(
                              icon: Icons.payments_outlined,
                              label:
                                  PriceTier.signs(restaurant.avgPrice.round()),
                            ),
                          if (distanceMeters != null)
                            _Pill(
                              icon: Icons.near_me_outlined,
                              label: _formatDistance(distanceMeters!),
                            ),
                        ],
                      ),
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
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = colors.subtle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = 74.0;
    Widget child;

    final cover = restaurant.coverImage;
    if (cover == null || cover.isEmpty) {
      child = Container(
        color: colors.background,
        child: Icon(Icons.restaurant, color: colors.subtle),
      );
    } else if (restaurant.coverIsLocalFile) {
      child = Image.file(File(cover),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _broken(colors));
    } else {
      child = CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: colors.background),
        errorWidget: (_, __, ___) => _broken(colors),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _broken(AppColors colors) => Container(
        color: colors.background,
        child: Icon(Icons.image_not_supported_outlined, color: colors.subtle),
      );
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = (value / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF34C759), t)!;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.92), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(text,
            style: AppTheme.heading(21, color: Colors.white)),
      ),
    );
  }
}
