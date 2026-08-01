import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/pixel_animation.dart';
import 'color_convert.dart';

/// Stratégie d'ajustement d'une image/GIF importé(e) à la grille de travail
/// (voir specs.md §4.3). Dans les deux cas, l'image n'est jamais déformée.
enum ImageFitMode {
  /// Inclut l'image entière, quitte à laisser des bandes noires
  /// (letterbox/pillarbox) sur les bords.
  contain,

  /// Remplit toute la grille (la plus petite dimension colle aux bords),
  /// quitte à recadrer le surplus sur la plus grande dimension.
  cover,
}

/// Convertit une image/GIF importé(e) vers la résolution de travail basse
/// (voir specs.md §4.4/§4.5). Limite le nombre de frames pour rester raisonnable en BLE.
PixelAnimation decodeImageBytesToAnimation(
  Uint8List bytes, {
  required bool isGif,
  required int gridWidth,
  required int gridHeight,
  ImageFitMode fitMode = ImageFitMode.cover,
  int maxFrames = 30,
  int defaultFrameDelayMs = 120,
}) {
  final decoded = isGif ? img.decodeGif(bytes) : img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Image illisible.');
  }

  final sourceFrames = decoded.frames.isNotEmpty ? decoded.frames : [decoded];
  final limited = sourceFrames.take(maxFrames).toList();

  final frames = limited.map((frame) {
    final fitted = fitMode == ImageFitMode.contain
        ? _containToGrid(frame, gridWidth, gridHeight)
        : _coverToGrid(frame, gridWidth, gridHeight);
    return _toPixelFrame(fitted);
  }).toList();

  final firstDuration = limited.first.frameDuration;
  final delay = firstDuration > 0 ? firstDuration : defaultFrameDelayMs;

  return PixelAnimation(frames: frames, frameDelayMs: delay);
}

/// Redimensionne [source] pour l'inclure entièrement dans une grille
/// `gridWidth`x`gridHeight` sans la déformer (letterbox/pillarbox), au lieu
/// d'étirer l'image pour remplir exactement le cadre.
img.Image _containToGrid(img.Image source, int gridWidth, int gridHeight) {
  final scale = (gridWidth / source.width < gridHeight / source.height)
      ? gridWidth / source.width
      : gridHeight / source.height;
  final fittedWidth = (source.width * scale).round().clamp(1, gridWidth);
  final fittedHeight = (source.height * scale).round().clamp(1, gridHeight);

  final resized = img.copyResize(
    source,
    width: fittedWidth,
    height: fittedHeight,
    interpolation: img.Interpolation.average,
  );

  final canvas = img.Image(
    width: gridWidth,
    height: gridHeight,
    numChannels: 3,
  );
  img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
  img.compositeImage(canvas, resized, center: true);
  return canvas;
}

/// Redimensionne [source] pour remplir entièrement une grille
/// `gridWidth`x`gridHeight` sans la déformer, en recadrant le surplus sur la
/// plus grande dimension (la plus petite dimension colle aux bords).
img.Image _coverToGrid(img.Image source, int gridWidth, int gridHeight) {
  final scale = (gridWidth / source.width > gridHeight / source.height)
      ? gridWidth / source.width
      : gridHeight / source.height;
  final scaledWidth = max((source.width * scale).round(), gridWidth);
  final scaledHeight = max((source.height * scale).round(), gridHeight);

  final resized = img.copyResize(
    source,
    width: scaledWidth,
    height: scaledHeight,
    interpolation: img.Interpolation.average,
  );

  return img.copyCrop(
    resized,
    x: ((scaledWidth - gridWidth) / 2).round(),
    y: ((scaledHeight - gridHeight) / 2).round(),
    width: gridWidth,
    height: gridHeight,
  );
}

PixelFrame _toPixelFrame(img.Image image) {
  final pixels = Uint8List(image.width * image.height * 2);
  var i = 0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final rgb565 = rgbToRgb565(
        pixel.r.toInt(),
        pixel.g.toInt(),
        pixel.b.toInt(),
      );
      pixels[i++] = (rgb565 >> 8) & 0xFF;
      pixels[i++] = rgb565 & 0xFF;
    }
  }
  return PixelFrame(
    width: image.width,
    height: image.height,
    pixelsRgb565: pixels,
  );
}
