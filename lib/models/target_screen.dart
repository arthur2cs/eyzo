/// Écran(s) cible(s) sur les lunettes (voir specs.md §6.2 — champ SCREEN).
enum TargetScreen {
  left(0x00, 'Gauche'),
  right(0x01, 'Droit'),
  simultaneous(0x02, 'Simultané'),

  /// Texte uniquement : les 2 écrans forment une seule bande de défilement continue
  /// (voir specs.md §4.2 et §6.3 — l'écran de départ dépend de la direction).
  sequential(0x03, 'Séquentiel');

  const TargetScreen(this.byte, this.label);

  final int byte;
  final String label;

  /// Le verre GAUCHE du porteur reçoit-il du contenu ?
  bool get showsLeft => this != TargetScreen.right;

  /// Le verre DROIT du porteur reçoit-il du contenu ?
  bool get showsRight => this != TargetScreen.left;
}
