import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Affiche les 2 verres des lunettes côte à côte selon la convention "miroir" :
/// on voit ce que le porteur montre au public (comme se faire face). Le verre
/// DROIT du porteur apparaît donc à GAUCHE dans l'app, et le verre GAUCHE du
/// porteur à DROITE (voir specs.md §3).
class DualLensRow extends StatelessWidget {
  const DualLensRow({
    super.key,
    required this.rightLens,
    required this.leftLens,
  });

  /// Contenu affiché sur le verre droit du porteur (rendu à gauche de l'app).
  final Widget rightLens;

  /// Contenu affiché sur le verre gauche du porteur (rendu à droite de l'app).
  final Widget leftLens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        rightLens,
        Container(
          width: 18,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        leftLens,
      ],
    );
  }
}
