import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

Future<String?> showSaveFavoriteDialog(
  BuildContext context, {
  String initialName = '',
}) {
  final controller = TextEditingController(text: initialName);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nom du favori',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nom du favori…'),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
