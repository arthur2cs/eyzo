import 'package:flutter/material.dart';

import 'scroll_direction_mode.dart';

/// Configuration d'un contenu "texte défilant" (voir specs.md §4.2).
class TextContent {
  const TextContent({
    required this.text,
    this.font = GlassesFont.classic,
    this.size = 2,
    this.colorFg = Colors.white,
    this.colorBg = Colors.black,
    this.speed = 5,
    this.direction = ScrollDirectionMode.leftward,
  });

  final String text;
  final GlassesFont font;
  final int size;
  final Color colorFg;
  final Color colorBg;
  final int speed;
  final ScrollDirectionMode direction;

  TextContent copyWith({
    String? text,
    GlassesFont? font,
    int? size,
    Color? colorFg,
    Color? colorBg,
    int? speed,
    ScrollDirectionMode? direction,
  }) {
    return TextContent(
      text: text ?? this.text,
      font: font ?? this.font,
      size: size ?? this.size,
      colorFg: colorFg ?? this.colorFg,
      colorBg: colorBg ?? this.colorBg,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'font': font.id,
        'size': size,
        'colorFg': colorFg.toARGB32(),
        'colorBg': colorBg.toARGB32(),
        'speed': speed,
        'direction': direction.byte,
      };

  factory TextContent.fromJson(Map<String, dynamic> json) => TextContent(
        text: json['text'] as String,
        font: GlassesFont.values.firstWhere((f) => f.id == json['font'], orElse: () => GlassesFont.classic),
        size: json['size'] as int,
        colorFg: Color(json['colorFg'] as int),
        colorBg: Color(json['colorBg'] as int),
        speed: json['speed'] as int,
        direction: ScrollDirectionMode.values
            .firstWhere((d) => d.byte == json['direction'], orElse: () => ScrollDirectionMode.leftward),
      );
}
