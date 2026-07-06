import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors that adapt between light and dark themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color ink; // primary text
  final Color subtle; // secondary text / icons
  final Color line; // borders / dividers
  final Color surface; // cards
  final Color background; // scaffold

  const AppColors({
    required this.ink,
    required this.subtle,
    required this.line,
    required this.surface,
    required this.background,
  });

  @override
  AppColors copyWith({
    Color? ink,
    Color? subtle,
    Color? line,
    Color? surface,
    Color? background,
  }) =>
      AppColors(
        ink: ink ?? this.ink,
        subtle: subtle ?? this.subtle,
        line: line ?? this.line,
        surface: surface ?? this.surface,
        background: background ?? this.background,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      ink: Color.lerp(ink, other.ink, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      line: Color.lerp(line, other.line, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      background: Color.lerp(background, other.background, t)!,
    );
  }

  // "Cozy kitchen" palette — warm cream, cocoa text, peachy warmth.
  static const light = AppColors(
    ink: Color(0xFF4A3B32), // warm cocoa
    subtle: Color(0xFFA38F80), // latte
    line: Color(0xFFF0E3D3), // biscuit
    surface: Color(0xFFFFFDFA),
    background: Color(0xFFFFF6EA), // warm cream
  );

  static const dark = AppColors(
    ink: Color(0xFFF6ECE1),
    subtle: Color(0xFFB5A294),
    line: Color(0xFF3C2F26),
    surface: Color(0xFF2B211A),
    background: Color(0xFF201812), // warm espresso
  );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// A selectable accent palette.
class ThemePalette {
  final String name;
  final Color accent;
  final Color accentDark;
  const ThemePalette(this.name, this.accent, this.accentDark);
}

const List<ThemePalette> kPalettes = [
  ThemePalette('Peach', Color(0xFFF07A4B), Color(0xFFD65F31)),
  ThemePalette('Berry', Color(0xFFE85D8A), Color(0xFFC94570)),
  ThemePalette('Sage', Color(0xFF6FA57C), Color(0xFF54835F)),
  ThemePalette('Ocean', Color(0xFF4C93C9), Color(0xFF3574A6)),
  ThemePalette('Grape', Color(0xFF9B6BC7), Color(0xFF7E4FA8)),
  ThemePalette('Sunny', Color(0xFFE8A21D), Color(0xFFC68608)),
];

/// Warm, friendly, cozy theme (light + dark).
class AppTheme {
  // Mutable so the user can pick a palette in Customize. Set via [usePalette].
  static Color accent = const Color(0xFFF07A4B);
  static Color accentDark = const Color(0xFFD65F31);
  static const Color honey = Color(0xFFFFC24B);
  static const Color sage = Color(0xFF8FBA96);

  static void usePalette(int index) {
    final p = kPalettes[index.clamp(0, kPalettes.length - 1)];
    accent = p.accent;
    accentDark = p.accentDark;
  }

  /// Chubby rounded display font for headings & big numbers.
  static TextStyle heading(double size,
          {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.baloo2(
          fontSize: size, fontWeight: weight, color: color, height: 1.15);

  static Gradient get accentGradient => LinearGradient(
        colors: [Color.lerp(accent, Colors.white, 0.30)!, accent],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    // Quicksand: soft, rounded, easy on the eyes.
    final textTheme = GoogleFonts.quicksandTextTheme(base.textTheme).apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: honey,
        surface: c.surface,
        onSurface: c.ink,
      ),
      extensions: [c],
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: _SoftSlidePageTransitionsBuilder(),
        TargetPlatform.iOS: _SoftSlidePageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.baloo2(
          color: c.ink,
          fontSize: 26,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: TextStyle(color: c.subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surface,
        side: BorderSide(color: c.line),
        labelStyle: TextStyle(
            color: c.ink, fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      dividerTheme: DividerThemeData(color: c.line, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Soft warm glow shadow — cozy, not techy.
  static List<BoxShadow> shadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.35)
            : const Color(0xFFDBA06A).withValues(alpha: 0.20),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// The signature soft card decoration.
  static BoxDecoration panel(BuildContext context,
      {Color? color, double radius = 24}) {
    final c = context.colors;
    return BoxDecoration(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.line, width: 1.5),
      boxShadow: shadow(context),
    );
  }
}

/// Gentle slide-up + fade route transition (replaces the stock zoom).
class _SoftSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.045), end: Offset.zero)
            .animate(curved),
        child: child,
      ),
    );
  }
}
