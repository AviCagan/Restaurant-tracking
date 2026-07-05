import 'package:flutter/services.dart';

import '../data/app_prefs.dart';

/// Central haptics that respect the user's strength setting
/// (Settings → Haptics: 0 off, 1 light, 2 medium, 3 strong).
class Haptics {
  /// Small UI taps (selecting a tab, a chip, a tier).
  static void tick() {
    switch (AppPrefs.hapticStrength.value) {
      case 0:
        return;
      case 1:
      case 2:
        HapticFeedback.selectionClick();
      case 3:
        HapticFeedback.mediumImpact();
    }
  }

  /// Rating-bar steps — the satisfying one.
  static void step() {
    switch (AppPrefs.hapticStrength.value) {
      case 0:
        return;
      case 1:
        HapticFeedback.selectionClick();
      case 2:
        HapticFeedback.mediumImpact();
      case 3:
        HapticFeedback.heavyImpact();
    }
  }
}
