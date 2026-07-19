import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/utils/color_convert.dart';
import '../../core/utils/pixel_canvas.dart';
import '../../models/pixel_animation.dart';

/// Bibliothèque d'animations prédéfinies embarquées dans l'app (voir specs.md §4.3).
class AnimationPreset {
  const AnimationPreset({required this.id, required this.name, required this.icon, required this.build});

  final String id;
  final String name;
  final IconData icon;
  final PixelAnimation Function() build;
}

const int _w = EyzoGrid.defaultWidth;
const int _h = EyzoGrid.defaultHeight;

const List<String> _heartBitmap = [
  ' ## ## ',
  '#######',
  '#######',
  ' ##### ',
  '  ###  ',
  '   #   ',
];

const List<String> _smileyOpen = [
  '  #####  ',
  ' ####### ',
  '## o o ##',
  '#########',
  '# ##### #',
  '## --- ##',
  ' ####### ',
  '  #####  ',
];

const List<String> _smileyWink = [
  '  #####  ',
  ' ####### ',
  '## - o ##',
  '#########',
  '# ##### #',
  '## --- ##',
  ' ####### ',
  '  #####  ',
];

const List<String> _eyesOpen = [
  ' ##   ## ',
  '#### ####',
  '#### ####',
  ' ##   ## ',
];

const List<String> _eyesClosed = [
  '         ',
  '#### ####',
  '         ',
  '         ',
];

PixelAnimation _heartBeat() {
  final red = colorToRgb565(const Color(0xFFFF3B30));
  final black = colorToRgb565(Colors.black);
  return PixelAnimation(
    frameDelayMs: 220,
    frames: [
      frameFromBitmap(_heartBitmap, canvasWidth: _w, canvasHeight: _h, fgRgb565: red, bgRgb565: black, scale: 2),
      frameFromBitmap(_heartBitmap, canvasWidth: _w, canvasHeight: _h, fgRgb565: red, bgRgb565: black, scale: 3),
    ],
  );
}

PixelAnimation _smiley() {
  final yellow = colorToRgb565(const Color(0xFFFFCC00));
  final black = colorToRgb565(Colors.black);
  return PixelAnimation(
    frameDelayMs: 600,
    frames: [
      frameFromBitmap(_smileyOpen, canvasWidth: _w, canvasHeight: _h, fgRgb565: yellow, bgRgb565: black, scale: 3),
      frameFromBitmap(_smileyOpen, canvasWidth: _w, canvasHeight: _h, fgRgb565: yellow, bgRgb565: black, scale: 3),
      frameFromBitmap(_smileyWink, canvasWidth: _w, canvasHeight: _h, fgRgb565: yellow, bgRgb565: black, scale: 3),
    ],
  );
}

PixelAnimation _eyes() {
  final white = colorToRgb565(Colors.white);
  final black = colorToRgb565(Colors.black);
  return PixelAnimation(
    frameDelayMs: 1400,
    frames: [
      frameFromBitmap(_eyesOpen, canvasWidth: _w, canvasHeight: _h, fgRgb565: white, bgRgb565: black, scale: 3),
      frameFromBitmap(_eyesOpen, canvasWidth: _w, canvasHeight: _h, fgRgb565: white, bgRgb565: black, scale: 3),
      frameFromBitmap(_eyesClosed, canvasWidth: _w, canvasHeight: _h, fgRgb565: white, bgRgb565: black, scale: 3),
    ],
  );
}

final List<AnimationPreset> kAnimationPresets = [
  AnimationPreset(id: 'heart', name: 'Cœur qui bat', icon: Icons.favorite, build: _heartBeat),
  AnimationPreset(id: 'smiley', name: 'Smiley clin d\'œil', icon: Icons.emoji_emotions, build: _smiley),
  AnimationPreset(id: 'eyes', name: 'Yeux qui clignent', icon: Icons.remove_red_eye, build: _eyes),
];
