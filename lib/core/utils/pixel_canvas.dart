import 'dart:typed_data';

import '../../models/pixel_animation.dart';

/// Petit canvas mutable pour construire des [PixelFrame] par code
/// (utilisé par les animations prédéfinies, voir specs.md §4.3).
class PixelCanvas {
  PixelCanvas(this.width, this.height, {int background = 0x0000})
    : _pixels = List.filled(width * height, background);

  final int width;
  final int height;
  final List<int> _pixels;

  void setPixel(int x, int y, int rgb565) {
    if (x < 0 || x >= width || y < 0 || y >= height) return;
    _pixels[y * width + x] = rgb565;
  }

  void fillRect(int x0, int y0, int w, int h, int rgb565) {
    for (var y = y0; y < y0 + h; y++) {
      for (var x = x0; x < x0 + w; x++) {
        setPixel(x, y, rgb565);
      }
    }
  }

  PixelFrame toFrame() {
    final bytes = Uint8List(width * height * 2);
    for (var i = 0; i < _pixels.length; i++) {
      bytes[i * 2] = (_pixels[i] >> 8) & 0xFF;
      bytes[i * 2 + 1] = _pixels[i] & 0xFF;
    }
    return PixelFrame(width: width, height: height, pixelsRgb565: bytes);
  }
}

/// Construit une frame à partir d'un petit bitmap ASCII ('#' = premier plan, tout le reste = fond),
/// centré et mis à l'échelle dans un canvas de `canvasWidth`x`canvasHeight`.
PixelFrame frameFromBitmap(
  List<String> rows, {
  required int canvasWidth,
  required int canvasHeight,
  required int fgRgb565,
  required int bgRgb565,
  int scale = 2,
}) {
  final canvas = PixelCanvas(canvasWidth, canvasHeight, background: bgRgb565);
  final bitmapHeight = rows.length;
  final bitmapWidth = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

  final scaledW = bitmapWidth * scale;
  final scaledH = bitmapHeight * scale;
  final offsetX = ((canvasWidth - scaledW) / 2).floor().clamp(0, canvasWidth);
  final offsetY = ((canvasHeight - scaledH) / 2).floor().clamp(0, canvasHeight);

  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      if (row[c] == '#') {
        canvas.fillRect(
          offsetX + c * scale,
          offsetY + r * scale,
          scale,
          scale,
          fgRgb565,
        );
      }
    }
  }
  return canvas.toFrame();
}
