import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/display_settings_providers.dart';
import '../core/theme/app_theme.dart';

/// Modale de réglage de l'espace physique entre les 2 écrans (non collés dans
/// le prototype), en mm — voir [DualLensRow]. La valeur est persistée via
/// [interLensGapProvider] et utilisée pour simuler le délai de traversée du
/// texte en mode séquentiel (voir SequentialTextPreview).
Future<void> showInterLensGapDialog(BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController(
    text: _formatMm(ref.read(interLensGapProvider)),
  );
  final result = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Espace inter-écran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distance physique entre les 2 écrans (non collés). Utilisée '
            'pour simuler, dans l\'aperçu, le délai que met le texte à '
            'traverser cet espace en mode séquentiel.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}([.,]\d{0,1})?$')),
            ],
            decoration: const InputDecoration(suffixText: 'mm'),
            onSubmitted: (_) =>
                Navigator.of(context).pop(_parseMm(controller.text)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_parseMm(controller.text)),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  if (result != null) {
    await ref.read(interLensGapProvider.notifier).setMm(result.clamp(0, 50));
  }
}

double? _parseMm(String text) => double.tryParse(text.replaceAll(',', '.'));

String _formatMm(double mm) => mm.toStringAsFixed(1).replaceAll('.', ',');
