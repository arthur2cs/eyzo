/// Résolution de travail basse (éditeur pixel-art, presets, import) — voir specs.md §4.5.
/// Le firmware fait l'upscale nearest-neighbor vers les 240x320 réels de l'écran.
class EyzoGrid {
  EyzoGrid._();

  static const int defaultWidth = 32;
  static const int defaultHeight = 42;

  /// Résolution native de l'écran ST7789V (voir specs.md §2) — disponible en option
  /// pour l'import d'image/GIF, au prix d'un transfert BLE plus lent (voir specs.md §9).
  static const (int, int) fullResolution = (240, 320);

  static const List<(int, int)> availableSizes = [
    (32, 42),
    (64, 84),
    fullResolution,
  ];
}
