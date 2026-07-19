/// Résolution de travail basse (éditeur pixel-art, presets, import) — voir specs.md §4.5.
/// Le firmware fait l'upscale nearest-neighbor vers les 240x320 réels de l'écran.
class EyzoGrid {
  EyzoGrid._();

  static const int defaultWidth = 32;
  static const int defaultHeight = 42;

  static const List<(int, int)> availableSizes = [(32, 42), (64, 84)];
}
