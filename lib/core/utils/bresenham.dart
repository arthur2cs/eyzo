/// Points d'une ligne discrète entre deux cellules de grille (algorithme de Bresenham).
List<(int, int)> bresenhamLine(int x0, int y0, int x1, int y1) {
  final points = <(int, int)>[];
  var x = x0;
  var y = y0;
  final dx = (x1 - x0).abs();
  final dy = -(y1 - y0).abs();
  final sx = x0 < x1 ? 1 : -1;
  final sy = y0 < y1 ? 1 : -1;
  var err = dx + dy;

  while (true) {
    points.add((x, y));
    if (x == x1 && y == y1) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y += sy;
    }
  }
  return points;
}
