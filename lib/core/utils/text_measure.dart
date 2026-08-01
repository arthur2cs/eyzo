import 'package:flutter/material.dart';

/// Largeur réelle (logique) qu'occuperait [text] rendu avec [style] sur une seule ligne.
/// Utilisé pour dimensionner correctement les aperçus de texte défilant
/// (voir specs.md §4.2 — la largeur du cadre visible ne doit pas contraindre
/// la largeur de rendu du texte, sous peine de le tronquer).
double measureTextWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  return painter.width;
}

/// Durée d'un cycle complet (allumé + éteint) du mode "Clignotant", sur une
/// échelle de vitesse 1-10 — indépendante de la longueur du texte, à
/// l'inverse de la vitesse de défilement (voir specs.md §4.2).
Duration blinkPeriod(int speed) {
  final clamped = speed.clamp(1, 10);
  final ms = 900 - clamped * 70;
  return Duration(milliseconds: ms);
}
