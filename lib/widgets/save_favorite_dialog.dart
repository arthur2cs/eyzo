import 'package:flutter/material.dart';

Future<String?> showSaveFavoriteDialog(BuildContext context, {String initialName = ''}) {
  final controller = TextEditingController(text: initialName);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Ajouter aux favoris'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Nom du favori'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
