import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// A sleek bottom sheet for picking a 1–10 rating (or clearing it).
///
/// Returns: `null` if dismissed, `0` to clear, or `1..10` for a rating.
class RatingPickerSheet extends StatelessWidget {
  const RatingPickerSheet({super.key, required this.title, this.current});

  final String title;
  final int? current;

  static Future<int?> show(BuildContext context,
      {required String title, int? current}) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => RatingPickerSheet(title: title, current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tap a score',
                style: TextStyle(fontSize: 13, color: colors.subtle)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(10, (i) {
                final n = i + 1;
                final selected = n == current;
                // Amber → green gradient as the number rises.
                final t = i / 9;
                final color = Color.lerp(
                    const Color(0xFFF5A623), const Color(0xFF34C759), t)!;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pop(context, n);
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: selected
                          ? color
                          : color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : color,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, 0),
                icon: Icon(Icons.not_interested, size: 18, color: colors.subtle),
                label: Text('No rating',
                    style: TextStyle(color: colors.subtle)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
