import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/text_measure.dart';
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
    )..repeat();
    _recomputeDuration();
  }

  @override
  void didUpdateWidget(covariant ScrollingTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recomputeDuration();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _fontSize => 12.0 + widget.content.size * 4.0;

  TextStyle get _textStyle => TextStyle(
    color: widget.content.colorFg,
    fontSize: _fontSize,
    fontWeight: widget.content.font == GlassesFont.bold
        ? FontWeight.bold
        : FontWeight.normal,
    fontFamily: widget.content.font.label == 'Mono' ? 'monospace' : null,
  );

  String get _displayText =>
      widget.content.text.isEmpty ? 'Aperçu…' : widget.content.text;

  /// Vitesse cible en px/s (échelle 1-10) — la durée du cycle est déduite de la
  /// distance réelle à parcourir pour que le texte défile à une vitesse à peu
  /// près constante, quelle que soit sa longueur (voir specs.md §4.2).
  void _recomputeDuration() {
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
                  child: OverflowBox(
                    minWidth: 0,
                    maxWidth: double.infinity,
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
