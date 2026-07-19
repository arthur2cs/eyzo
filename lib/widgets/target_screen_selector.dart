import 'package:flutter/material.dart';

import '../models/target_screen.dart';

/// Options par défaut : gauche / droit / simultané. Le mode "Séquentiel" n'est
/// pertinent que pour le texte défilant (voir specs.md §4.2) et doit être passé
/// explicitement via [options] là où il a du sens.
const List<TargetScreen> kDefaultTargetScreenOptions = [
  TargetScreen.left,
  TargetScreen.right,
  TargetScreen.simultaneous,
];

/// Sélecteur d'écran(s) cible(s) — contenu indépendant par écran
/// (voir specs.md §6.2 champ SCREEN).
class TargetScreenSelector extends StatelessWidget {
  const TargetScreenSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = kDefaultTargetScreenOptions,
  });

  final TargetScreen value;
  final ValueChanged<TargetScreen> onChanged;
  final List<TargetScreen> options;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TargetScreen>(
      segments: options
          .map((s) => ButtonSegment(value: s, label: Text(s.label)))
          .toList(),
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}
