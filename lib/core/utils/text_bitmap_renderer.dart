import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/pixel_animation.dart';
import '../../models/scroll_direction_mode.dart';
import '../../models/text_content.dart';
import '../glasses_display.dart';
import 'color_convert.dart';
import 'text_style.dart';

/// Bitmap RGB565 rendu à partir d'un [TextContent], rendu pixel-identique à
/// l'aperçu de composition (voir [textStyleFor]) : le firmware n'a plus qu'à
/// afficher/défiler ce bitmap tel quel (voir specs.md §6.3), il ne rend plus
/// aucune police lui-même — ce qui élimine le décalage taille/police entre
/// l'aperçu app et l'affichage réel sur les lunettes.
class TextBitmap {
  const TextBitmap({required this.frame, required this.colorBgRgb565});

  /// Statique/clignotant : plein écran (`GlassesDisplay.nativeWidth` x
  /// `nativeHeight`), fond déjà peint. Défilement : largeur = texte seul
  /// (`nativeHeight` de haut), le fond est peint par le firmware à chaque
  /// pas de défilement (voir [colorBgRgb565]).
  final PixelFrame frame;

  final int colorBgRgb565;
}

bool _isScrolling(TextContent content) =>
    content.direction == ScrollDirectionMode.leftward ||
    content.direction == ScrollDirectionMode.rightward;

Future<TextBitmap> renderTextBitmap(TextContent content) async {
  final style = textStyleFor(content);
  final painter = TextPainter(
    text: TextSpan(text: content.renderedText, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();

  final scrolling = _isScrolling(content);
  const height = GlassesDisplay.nativeHeight;
  final width = scrolling
      ? painter.width.ceil().clamp(1, 1 << 20)
      : GlassesDisplay.nativeWidth;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = content.colorBg,
  );
  final dx = scrolling ? 0.0 : (width - painter.width) / 2;
  final dy = (height - painter.height) / 2;
  painter.paint(canvas, Offset(dx, dy));

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (byteData == null) {
    throw StateError('Rendu du bitmap de texte impossible.');
  }

  final rgba = byteData.buffer.asUint8List();
  final pixels = Uint8List(width * height * 2);
  var o = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    final rgb565 = rgbToRgb565(rgba[i], rgba[i + 1], rgba[i + 2]);
    pixels[o++] = (rgb565 >> 8) & 0xFF;
    pixels[o++] = rgb565 & 0xFF;
  }

  return TextBitmap(
    frame: PixelFrame(width: width, height: height, pixelsRgb565: pixels),
    colorBgRgb565: colorToRgb565(content.colorBg),
  );
}
