import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/glasses_display.dart';
import '../core/utils/glasses_timing.dart';
import '../core/utils/pixel_image.dart';
import '../core/utils/text_bitmap_renderer.dart';
import '../models/scroll_direction_mode.dart';
import '../models/text_content.dart';
import 'dual_lens_row.dart';
import 'glasses_screen_frame.dart';
import 'lens_with_label.dart';
import 'text_bitmap_painter.dart';

/// Aperçu du mode "Séquentiel" (texte uniquement, voir specs.md §4.2/§6.3) :
/// les 2 écrans forment une seule bande de défilement continue. L'écran de
/// départ dépend de la direction — en défilement "←" (mouvement visuel
/// droite→gauche sur le téléphone) le texte entre par l'écran Gauche et
/// sort par l'écran Droit ; en "→" c'est l'inverse.
/// Pour les modes statique/clignotant (sans déplacement), les 2 écrans
/// affichent simplement le même contenu (équivalent à "Simultané").
///
/// Affiche **le bitmap réellement envoyé** (voir text_bitmap_renderer.dart)
/// animé par un minuteur qui avance pixel par pixel exactement aux mêmes
/// cadences que le firmware (voir glasses_timing.dart et
/// display_manager.cpp::updateSequential) : ce que l'utilisateur voit ici
/// est, au pixel et à l'instant près, ce que les lunettes afficheront.
class SequentialTextPreview extends StatefulWidget {
  const SequentialTextPreview({
    super.key,
    required this.content,
    this.lensWidth = 130,
    this.interLensGapMm = 0,
  });

  final TextContent content;
  final double lensWidth;

  /// Espace physique entre les 2 écrans (non collés dans le prototype), en
  /// mm — voir [DualLensRow]. Converti en pixels natifs (voir
  /// [_nativeGapPx]) : le texte y est invisible le temps de la traverser, à
  /// la même vitesse (en pixels natifs/seconde) que le défilement réel.
  final double interLensGapMm;

  @override
  State<SequentialTextPreview> createState() => _SequentialTextPreviewState();
}

class _SequentialTextPreviewState extends State<SequentialTextPreview> {
  ui.Image? _image;
  double _bitmapWidth = 0;
  double _virtualX = 0;
  bool _blinkOn = true;
  Timer? _timer;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadBitmap();
  }

  @override
  void didUpdateWidget(covariant SequentialTextPreview oldWidget) {
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
    } else if (old.speed != content.speed ||
        oldWidget.interLensGapMm != widget.interLensGapMm) {
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

  /// Écart, en pixels **natifs** (voir GlassesDisplay.nativeWidth), entre
  /// les 2 écrans — c'est dans cette même unité que [_virtualX] avance
  /// (1 pixel natif par pas, voir _tick), pour que la vitesse perçue reste
  /// identique à celle du firmware même en tenant compte de cet écart
  /// purement visuel (le firmware, lui, n'a aucune notion d'écart : les 2
  /// écrans y sont une bande continue de 2xSCREEN_W, voir protocol.h).
  double get _nativeGapPx =>
      widget.interLensGapMm /
      GlassesDisplay.lensWidthMm *
      GlassesDisplay.nativeWidth;

  double get _combinedNativeWidth =>
      GlassesDisplay.nativeWidth * 2 + _nativeGapPx;

  /// Miroir de `SequentialState::needsRedraw` côté firmware (première frame
  /// après un (re)démarrage) : position/état initiaux avant tout défilement.
  void _resetPosition() {
    switch (widget.content.direction) {
      case ScrollDirectionMode.leftward:
        _virtualX = _combinedNativeWidth;
      case ScrollDirectionMode.rightward:
        _virtualX = -_bitmapWidth;
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

  /// Miroir exact de `updateSequential()` côté firmware (display_manager.cpp) :
  /// même convention de signe que le défilement individuel (`leftward` fait
  /// décroître la position, `rightward` la fait croître, voir specs.md §6.3)
  /// — augmenté seulement de [_nativeGapPx] dans les bornes de rebouclage
  /// (voir [_nativeGapPx]).
  void _tick() {
    if (!mounted) return;
    setState(() {
      final content = widget.content;
      if (content.direction == ScrollDirectionMode.blink) {
        _blinkOn = !_blinkOn;
        return;
      }
      final combined = _combinedNativeWidth;
      if (content.direction == ScrollDirectionMode.leftward) {
        _virtualX--;
        if (_virtualX < -_bitmapWidth) _virtualX = combined;
      } else if (content.direction == ScrollDirectionMode.rightward) {
        _virtualX++;
        if (_virtualX > combined) _virtualX = -_bitmapWidth;
      }
    });
  }

  Widget _lensWindow(double offsetXPx, bool showImage) {
    return GlassesScreenFrame(
      width: widget.lensWidth,
      backgroundColor: widget.content.colorBg,
      child: NativeAspectBox(
        child: CustomPaint(
          painter: TextBitmapPainter(
            image: showImage ? _image : null,
            offsetXPx: offsetXPx,
            backgroundColor: widget.content.colorBg,
            nativeViewportWidth: GlassesDisplay.nativeWidth.toDouble(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final travels =
        content.direction == ScrollDirectionMode.leftward ||
        content.direction == ScrollDirectionMode.rightward;
    final showImage =
        content.direction != ScrollDirectionMode.blink || _blinkOn;

    // Miroir exact de redrawSequential() côté firmware (display_manager.cpp),
    // en tenant compte de la vue "miroir" de l'app (voir DualLensRow : le
    // verre Gauche du porteur est affiché à DROITE de l'app, le Droit à
    // GAUCHE, specs.md §3) : c'est donc l'écran affiché à gauche de l'app
    // (droitLens) qui utilise l'offset virtualX tel quel (comme canvasRight
    // côté firmware), et celui affiché à droite (gaucheLens) qui utilise
    // virtualX - SCREEN_W (comme canvasLeft, ici élargi de l'écart
    // inter-écrans, voir _nativeGapPx) — la jointure entre les 2 tranches
    // tombe ainsi exactement sur le connecteur visuel entre les 2 verres,
    // sans quoi le texte "sauterait" d'un bord extérieur à l'autre au lieu
    // de continuer d'un écran à l'autre.
    final droitLens = travels
        ? _lensWindow(_virtualX, showImage)
        : _lensWindow(0, showImage);
    final gaucheLens = travels
        ? _lensWindow(
            _virtualX - (GlassesDisplay.nativeWidth + _nativeGapPx),
            showImage,
          )
        : _lensWindow(0, showImage);

    return DualLensRow(
      rightLens: LensWithLabel(label: 'R', lens: droitLens),
      leftLens: LensWithLabel(label: 'L', lens: gaucheLens),
    );
  }
}
