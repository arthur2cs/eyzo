import 'package:flutter/material.dart';

import '../../models/scroll_direction_mode.dart';
import '../../models/text_content.dart';

/// Style de rendu d'un [TextContent] — unique source de vérité utilisée à la
/// fois par les aperçus (ScrollingTextPreview/SequentialTextPreview) et par
/// le rendu bitmap envoyé aux lunettes (text_bitmap_renderer.dart), pour que
/// les deux restent identiques par construction plutôt que par duplication.
TextStyle textStyleFor(TextContent content) => TextStyle(
  color: content.colorFg,
  fontSize: 12.0 + content.size * 4.0,
  fontWeight: content.font == GlassesFont.bold
      ? FontWeight.w900
      : FontWeight.normal,
  fontFamily: switch (content.font) {
    GlassesFont.mono => 'monospace',
    GlassesFont.pixel => 'PressStart2P',
    GlassesFont.classic || GlassesFont.bold => null,
  },
);
