import 'package:flutter/material.dart';

/// Conversion Color Flutter <-> RGB565 (format pixel utilisé par le protocole BLE, voir specs.md §6.3).
int colorToRgb565(Color color) {
  final r = (color.r * 255.0).round() & 0xFF;
  final g = (color.g * 255.0).round() & 0xFF;
  final b = (color.b * 255.0).round() & 0xFF;
  return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
}

int rgbToRgb565(int r, int g, int b) {
  return ((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3);
}

Color rgb565ToColor(int value) {
  final r = (value >> 11) & 0x1F;
  final g = (value >> 5) & 0x3F;
  final b = value & 0x1F;
  return Color.fromARGB(
    255,
    (r * 255 / 31).round(),
    (g * 255 / 63).round(),
    (b * 255 / 31).round(),
  );
}
