import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/display_settings_providers.dart';
import '../core/theme/app_theme.dart';
import 'inter_lens_gap_dialog.dart';

/// Affiche les 2 verres des lunettes côte à côte selon la convention "miroir" :
/// on voit ce que le porteur montre au public (comme se faire face). Le verre
/// DROIT du porteur apparaît donc à GAUCHE dans l'app, et le verre GAUCHE du
/// porteur à DROITE (voir specs.md §3).
class DualLensRow extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final gapMm = ref.watch(interLensGapProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        rightLens,
        _InterLensGapIndicator(gapMm: gapMm),
        leftLens,
      ],
    );
  }
}

/// Bouton représentant l'espace physique entre les 2 écrans (non collés dans
/// le prototype) : ouvre la modale de réglage en mm (voir
/// [showInterLensGapDialog]), et affiche la valeur courante persistée.
class _InterLensGapIndicator extends ConsumerWidget {
  const _InterLensGapIndicator({required this.gapMm});

  final double gapMm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showInterLensGapDialog(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.compare_arrows,
              size: 20,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              '${gapMm.toStringAsFixed(1).replaceAll('.', ',')} mm',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
