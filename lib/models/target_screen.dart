/// Écran cible sur les lunettes (voir specs.md §6.2 — champ SCREEN).
enum TargetScreen {
  left(0x00, 'Gauche'),
  right(0x01, 'Droit'),
  both(0x02, 'Les deux');

  const TargetScreen(this.byte, this.label);

  final int byte;
  final String label;

  /// Le verre GAUCHE du porteur reçoit-il du contenu ?
  bool get showsLeft => this == TargetScreen.left || this == TargetScreen.both;

  /// Le verre DROIT du porteur reçoit-il du contenu ?
  bool get showsRight =>
      this == TargetScreen.right || this == TargetScreen.both;
}
