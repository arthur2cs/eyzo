import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Cadre simulant un écran des lunettes, dessiné au format 3:2 pour un
/// aperçu plus réaliste que le ratio natif 240x320 du panneau ST7789V
/// (voir specs.md §2/§3).
class GlassesScreenFrame extends StatelessWidget {
  const GlassesScreenFrame({
    super.key,
    required this.child,
    this.width = 160,
    this.backgroundColor = Colors.black,
  });

  final Widget child;
  final double width;
  final Color backgroundColor;

  static const double aspectRatio = 3 / 2;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width / aspectRatio,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
