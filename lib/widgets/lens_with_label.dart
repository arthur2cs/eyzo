import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Verre + légende ("L"/"R", du point de vue du porteur — voir CLAUDE.md
/// pour la convention L/R (porteur) vs gauche/droite (aperçu, miroir)).
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
