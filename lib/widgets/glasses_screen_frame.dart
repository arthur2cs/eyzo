import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Cadre simulant un écran des lunettes (ratio 240x320, voir specs.md §2).
class GlassesScreenFrame extends StatelessWidget {
  const GlassesScreenFrame({super.key, required this.child, this.width = 160, this.backgroundColor = Colors.black});

  final Widget child;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 320 / 240,
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
