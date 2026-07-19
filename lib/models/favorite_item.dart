import 'pixel_animation.dart';
import 'target_screen.dart';
import 'text_content.dart';

enum FavoriteType { text, animation }

/// Élément sauvegardé en local (Hive) — voir specs.md §4.6.
class FavoriteItem {
  const FavoriteItem({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.targetScreen,
    this.textContent,
    this.animation,
  });

  final String id;
  final String name;
  final FavoriteType type;
  final DateTime createdAt;
  final TargetScreen targetScreen;
  final TextContent? textContent;
  final PixelAnimation? animation;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'targetScreen': targetScreen.byte,
    'textContent': textContent?.toJson(),
    'animation': animation?.toJson(),
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: FavoriteType.values.firstWhere((t) => t.name == json['type']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    targetScreen: TargetScreen.values.firstWhere(
      (s) => s.byte == json['targetScreen'],
    ),
    textContent: json['textContent'] != null
        ? TextContent.fromJson(
            Map<String, dynamic>.from(json['textContent'] as Map),
          )
        : null,
    animation: json['animation'] != null
        ? PixelAnimation.fromJson(
            Map<String, dynamic>.from(json['animation'] as Map),
          )
        : null,
  );
}
