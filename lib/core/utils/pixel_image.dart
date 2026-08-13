import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../models/pixel_animation.dart';

/// Décode un [PixelFrame] (RGB565 big-endian, voir specs.md §6.3) en
/// [ui.Image] affichable. Utilisé pour que les aperçus montrent **le bitmap
/// réellement envoyé aux lunettes** (voir text_bitmap_renderer.dart) plutôt
/// qu'un second rendu indépendant — y compris la perte de précision propre
/// au RGB565 (5/6/5 bits), pour que l'aperçu reste fidèle même sur ce détail.
Future<ui.Image> pixelFrameToImage(PixelFrame frame) {
  final pixels = frame.pixelsRgb565;
  final rgba = Uint8List(frame.width * frame.height * 4);
  var o = 0;
  for (var i = 0; i < pixels.length; i += 2) {
    final rgb565 = (pixels[i] << 8) | pixels[i + 1];
    final r = (rgb565 >> 11) & 0x1F;
    final g = (rgb565 >> 5) & 0x3F;
    final b = rgb565 & 0x1F;
    rgba[o++] = (r * 255 / 31).round();
    rgba[o++] = (g * 255 / 63).round();
    rgba[o++] = (b * 255 / 31).round();
    rgba[o++] = 0xFF;
  }

  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
