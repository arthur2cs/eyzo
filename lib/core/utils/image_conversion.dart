import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/pixel_animation.dart';
import 'color_convert.dart';

/// Convertit une image/GIF importé(e) vers la résolution de travail basse
/// (voir specs.md §4.4/§4.5). Limite le nombre de frames pour rester raisonnable en BLE.
PixelAnimation decodeImageBytesToAnimation(
  Uint8List bytes, {
  required bool isGif,
  required int gridWidth,
  required int gridHeight,
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
    final resized = img.copyResize(
      frame,
      width: gridWidth,
      height: gridHeight,
      interpolation: img.Interpolation.average,
    );
    return _toPixelFrame(resized);
  }).toList();

  final firstDuration = limited.first.frameDuration;
  final delay = firstDuration > 0 ? firstDuration : defaultFrameDelayMs;

  return PixelAnimation(frames: frames, frameDelayMs: delay);
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
