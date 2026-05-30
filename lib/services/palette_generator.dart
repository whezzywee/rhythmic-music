import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PaletteColor {
  final Color color;
  final Color bodyTextColor;
  final Color titleTextColor;

  PaletteColor({required this.color, required this.bodyTextColor, required this.titleTextColor});
}

class PaletteGenerator {
  final PaletteColor? dominantColor;
  final PaletteColor? darkMutedColor;
  final PaletteColor? darkVibrantColor;
  final PaletteColor? lightMutedColor;
  final PaletteColor? lightVibrantColor;

  PaletteGenerator._({
    this.dominantColor,
    this.darkMutedColor,
    this.darkVibrantColor,
    this.lightMutedColor,
    this.lightVibrantColor,
  });

  static Future<PaletteGenerator> fromImageProvider(
    ImageProvider provider, {
    Size? size,
    int maximumColorCount = 16,
  }) async {
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    ImageStreamListener? listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool sync) {
        completer.complete(info.image);
        stream.removeListener(listener!);
      },
      onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
        stream.removeListener(listener!);
      },
    );
    stream.addListener(listener);

    final image = await completer.future;
    final palette = await _generatePalette(image, maximumColorCount);
    image.dispose();
    return palette;
  }

  static Future<PaletteGenerator> _generatePalette(ui.Image image, int maxColors) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return PaletteGenerator._();
    }

    final pixels = byteData.buffer.asUint32List();
    final colorCounts = <int, int>{};

    final width = image.width;
    final height = image.height;

    final step = ((width * height) / 10000).ceil().clamp(1, 64);
    for (int i = 0; i < pixels.length; i += step) {
      final pixel = pixels[i];
      final a = (pixel >> 24) & 0xFF;
      if (a < 128) continue;
      final r = (pixel >> 16) & 0xFF;
      final g = (pixel >> 8) & 0xFF;
      final b = pixel & 0xFF;
      final quantized = _quantizeColor(r, g, b);
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }

    if (colorCounts.isEmpty) {
      return PaletteGenerator._();
    }

    final sorted = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dominant = _entryToColor(sorted[0].key);
    final paletteColor = PaletteColor(
      color: dominant,
      bodyTextColor: _textColorForBackground(dominant),
      titleTextColor: _textColorForBackground(dominant),
    );

    final lightVariant = _adjustLightness(dominant, 0.15);
    final darkVariant = _adjustLightness(dominant, -0.15);

    return PaletteGenerator._(
      dominantColor: paletteColor,
      darkMutedColor: PaletteColor(
        color: darkVariant,
        bodyTextColor: _textColorForBackground(darkVariant),
        titleTextColor: _textColorForBackground(darkVariant),
      ),
      darkVibrantColor: PaletteColor(
        color: _saturate(darkVariant, 0.1),
        bodyTextColor: _textColorForBackground(darkVariant),
        titleTextColor: _textColorForBackground(darkVariant),
      ),
      lightMutedColor: PaletteColor(
        color: lightVariant,
        bodyTextColor: _textColorForBackground(lightVariant),
        titleTextColor: _textColorForBackground(lightVariant),
      ),
      lightVibrantColor: PaletteColor(
        color: _saturate(lightVariant, 0.1),
        bodyTextColor: _textColorForBackground(lightVariant),
        titleTextColor: _textColorForBackground(lightVariant),
      ),
    );
  }

  static int _quantizeColor(int r, int g, int b) {
    final qr = ((r + 15) ~/ 32) * 32;
    final qg = ((g + 15) ~/ 32) * 32;
    final qb = ((b + 15) ~/ 32) * 32;
    return (0xFF << 24) | (qr << 16) | (qg << 8) | qb;
  }

  static Color _entryToColor(int argb) {
    return Color(argb);
  }

  static Color _textColorForBackground(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white70;
  }

  static Color _adjustLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static Color _saturate(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation + amount).clamp(0.0, 1.0)).toColor();
  }
}
