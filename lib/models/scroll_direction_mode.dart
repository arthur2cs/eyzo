/// Direction/mode d'affichage du texte défilant (voir specs.md §4.2 / §6.3).
enum ScrollDirectionMode {
  leftward(0x00, 'Défilement ← '),
  rightward(0x01, 'Défilement →'),
  static_(0x02, 'Statique'),
  blink(0x03, 'Clignotant');

  const ScrollDirectionMode(this.byte, this.label);

  final int byte;
  final String label;
}

/// Polices bitmap embarquées côté firmware (id à faire correspondre côté ESP32).
enum GlassesFont {
  classic(0, 'Classique'),
  bold(1, 'Bold'),
  mono(2, 'Mono'),
  pixel(3, 'Pixel');

  const GlassesFont(this.id, this.label);

  final int id;
  final String label;
}
