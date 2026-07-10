import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import '../data/app_prefs.dart';
import 'web_bridge/web_bridge.dart' as web;

/// Central haptics that respect the user's strength setting
/// (Settings → Haptics: 0 off, 1 light, 2 medium, 3 strong).
///
/// On the web the browser Vibration API buzzes Android phones (iPhones
/// don't expose vibration to browsers, so web haptics are Android-only).
class Haptics {
  /// Small UI taps (selecting a tab, a chip, a tier).
  static void tick() {
    final strength = AppPrefs.hapticStrength.value;
    if (strength == 0) return;
    if (kIsWeb) {
      web.vibrate(strength == 3 ? 20 : 10);
      return;
    }
    switch (strength) {
      case 1:
      case 2:
        HapticFeedback.selectionClick();
      case 3:
        HapticFeedback.mediumImpact();
    }
  }

  /// Rating-bar steps — the satisfying one.
  static void step() {
    final strength = AppPrefs.hapticStrength.value;
    if (strength == 0) return;
    if (kIsWeb) {
      web.vibrate(switch (strength) {
        1 => 10,
        2 => 20,
        _ => 35,
      });
      return;
    }
    switch (strength) {
      case 1:
        HapticFeedback.selectionClick();
      case 2:
        HapticFeedback.mediumImpact();
      case 3:
        HapticFeedback.heavyImpact();
    }
  }
}
