import 'dart:typed_data';

import '../../models/pixel_animation.dart';

/// Remplissage par diffusion (bucket fill) à partir de (x, y).
PixelFrame floodFill(PixelFrame frame, int x, int y, int newColor) {
  final target = frame.getPixel(x, y);
  if (target == newColor) return frame;

  final pixels = Uint8List.fromList(frame.pixelsRgb565);
  final width = frame.width;
  final height = frame.height;

  int getAt(int px, int py) {
    final i = (py * width + px) * 2;
    return (pixels[i] << 8) | pixels[i + 1];
  }

  void setAt(int px, int py, int color) {
    final i = (py * width + px) * 2;
    pixels[i] = (color >> 8) & 0xFF;
    pixels[i + 1] = color & 0xFF;
  }

  final stack = <(int, int)>[(x, y)];
  while (stack.isNotEmpty) {
    final (cx, cy) = stack.removeLast();
    if (cx < 0 || cx >= width || cy < 0 || cy >= height) continue;
    if (getAt(cx, cy) != target) continue;
    setAt(cx, cy, newColor);
    stack.add((cx + 1, cy));
    stack.add((cx - 1, cy));
    stack.add((cx, cy + 1));
    stack.add((cx, cy - 1));
  }

  return frame.copyWith(pixelsRgb565: pixels);
}
