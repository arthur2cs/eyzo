import 'package:flutter/material.dart';

import '../models/target_screen.dart';

/// Sélecteur d'écran cible (gauche / droit / les deux) — contenu indépendant par écran
/// (voir specs.md §3.4 des échanges de cadrage / §6.2 champ SCREEN).
class TargetScreenSelector extends StatelessWidget {
  const TargetScreenSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TargetScreen value;
  final ValueChanged<TargetScreen> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TargetScreen>(
      segments: TargetScreen.values
          .map((s) => ButtonSegment(value: s, label: Text(s.label)))
          .toList(),
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );
  }
}
