import 'package:flutter/material.dart';

/// Quand le clavier système se ferme (y compris via le bouton retour Android,
/// qui ne redonne PAS automatiquement le focus perdu par le TextField),
/// force la perte de focus du champ actif. Sans ça, le champ reste affiché
/// "en attente de saisie" (curseur clignotant, encadré de focus) alors que
/// le clavier a disparu — comme si la saisie n'avait pas été validée
/// (voir specs.md §3).
class KeyboardDismissUnfocus extends StatefulWidget {
  const KeyboardDismissUnfocus({super.key, required this.child});

  final Widget child;

  @override
  State<KeyboardDismissUnfocus> createState() => _KeyboardDismissUnfocusState();
}

class _KeyboardDismissUnfocusState extends State<KeyboardDismissUnfocus>
    with WidgetsBindingObserver {
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final isKeyboardVisible = bottomInset > 0;
    if (_wasKeyboardVisible && !isKeyboardVisible) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    _wasKeyboardVisible = isKeyboardVisible;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
