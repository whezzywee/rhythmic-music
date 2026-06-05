import 'package:flutter/material.dart';

class NewAppTheme {
  static ThemeData dark() {
    const background = Color(0xFF101113);
    const surface = Color(0xFF181A1F);
    const surfaceHigh = Color(0xFF20242A);
    const primary = Color(0xFF54D6B5);
    const secondary = Color(0xFFFFB86B);
    const text = Color(0xFFF4F1EA);
    const muted = Color(0xFFA9B0B8);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: text,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.05,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: muted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text,
          fixedSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: const Color(0xFF07110E),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      extensions: const [
        NewAppColors(
          background: background,
          surface: surface,
          surfaceHigh: surfaceHigh,
          primary: primary,
          secondary: secondary,
          text: text,
          muted: muted,
        ),
      ],
    );
  }
}

class NewAppColors extends ThemeExtension<NewAppColors> {
  const NewAppColors({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.primary,
    required this.secondary,
    required this.text,
    required this.muted,
  });

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color primary;
  final Color secondary;
  final Color text;
  final Color muted;

  @override
  NewAppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? primary,
    Color? secondary,
    Color? text,
    Color? muted,
  }) {
    return NewAppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      text: text ?? this.text,
      muted: muted ?? this.muted,
    );
  }

  @override
  NewAppColors lerp(ThemeExtension<NewAppColors>? other, double t) {
    if (other is! NewAppColors) return this;
    return NewAppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}
