import 'package:flutter/material.dart';

import '../core/glasses_display.dart';
import '../core/theme/app_theme.dart';

/// Cadre simulant un écran des lunettes, dessiné au ratio d'aperçu défini
/// dans [GlassesDisplay] plutôt qu'au ratio natif du panneau ST7735S
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

  static const double aspectRatio = GlassesDisplay.previewAspectRatio;

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
