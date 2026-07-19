import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
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
  }

  @override
  void didUpdateWidget(covariant ScrollingTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final speed = widget.content.speed.clamp(1, 10);
    _controller.duration = Duration(milliseconds: (5500 - speed * 450).round());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _fontSize => 12.0 + widget.content.size * 4.0;

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
    final textStyle = TextStyle(
      color: content.colorFg,
      fontSize: _fontSize,
      fontWeight: content.font == GlassesFont.bold
          ? FontWeight.bold
          : FontWeight.normal,
      fontFamily: content.font.label == 'Mono' ? 'monospace' : null,
    );

    Widget textWidget = Text(
      content.text.isEmpty ? 'Aperçu…' : content.text,
      style: textStyle,
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
        return GlassesScreenFrame(
          width: widget.width,
          backgroundColor: content.colorBg,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = reverse ? 1 - _controller.value : _controller.value;
                final dx = widget.width - (t * (widget.width * 2 + 200));
                return Transform.translate(
                  offset: Offset(dx + widget.width, 0),
                  child: Align(alignment: Alignment.centerLeft, child: child),
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
