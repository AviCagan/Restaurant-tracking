import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Semantic colors that adapt between light and dark themes.
///
/// Widgets read these via `context.colors.subtle` etc. The brand [accent]
/// stays constant across themes and lives on [AppTheme].
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

  static const light = AppColors(
    ink: Color(0xFF3D3833), // warm dark
    subtle: Color(0xFF9C9088), // warm gray
    line: Color(0xFFECE3D8),
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFFBF6F0), // warm cream
  );

  static const dark = AppColors(
    ink: Color(0xFFF0E8DF),
    subtle: Color(0xFFA89E93),
    line: Color(0xFF302A22),
    surface: Color(0xFF211C16),
    background: Color(0xFF15110D), // warm near-black
  );
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Sleek, modern, low-clutter theme (light + dark).
class AppTheme {
  static const Color accent = Color(0xFFE2785A); // warm terracotta
  static const Color accentDark = Color(0xFFC9603C);
  static const Color honey = Color(0xFFF2B705); // warm highlight
  static const Color sage = Color(0xFF7FA98A); // friendly green

  /// Friendly rounded display font for headings & big numbers.
  static TextStyle heading(double size,
          {Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.fredoka(
          fontSize: size, fontWeight: weight, color: color, letterSpacing: 0.2);

  static const Gradient accentGradient = LinearGradient(
    colors: [Color(0xFFEC8A5E), accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);
    // Nunito: rounded, friendly, easy on the eyes.
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    );

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: accent,
        surface: c.surface,
        onSurface: c.ink,
      ),
      extensions: [c],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          color: c.ink,
          fontSize: 27,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: c.ink),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: c.subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.6),
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
    );
  }

  /// Hard "sticker" drop shadow (no blur) — the app's signature card look.
  static List<BoxShadow> shadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: dark
            ? Colors.black.withValues(alpha: 0.55)
            : const Color(0xFF7A5230).withValues(alpha: 0.16),
        blurRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// The signature "paper" card decoration: solid border + hard shadow.
  static BoxDecoration panel(BuildContext context,
      {Color? color, double radius = 22}) {
    final c = context.colors;
    return BoxDecoration(
      color: color ?? c.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: c.ink.withValues(alpha: 0.13), width: 1.5),
      boxShadow: shadow(context),
    );
  }
}
