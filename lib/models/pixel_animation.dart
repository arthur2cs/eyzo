import 'dart:convert';
import 'dart:typed_data';

/// Une frame de l'animation : pixels encodés en RGB565 (2 octets/pixel), row-major.
/// Résolution de travail basse (ex: 40x32, 80x64) — voir specs.md §4.5 / §6.3.
class PixelFrame {
  const PixelFrame({
    required this.width,
    required this.height,
    required this.pixelsRgb565,
  });

  final int width;
  final int height;
  final Uint8List pixelsRgb565;

  factory PixelFrame.blank(int width, int height, {int fillRgb565 = 0x0000}) {
    final pixels = Uint8List(width * height * 2);
    for (var i = 0; i < width * height; i++) {
      pixels[i * 2] = (fillRgb565 >> 8) & 0xFF;
      pixels[i * 2 + 1] = fillRgb565 & 0xFF;
    }
    return PixelFrame(width: width, height: height, pixelsRgb565: pixels);
  }

  PixelFrame copyWith({Uint8List? pixelsRgb565}) => PixelFrame(
    width: width,
    height: height,
    pixelsRgb565: pixelsRgb565 ?? this.pixelsRgb565,
  );

  int getPixel(int x, int y) {
    final i = (y * width + x) * 2;
    return (pixelsRgb565[i] << 8) | pixelsRgb565[i + 1];
  }

  /// Vrai si tous les pixels valent [rgb565] (ex : canevas vierge jamais dessiné).
  bool isUniform(int rgb565) {
    final hi = (rgb565 >> 8) & 0xFF;
    final lo = rgb565 & 0xFF;
    for (var i = 0; i < pixelsRgb565.length; i += 2) {
      if (pixelsRgb565[i] != hi || pixelsRgb565[i + 1] != lo) return false;
    }
    return true;
  }

  PixelFrame setPixel(int x, int y, int rgb565) {
    final copy = Uint8List.fromList(pixelsRgb565);
    final i = (y * width + x) * 2;
    copy[i] = (rgb565 >> 8) & 0xFF;
    copy[i + 1] = rgb565 & 0xFF;
    return copyWith(pixelsRgb565: copy);
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'pixels': base64Encode(pixelsRgb565),
  };

  factory PixelFrame.fromJson(Map<String, dynamic> json) => PixelFrame(
    width: json['width'] as int,
    height: json['height'] as int,
    pixelsRgb565: base64Decode(json['pixels'] as String),
  );
}

/// Animation multi-frames (éditeur pixel-art ou GIF importé).
class PixelAnimation {
  const PixelAnimation({required this.frames, this.frameDelayMs = 120});

  final List<PixelFrame> frames;
  final int frameDelayMs;

  int get width => frames.isNotEmpty ? frames.first.width : 0;
  int get height => frames.isNotEmpty ? frames.first.height : 0;

  PixelAnimation copyWith({List<PixelFrame>? frames, int? frameDelayMs}) =>
      PixelAnimation(
        frames: frames ?? this.frames,
        frameDelayMs: frameDelayMs ?? this.frameDelayMs,
      );

  Map<String, dynamic> toJson() => {
    'frameDelayMs': frameDelayMs,
    'frames': frames.map((f) => f.toJson()).toList(),
  };

  factory PixelAnimation.fromJson(Map<String, dynamic> json) => PixelAnimation(
    frameDelayMs: json['frameDelayMs'] as int,
    frames: (json['frames'] as List)
        .map((f) => PixelFrame.fromJson(f as Map<String, dynamic>))
        .toList(),
  );
}
