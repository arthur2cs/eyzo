import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/glasses_display.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/glasses_timing.dart';
import '../core/utils/pixel_image.dart';
import '../core/utils/text_bitmap_renderer.dart';
import '../models/scroll_direction_mode.dart';
import '../models/text_content.dart';
import 'glasses_screen_frame.dart';
import 'text_bitmap_painter.dart';

/// Aperçu du texte défilant tel qu'il sera rendu sur l'écran des lunettes
/// (voir specs.md §4.2). Affiche **le bitmap réellement envoyé** (voir
/// text_bitmap_renderer.dart) — pas un second rendu Flutter indépendant —
/// animé par un minuteur qui avance pixel par pixel exactement aux mêmes
/// cadences que le firmware (voir glasses_timing.dart et
/// display_manager.cpp::updateTextChannel) : ce que l'utilisateur voit ici
/// est, au pixel et à l'instant près, ce que les lunettes afficheront.
class ScrollingTextPreview extends StatefulWidget {
  const ScrollingTextPreview({
    super.key,
    required this.content,
    this.width = 160,
    this.active = true,
  });

  final TextContent content;
  final double width;

  /// Si false, simule un écran éteint (verre non ciblé par l'envoi en cours).
  final bool active;

  @override
  State<ScrollingTextPreview> createState() => _ScrollingTextPreviewState();
}

class _ScrollingTextPreviewState extends State<ScrollingTextPreview> {
  ui.Image? _image;
  double _bitmapWidth = 0;
  double _scrollX = 0;
  bool _blinkOn = true;
  Timer? _timer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadBitmap();
  }

  @override
  void didUpdateWidget(covariant ScrollingTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.content;
    final content = widget.content;
    final needsReload =
        old.text != content.text ||
        old.font != content.font ||
        old.size != content.size ||
        old.colorFg != content.colorFg ||
        old.colorBg != content.colorBg ||
        old.direction != content.direction;
    if (needsReload) {
      _loadBitmap();
    } else if (old.speed != content.speed) {
      _restartTimer(); // reprend depuis la position actuelle, cadence seule change
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Substitut d'aperçu quand le texte est vide, avec police/taille/couleurs
  /// choisies par l'utilisateur (jamais réellement envoyé : text_screen.dart
  /// bloque l'envoi tant que le texte est vide).
  TextContent _previewContent(TextContent content) {
    if (content.text.trim().isNotEmpty) return content;
    return content.copyWith(text: 'Votre texte…');
  }

  Future<void> _loadBitmap() async {
    final myGeneration = ++_loadGeneration;
    final bitmap = await renderTextBitmap(_previewContent(widget.content));
    final image = await pixelFrameToImage(bitmap.frame);
    if (!mounted || myGeneration != _loadGeneration) return;
    setState(() {
      _image = image;
      _bitmapWidth = bitmap.frame.width.toDouble();
      _resetPosition();
    });
    _restartTimer();
  }

  /// Miroir de `ScreenChannel::needsRedraw` côté firmware (première frame
  /// après un (re)démarrage) : position/état initiaux avant tout défilement.
  void _resetPosition() {
    switch (widget.content.direction) {
      case ScrollDirectionMode.leftward:
        _scrollX = GlassesDisplay.nativeWidth.toDouble();
      case ScrollDirectionMode.rightward:
        _scrollX = -_bitmapWidth;
      case ScrollDirectionMode.blink:
        _blinkOn = true;
      case ScrollDirectionMode.static_:
        break;
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final content = widget.content;
    if (content.direction == ScrollDirectionMode.static_) return;
    final intervalMs = content.direction == ScrollDirectionMode.blink
        ? blinkHalfPeriodMs(content.speed)
        : scrollStepIntervalMs(content.speed);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _tick());
  }

  /// Miroir exact de `updateTextChannel()` côté firmware (display_manager.cpp) :
  /// même formule de pas/rebouclage, pour ne jamais dériver visuellement
  /// d'un envoi long à l'autre.
  void _tick() {
    if (!mounted) return;
    setState(() {
      final content = widget.content;
      if (content.direction == ScrollDirectionMode.blink) {
        _blinkOn = !_blinkOn;
        return;
      }
      const screenW = GlassesDisplay.nativeWidth;
      if (content.direction == ScrollDirectionMode.leftward) {
        _scrollX--;
        if (_scrollX < -_bitmapWidth) _scrollX = screenW.toDouble();
      } else if (content.direction == ScrollDirectionMode.rightward) {
        _scrollX++;
        if (_scrollX > screenW) _scrollX = -_bitmapWidth;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return GlassesScreenFrame(
        width: widget.width,
        backgroundColor: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.power_settings_new,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final content = widget.content;
    final showImage =
        content.direction != ScrollDirectionMode.blink || _blinkOn;
    final offsetXPx = switch (content.direction) {
      ScrollDirectionMode.static_ || ScrollDirectionMode.blink => 0.0,
      ScrollDirectionMode.leftward ||
      ScrollDirectionMode.rightward => _scrollX,
    };

    return GlassesScreenFrame(
      width: widget.width,
      backgroundColor: content.colorBg,
      child: NativeAspectBox(
        child: CustomPaint(
          painter: TextBitmapPainter(
            image: showImage ? _image : null,
            offsetXPx: offsetXPx,
            backgroundColor: content.colorBg,
            nativeViewportWidth: GlassesDisplay.nativeWidth.toDouble(),
          ),
        ),
      ),
    );
  }
}
