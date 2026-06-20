import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Intensity of the tick that fires as the slider crosses each step.
enum SliderHaptic { heavy, light }

/// A labelled slider that fires a haptic tick on every step change —
/// making it satisfying to drag back and forth.
class HapticSlider extends StatefulWidget {
  const HapticSlider({
    super.key,
    required this.label,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.haptic,
    required this.onChanged,
    this.valueLabelBuilder,
    this.accent = AppTheme.accent,
  });

  final String label;
  final String? subtitle;
  final int value;
  final int min;
  final int max;
  final int step;
  final SliderHaptic haptic;
  final ValueChanged<int> onChanged;

  /// Custom formatter for the big value chip (e.g. add a "$").
  final String Function(int)? valueLabelBuilder;
  final Color accent;

  @override
  State<HapticSlider> createState() => _HapticSliderState();
}

class _HapticSliderState extends State<HapticSlider> {
  late int _lastStep;

  @override
  void initState() {
    super.initState();
    _lastStep = widget.value;
  }

  void _fireHaptic() {
    switch (widget.haptic) {
      case SliderHaptic.heavy:
        HapticFeedback.heavyImpact();
        break;
      case SliderHaptic.light:
        HapticFeedback.selectionClick();
        break;
    }
  }

  void _handleChange(double raw) {
    // Snap to the nearest step.
    var clamped = (raw / widget.step).round() * widget.step;
    if (clamped < widget.min) clamped = widget.min;
    if (clamped > widget.max) clamped = widget.max;
    if (clamped != _lastStep) {
      _lastStep = clamped;
      _fireHaptic();
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final divisions = ((widget.max - widget.min) / widget.step).round();
    final valueText = widget.valueLabelBuilder?.call(widget.value) ??
        widget.value.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.subtle, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: widget.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                valueText,
                style: TextStyle(
                  color: widget.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: widget.accent,
            inactiveTrackColor: widget.accent.withOpacity(0.15),
            thumbColor: widget.accent,
            overlayColor: widget.accent.withOpacity(0.15),
            trackHeight: 5,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 11),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: Slider(
            value: widget.value.toDouble(),
            min: widget.min.toDouble(),
            max: widget.max.toDouble(),
            divisions: divisions,
            onChanged: _handleChange,
          ),
        ),
      ],
    );
  }
}
