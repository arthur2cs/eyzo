/// Caractéristiques de l'écran physique des lunettes et grilles de travail
/// associées (voir specs.md §2, §4.4, §4.5, §9). Point d'entrée unique pour
/// toute logique dépendant de la résolution du panneau (éditeur, import,
/// aperçus, conversion d'image).
class GlassesDisplay {
  GlassesDisplay._();

  /// Diagonale de la dalle, en pouces.
  static const double diagonalInches = 1.77;

  /// Résolution native du panneau ST7735S (128x160 en orientation portrait),
  /// monté dans les lunettes en orientation **paysage** — largeur et hauteur
  /// sont donc inversées par rapport à la fiche technique du panneau (voir
  /// specs.md §2).
  static const int nativeWidth = 160;
  static const int nativeHeight = 128;
  static const (int, int) nativeResolution = (nativeWidth, nativeHeight);

  /// Dimensions physiques d'un écran en mode paysage, en mm — sert à convertir
  /// l'espace inter-écran réglable par l'utilisateur (voir [SettingsStore])
  /// en délai de traversée dans l'aperçu du mode séquentiel (specs.md §4.2).
  static const double lensWidthMm = 35.0;
  static const double lensHeightMm = 28.0;

  /// Résolution de travail par défaut pour l'éditeur pixel-art, l'import
  /// d'image/GIF, etc. — le firmware fait l'upscale nearest-neighbor vers
  /// la résolution native (voir specs.md §4.5).
  static const int defaultWorkingWidth = 40;
  static const int defaultWorkingHeight = 32;

  /// Presets proposés à l'utilisateur, dans le même ratio 5:4 que la dalle
  /// native. Le plein format natif est disponible en option (voir specs.md
  /// §9 pour le coût en transfert BLE).
  static const List<(int, int)> availableWorkingSizes = [
    (40, 32),
    (80, 64),
    nativeResolution,
  ];

  /// Ratio d'aperçu utilisé par [GlassesScreenFrame] — choix esthétique
  /// (plus large que haut) pour un rendu plus proche d'un vrai petit écran
  /// de lunettes, indépendant de la résolution réelle des données envoyées
  /// (voir specs.md §3).
  static const double previewAspectRatio = 3 / 2;
}
