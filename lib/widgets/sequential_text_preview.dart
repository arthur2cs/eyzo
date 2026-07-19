import 'package:flutter/material.dart';

import '../core/utils/text_measure.dart';
import '../models/scroll_direction_mode.dart';
import '../models/text_content.dart';
import 'dual_lens_row.dart';
import 'glasses_screen_frame.dart';
import 'lens_with_label.dart';

/// Aperçu du mode "Séquentiel" (texte uniquement, voir specs.md §4.2/§6.3) :
/// les 2 écrans forment une seule bande de défilement continue. L'écran de
/// départ dépend de la direction — en défilement "←" (mouvement visuel
/// droite→gauche sur le téléphone) le texte entre par l'écran Gauche et
/// sort par l'écran Droit ; en "→" c'est l'inverse.
/// Pour les modes statique/clignotant (sans déplacement), les 2 écrans
/// affichent simplement le même contenu (équivalent à "Simultané").
class SequentialTextPreview extends StatefulWidget {
  const SequentialTextPreview({
    super.key,
    required this.content,
    this.lensWidth = 130,
  });

  final TextContent content;
  final double lensWidth;

  @override
  State<SequentialTextPreview> createState() => _SequentialTextPreviewState();
}

class _SequentialTextPreviewState extends State<SequentialTextPreview>
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
  void didUpdateWidget(covariant SequentialTextPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recomputeDuration();
  }

  // Voir ScrollingTextPreview._loopAnimation : repeat() figerait la durée de
  // la simulation au premier appel, empêchant la vitesse de défilement d'avoir
  // un effet visible une fois l'animation démarrée.
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

  double get _combinedWidth => widget.lensWidth * 2;

  /// Voir [ScrollingTextPreview._recomputeDuration] — même logique, sur la
  /// largeur combinée des 2 écrans.
  void _recomputeDuration() {
    final speed = widget.content.speed.clamp(1, 10);
    final pxPerSecond = 30.0 + speed * 25.0;
    final textWidth = measureTextWidth(_displayText, _textStyle);
    final travel = _combinedWidth + textWidth;
    final ms = (travel / pxPerSecond * 1000).clamp(400, 20000).round();
    _controller.duration = Duration(milliseconds: ms);
  }

  Widget _buildText() =>
      Text(_displayText, style: _textStyle, maxLines: 1, softWrap: false);

  /// Fenêtre affichant la tranche [sliceStartX, sliceStartX + lensWidth) de la
  /// bande combinée portée par [_controller].
  Widget _window(double sliceStartX) {
    final content = widget.content;
    final combinedWidth = _combinedWidth;
    final reverse = content.direction == ScrollDirectionMode.rightward;
    final textWidth = measureTextWidth(_displayText, _textStyle);

    return GlassesScreenFrame(
      width: widget.lensWidth,
      backgroundColor: content.colorBg,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = reverse ? 1 - _controller.value : _controller.value;
            final pos = combinedWidth - t * (combinedWidth + textWidth);
            return Transform.translate(
              offset: Offset(pos - sliceStartX, 0),
              // Voir ScrollingTextPreview : sans OverflowBox, le texte serait
              // tronqué à la largeur de la fenêtre avant même d'être translaté,
              // ce qui l'empêcherait de "continuer" visuellement sur l'autre écran.
              // minHeight: 0 est nécessaire pour que l'alignement centre vraiment
              // le texte verticalement (sinon la contrainte de hauteur reste
              // "tight" et le texte est étiré en haut du cadre).
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
            child: _buildText(),
          ),
        ),
      ),
    );
  }

  Widget _staticOrBlinkWindow() {
    final content = widget.content;
    final textWidget = Padding(
      padding: const EdgeInsets.all(8),
      child: _buildText(),
    );
    return GlassesScreenFrame(
      width: widget.lensWidth,
      backgroundColor: content.colorBg,
      child: Center(
        child: content.direction == ScrollDirectionMode.blink
            ? FadeTransition(
                opacity: _controller.drive(
                  TweenSequence([
                    TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
                    TweenSequenceItem(tween: ConstantTween(0.0), weight: 50),
                  ]),
                ),
                child: textWidget,
              )
            : textWidget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final travels =
        widget.content.direction == ScrollDirectionMode.leftward ||
        widget.content.direction == ScrollDirectionMode.rightward;

    // Bande combinée alignée sur l'affichage app (miroir) : [Droit : 0..lensWidth)
    // à gauche de l'app, puis [Gauche : lensWidth..2*lensWidth) à droite de l'app —
    // la jointure entre les 2 tranches tombe ainsi exactement sur le connecteur
    // visuel entre les 2 verres (voir DualLensRow), sans quoi le texte "sauterait"
    // d'un bord extérieur à l'autre au lieu de continuer d'un écran à l'autre.
    final droitLens = travels ? _window(0) : _staticOrBlinkWindow();
    final gaucheLens = travels
        ? _window(widget.lensWidth)
        : _staticOrBlinkWindow();

    return DualLensRow(
      rightLens: LensWithLabel(label: 'Droite', lens: droitLens),
      leftLens: LensWithLabel(label: 'Gauche', lens: gaucheLens),
    );
  }
}
