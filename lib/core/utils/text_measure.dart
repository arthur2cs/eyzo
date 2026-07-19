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
