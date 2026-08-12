import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/text_measure.dart';
import '../core/utils/text_style.dart';
import '../models/scroll_direction_mode.dart';
import '../models/text_content.dart';
import 'glasses_screen_frame.dart';

/// Aperçu du texte défilant tel qu'il sera rendu sur l'écran des lunettes
/// (voir specs.md §4.2 — aperçu avant envoi).
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

class _ScrollingTextPreviewState extends State<ScrollingTextPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _controller.addStatusListener(_loopAnimation);
    _recomputeDuration();
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ScrollingTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recomputeDuration();
  }

  // AnimationController.repeat() fige la durée de la simulation au moment de
  // l'appel : changer `duration` en cours de route (ex. via le slider de
  // vitesse) n'aurait alors aucun effet visible. En relançant nous-mêmes
  // `forward()` à chaque cycle, la durée à jour est relue à chaque boucle.
  void _loopAnimation(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_loopAnimation);
    _controller.dispose();
    super.dispose();
  }

  TextStyle get _textStyle => textStyleFor(widget.content);

  String get _displayText {
    final text = widget.content.text.isEmpty
        ? 'Votre texte…'
        : widget.content.text;
    return widget.content.font == GlassesFont.pixel
        ? text.toUpperCase()
        : text;
  }

  /// Vitesse cible en px/s (échelle 1-10) — la durée du cycle est déduite de la
  /// distance réelle à parcourir pour que le texte défile à une vitesse à peu
  /// près constante, quelle que soit sa longueur (voir specs.md §4.2).
  void _recomputeDuration() {
    if (widget.content.direction == ScrollDirectionMode.blink) {
      // Le clignotement n'a pas de "distance à parcourir" : sa durée ne doit
      // dépendre que de la vitesse, pas de la longueur du texte (sinon un
      // message long clignoterait lentement même à vitesse 10).
      _controller.duration = blinkPeriod(widget.content.speed);
      return;
    }
    final speed = widget.content.speed.clamp(1, 10);
    final pxPerSecond = 30.0 + speed * 25.0;
    final textWidth = measureTextWidth(_displayText, _textStyle);
    final travel = widget.width + textWidth;
    final ms = (travel / pxPerSecond * 1000).clamp(400, 20000).round();
    _controller.duration = Duration(milliseconds: ms);
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
    final textWidget = Text(
      _displayText,
      style: _textStyle,
      maxLines: 1,
      softWrap: false,
    );

    switch (content.direction) {
      case ScrollDirectionMode.static_:
        return GlassesScreenFrame(
          width: widget.width,
          backgroundColor: content.colorBg,
          child: Center(
            child: Padding(padding: const EdgeInsets.all(8), child: textWidget),
          ),
        );
      case ScrollDirectionMode.blink:
        return GlassesScreenFrame(
          width: widget.width,
          backgroundColor: content.colorBg,
          child: Center(
            child: FadeTransition(
              opacity: _controller.drive(
                TweenSequence([
                  TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
                  TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
                ]),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: textWidget,
              ),
            ),
          ),
        );
      case ScrollDirectionMode.leftward:
      case ScrollDirectionMode.rightward:
        final reverse = content.direction == ScrollDirectionMode.rightward;
        final textWidth = measureTextWidth(_displayText, _textStyle);
        return GlassesScreenFrame(
          width: widget.width,
          backgroundColor: content.colorBg,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = reverse ? 1 - _controller.value : _controller.value;
                final pos = widget.width - t * (widget.width + textWidth);
                return Transform.translate(
                  offset: Offset(pos, 0),
                  // OverflowBox laisse le texte se dessiner à sa largeur naturelle
                  // (même plus large que le cadre visible) : sans ça, il serait
                  // tronqué à la largeur du cadre avant même d'être translaté.
                  // minHeight: 0 est indispensable pour que l'alignement centre
                  // réellement le texte : sans lui, la contrainte de hauteur reçue
                  // reste "tight" (= hauteur du cadre) et le texte est étiré en
                  // haut du cadre au lieu d'être centré.
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
                    minHeight: 0,
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: textWidget,
              ),
            ),
          ),
        );
    }
  }
}
