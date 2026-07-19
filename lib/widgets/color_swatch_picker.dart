import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

const List<Color> kGlassesPalette = [
  Colors.white,
  Colors.black,
  Color(0xFFFF3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF00C7BE),
  Color(0xFF007AFF),
  Color(0xFF5856D6),
  Color(0xFFFF2D55),
  Color(0xFFAF52DE),
  Color(0xFF8E8E93),
];

/// Sélecteur de couleur simplifié (palette RGB565-friendly) — voir specs.md §4.2.
class ColorSwatchPicker extends StatelessWidget {
  const ColorSwatchPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kGlassesPalette.map((color) {
        final selected = color.toARGB32() == value.toARGB32();
        return GestureDetector(
          onTap: () => onChanged(color),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.textPrimary : AppColors.border,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
