import 'package:flutter/material.dart';

import '../core/utils/color_convert.dart';
import '../models/pixel_animation.dart';

/// Dessine une [PixelFrame] (grille RGB565 basse résolution) mise à l'échelle.
class PixelFramePainter extends CustomPainter {
  const PixelFramePainter(this.frame);

  final PixelFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / frame.width;
    final cellH = size.height / frame.height;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        paint.color = rgb565ToColor(frame.getPixel(x, y));
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PixelFramePainter oldDelegate) =>
      oldDelegate.frame != frame;
}
