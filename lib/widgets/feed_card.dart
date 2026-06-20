import 'package:flutter/material.dart';

import '../data/social_service.dart';
import '../theme/app_theme.dart';

/// Avatar circle showing a person's initials.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.name, this.size = 42});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = p.isEmpty
        ? '?'
        : (p.length == 1
            ? p.first.substring(0, 1)
            : p.first.substring(0, 1) + p.last.substring(0, 1));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials.toUpperCase(),
            style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36)),
      ),
    );
  }
}

/// A friend's shared rating, shown in feeds and on friend profiles.
class FeedCard extends StatelessWidget {
  const FeedCard({super.key, required this.item, this.showWho = true});
  final FeedItem item;
  final bool showWho;

  static String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inDays >= 1) return '${d.inDays}d ago';
    if (d.inHours >= 1) return '${d.inHours}h ago';
    if (d.inMinutes >= 1) return '${d.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final t = (item.rating / 10).clamp(0.0, 1.0);
    final color =
        Color.lerp(const Color(0xFFF5A623), const Color(0xFF34C759), t)!;

    return Container(
      padding: const EdgeInsets.all(14),
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
              if (showWho) ...[
                PersonAvatar(name: item.friendName),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showWho)
                      RichText(
                        text: TextSpan(
                          style: TextStyle(color: colors.ink, fontSize: 14),
                          children: [
                            TextSpan(
                                text: item.friendName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const TextSpan(text: '  rated  '),
                            TextSpan(
                                text: item.restaurantName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      )
                    else
                      Text(item.restaurantName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('${item.location} · ${ago(item.when)}',
                        style: TextStyle(fontSize: 12, color: colors.subtle)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    item.rating == item.rating.roundToDouble()
                        ? item.rating.toStringAsFixed(0)
                        : item.rating.toStringAsFixed(1),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 17),
                  ),
                ),
              ),
            ],
          ),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(item.note,
                style: TextStyle(fontSize: 13, color: colors.ink, height: 1.3)),
          ],
        ],
      ),
    );
  }
}
