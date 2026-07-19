import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Verre + légende ("Droite"/"Gauche", du point de vue du porteur).
class LensWithLabel extends StatelessWidget {
  const LensWithLabel({super.key, required this.lens, required this.label});

  final Widget lens;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        lens,
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
