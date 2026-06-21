import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/price_tier.dart';
import '../models/restaurant.dart';
import '../theme/app_theme.dart';

/// A bold, photo-forward restaurant card: a big banner photo with the name
/// overlaid and a floating score badge, info tags underneath.
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
    return Container(
      decoration: AppTheme.panel(context, radius: 24),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Banner(restaurant: restaurant),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                        label: PriceTier.signs(restaurant.avgPrice.round()),
                      ),
                    if (restaurant.isChain &&
                        restaurant.chainName != null)
                      _Tag(
                        icon: Icons.storefront_outlined,
                        label: restaurant.chainName!,
                      ),
                    if (distanceMeters != null)
                      _Tag(
                        icon: Icons.near_me_outlined,
                        label: _formatDistance(distanceMeters!),
                      ),
                  ],
                ),
              ),
            ],
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

class _Banner extends StatelessWidget {
  const _Banner({required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final cover = restaurant.coverImage;
    final subtitle = restaurant.isChain && restaurant.locationDescriptor != null
        ? restaurant.locationDescriptor!
        : restaurant.address;

    Widget image;
    if (cover == null || cover.isEmpty) {
      image = const _PlaceholderBanner();
    } else if (restaurant.coverIsLocalFile) {
      image = Image.file(File(cover),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _PlaceholderBanner());
    } else {
      image = CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        placeholder: (_, __) => const _PlaceholderBanner(),
        errorWidget: (_, __, ___) => const _PlaceholderBanner(),
      );
    }

    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // Dark scrim for legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.45, 1.0],
              ),
            ),
          ),
          // Name + subtitle
          Positioned(
            left: 14,
            right: 72,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.heading(21, color: Colors.white),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          // Score badge
          Positioned(
            top: 12,
            right: 12,
            child: _ScoreBadge(value: restaurant.overallRating),
          ),
          // Favorite heart
          if (restaurant.isFavorite)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite,
                    size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlaceholderBanner extends StatelessWidget {
  const _PlaceholderBanner();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFEFA98A), Color(0xFFE2785A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Text('🍽️', style: TextStyle(fontSize: 44))),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final t = (value / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF3FB55D), t)!;
    final text = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);

    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.92), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(text, style: AppTheme.heading(19, color: Colors.white)),
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.subtle),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11.5,
                  color: colors.subtle,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
