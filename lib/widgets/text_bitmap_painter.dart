import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/glasses_display.dart';

/// Dessine une fenêtre d'un bitmap texte (voir pixel_image.dart) décalée
/// horizontalement de [offsetXPx] pixels **natifs** (voir
/// GlassesDisplay.nativeWidth) — miroir exact de `blitBitmapWindow()` côté
/// firmware (display_manager.cpp) : fond peint en premier, bitmap ensuite,
/// tronqué aux bords de la fenêtre. [image] à `null` (encore en cours de
/// chargement, ou clignotement à l'état éteint) ne peint que le fond.
class TextBitmapPainter extends CustomPainter {
  const TextBitmapPainter({
    required this.image,
    required this.offsetXPx,
    required this.backgroundColor,
    required this.nativeViewportWidth,
  });

  final ui.Image? image;
  final double offsetXPx;
  final Color backgroundColor;

  /// Largeur, en pixels natifs, représentée par ce viewport (voir
  /// GlassesDisplay.nativeWidth — un écran physique complet) : sert à
  /// calculer l'échelle d'affichage par rapport à [Size] reçue par [paint].
  final double nativeViewportWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    final img = image;
    if (img == null) return;

    final scale = size.width / nativeViewportWidth;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(offsetXPx * scale, 0);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromLTWH(0, 0, img.width * scale, size.height),
      Paint()..filterQuality = FilterQuality.none,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TextBitmapPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.offsetXPx != offsetXPx ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.nativeViewportWidth != nativeViewportWidth;
}

/// Dimensionne [child] au ratio **natif** de l'écran des lunettes (voir
/// GlassesDisplay.nativeWidth/nativeHeight), centré dans l'espace
/// disponible — indépendant du ratio esthétique du cadre d'aperçu (voir
/// GlassesScreenFrame, specs.md §3), qui peut différer du ratio natif réel.
/// Sans ça, [TextBitmapPainter] recevrait une [Size] déformée par rapport
/// au bitmap réel et son échelle horizontale/verticale diffèrerait.
class NativeAspectBox extends StatelessWidget {
  const NativeAspectBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w * GlassesDisplay.nativeHeight / GlassesDisplay.nativeWidth;
        return Center(child: SizedBox(width: w, height: h, child: child));
      },
    );
  }
}
