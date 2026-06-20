import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/social_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_prompt.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: ValueListenableBuilder<UserProfile?>(
        valueListenable: AuthService.user,
        builder: (context, user, _) {
          if (user == null) {
            return const SignInPrompt(
                message:
                    'See what your friends are eating and rating in one feed.');
          }
          final items = SocialService.feed();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              const _PreviewBanner(),
              const SizedBox(height: 12),
              ...items.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeedCard(item: f),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Preview — sample feed. Real friend syncing comes with Firebase.',
              style: TextStyle(fontSize: 12, color: colors.subtle),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});
  final FeedItem item;

  String _ago(DateTime t) {
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
              _Avatar(name: item.friendName),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(color: colors.ink, fontSize: 14),
                        children: [
                          TextSpan(
                              text: item.friendName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                          const TextSpan(text: '  rated  '),
                          TextSpan(
                              text: item.restaurantName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${item.location} · ${_ago(item.when)}',
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final initials = p.isEmpty
        ? '?'
        : (p.length == 1
            ? p.first.substring(0, 1)
            : p.first.substring(0, 1) + p.last.substring(0, 1));
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(initials.toUpperCase(),
            style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ),
    );
  }
}
