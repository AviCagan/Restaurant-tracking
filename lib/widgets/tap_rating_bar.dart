import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../services/haptics.dart';

/// A fast, satisfying 1–10 rating control: tap or drag across the segments.
/// Segments fill with an amber→green gradient, each step fires a heavy haptic,
/// and the big number pops when it changes.
class TapRatingBar extends StatefulWidget {
  const TapRatingBar({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.emoji,
  });

  final String label;
  final String? emoji;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<TapRatingBar> createState() => _TapRatingBarState();
}

class _TapRatingBarState extends State<TapRatingBar> {
  static const _words = [
    '', 'Awful', 'Bad', 'Meh', 'Okay', 'Decent', //
    'Good', 'Great', 'Excellent', 'Amazing', 'Perfect',
  ];

  Color _color(double t) =>
      Color.lerp(const Color(0xFFF5A623), const Color(0xFF3FB55D), t)!;

  void _setFromDx(double dx, double width) {
    var i = (dx / width * 10).ceil();
    if (i < 1) i = 1;
    if (i > 10) i = 10;
    if (i != widget.value) {
      Haptics.step();
      widget.onChanged(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = _color(widget.value / 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.emoji != null) ...[
              Text(widget.emoji!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
            ],
            Text(widget.label,
                style: AppTheme.heading(18, color: colors.ink)),
            const Spacer(),
            Text(_words[widget.value],
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color)),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              key: ValueKey(widget.value),
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Text('${widget.value}',
                  style: AppTheme.heading(28, color: color)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _setFromDx(d.localPosition.dx, c.maxWidth),
              onHorizontalDragUpdate: (d) =>
                  _setFromDx(d.localPosition.dx, c.maxWidth),
              child: SizedBox(
                height: 26,
                child: Row(
                  children: List.generate(10, (i) {
                    final filled = i < widget.value;
                    final segColor = _color((i + 1) / 10);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOut,
                          height: filled ? 24 : 14,
                          decoration: BoxDecoration(
                            color: filled ? segColor : colors.line,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
