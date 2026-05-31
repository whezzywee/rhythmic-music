import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PaletteColor {
  final Color color;
  final Color bodyTextColor;
  final Color titleTextColor;

  PaletteColor(
      {required this.color,
      required this.bodyTextColor,
      required this.titleTextColor});
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

  static Future<PaletteGenerator> _generatePalette(
      ui.Image image, int maxColors) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return PaletteGenerator._();
    }

    final result = await compute(_extractPaletteColors, {
      'pixels': Uint8List.fromList(byteData.buffer.asUint8List()),
      'width': image.width,
      'height': image.height,
      'maximumColorCount': maxColors,
    });

    final dominantValue = result['dominant'];
    if (dominantValue == null) {
      return PaletteGenerator._();
    }

    final dominant = Color(dominantValue);
    final paletteColor = PaletteColor(
      color: dominant,
      bodyTextColor: _textColorForBackground(dominant),
      titleTextColor: _textColorForBackground(dominant),
    );

    final lightVariant =
        Color(result['light'] ?? _adjustLightness(dominant, 0.15).toARGB32());
    final darkVariant =
        Color(result['dark'] ?? _adjustLightness(dominant, -0.15).toARGB32());

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

  static Color _textColorForBackground(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white70;
  }

  static Color _adjustLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _saturate(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation((hsl.saturation + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

Map<String, int?> _extractPaletteColors(Map<String, dynamic> request) {
  final pixels = request['pixels'] as Uint8List;
  final width = request['width'] as int;
  final height = request['height'] as int;
  final maximumColorCount = request['maximumColorCount'] as int;
  final colorCounts = <int, int>{};
  var sampled = 0;

  final pixelCount = width * height;
  final step = (pixelCount / 6000).ceil().clamp(1, 64);
  for (var pixelIndex = 0; pixelIndex < pixelCount; pixelIndex += step) {
    final offset = pixelIndex * 4;
    final r = pixels[offset];
    final g = pixels[offset + 1];
    final b = pixels[offset + 2];
    final a = pixels[offset + 3];
    if (a < 128) continue;

    final quantized = _quantizeColor(r, g, b);
    colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    sampled++;
  }

  if (colorCounts.isEmpty || sampled == 0) {
    return {'dominant': null, 'light': null, 'dark': null};
  }

  final candidates = colorCounts.entries.toList()
    ..sort((a, b) => _scoreColor(b.key, b.value, sampled)
        .compareTo(_scoreColor(a.key, a.value, sampled)));

  final capped = candidates.take(math.max(1, maximumColorCount)).toList();
  final dominant = capped.first.key;
  return {
    'dominant': dominant,
    'light': _shiftLightness(dominant, 0.15),
    'dark': _shiftLightness(dominant, -0.15),
  };
}

int _quantizeColor(int r, int g, int b) {
  final qr = ((r + 12) ~/ 24) * 24;
  final qg = ((g + 12) ~/ 24) * 24;
  final qb = ((b + 12) ~/ 24) * 24;
  return (0xFF << 24) |
      (qr.clamp(0, 255) << 16) |
      (qg.clamp(0, 255) << 8) |
      qb.clamp(0, 255);
}

double _scoreColor(int argb, int count, int sampled) {
  final color = Color(argb);
  final hsl = HSLColor.fromColor(color);
  final frequency = count / sampled;
  final saturation = hsl.saturation;
  final lightness = hsl.lightness;

  var score = frequency * (0.35 + saturation);
  score *= (1 - (lightness - 0.5).abs()).clamp(0.25, 1.0);

  if (saturation < 0.12) score *= 0.2;
  if (lightness < 0.08 || lightness > 0.92) score *= 0.15;
  if (lightness < 0.16 || lightness > 0.86) score *= 0.45;

  return score;
}

int _shiftLightness(int argb, double amount) {
  final hsl = HSLColor.fromColor(Color(argb));
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor()
      .toARGB32();
}
