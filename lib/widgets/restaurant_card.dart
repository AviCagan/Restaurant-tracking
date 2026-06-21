import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// A restaurant in the list: a chunky "paper" card with the score badge
/// overlapping the photo corner.
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
      decoration: AppTheme.panel(context),
      clipBehavior: Clip.none,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                _CoverWithBadge(restaurant: restaurant),
                const SizedBox(width: 16),
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
                              style: AppTheme.heading(19, color: colors.ink),
                            ),
                          ),
                          if (restaurant.isFavorite) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.favorite,
                                size: 14, color: AppTheme.accent),
                          ],
                        ],
                      ),
                      if (restaurant.isChain &&
                          restaurant.locationDescriptor != null) ...[
                        const SizedBox(height: 3),
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
                      ] else ...[
                        const SizedBox(height: 3),
                        Text(
                          restaurant.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: colors.subtle,
                              height: 1.25),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Tag(
                            icon: Icons.event_repeat_outlined,
                            label: restaurant.visitCount == 1
                                ? '1 visit'
                                : '${restaurant.visitCount} visits',
                          ),
                          if (restaurant.avgPrice > 0)
                            _Tag(
                              icon: Icons.payments_outlined,
                              label:
                                  PriceTier.signs(restaurant.avgPrice.round()),
                            ),
                          if (distanceMeters != null)
                            _Tag(
                              icon: Icons.near_me_outlined,
                              label: _formatDistance(distanceMeters!),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.subtle),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: colors.subtle,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CoverWithBadge extends StatelessWidget {
  const _CoverWithBadge({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const size = 84.0;

    final cover = restaurant.coverImage;
    Widget img;
    if (cover == null || cover.isEmpty) {
      img = Container(
        color: colors.background,
        child: Icon(Icons.restaurant, color: colors.subtle),
      );
    } else if (restaurant.coverIsLocalFile) {
      img = Image.file(File(cover),
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => _broken(colors));
    } else {
      img = CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: colors.background),
        errorWidget: (_, __, ___) => _broken(colors),
      );
    }

    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.ink.withValues(alpha: 0.13),
                  width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: img,
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: _ScoreBadge(value: restaurant.overallRating),
          ),
        ],
      ),
    );
  }

  Widget _broken(AppColors colors) => Container(
        color: colors.background,
        child: Icon(Icons.image_not_supported_outlined, color: colors.subtle),
      );
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = (value / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF3FB55D), t)!;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.92), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.surface, width: 2.5),
      ),
      child: Center(
        child: Text(text, style: AppTheme.heading(16, color: Colors.white)),
      ),
    );
  }
}
