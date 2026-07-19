import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/bresenham.dart';
import '../../core/utils/color_convert.dart';
import '../../core/utils/flood_fill.dart';
import '../../models/pixel_animation.dart';
import 'editor_tool.dart';

/// Grille de dessin pixel-art avec crayon / ligne / remplissage / gomme
/// (voir specs.md §4.5).
class PixelArtCanvas extends StatefulWidget {
  const PixelArtCanvas({
    super.key,
    required this.frame,
    required this.tool,
    required this.drawColor,
    required this.eraseColor,
    required this.onFrameChanged,
    this.onDrawingChanged,
  });

  final PixelFrame frame;
  final EditorTool tool;
  final int drawColor;
  final int eraseColor;
  final ValueChanged<PixelFrame> onFrameChanged;

  /// Signale le début/la fin d'un tracé, pour permettre au parent de désactiver
  /// temporairement le scroll de la page englobante et de préparer l'annulation
  /// (voir specs.md §4.5) — sans ça, un glissé à un doigt fait défiler la page
  /// au lieu de dessiner en continu.
  final ValueChanged<bool>? onDrawingChanged;

  @override
  State<PixelArtCanvas> createState() => _PixelArtCanvasState();
}

class _PixelArtCanvasState extends State<PixelArtCanvas> {
  (int, int)? _lineStart;
  (int, int)? _lineEnd;

  int get _activeColor =>
      widget.tool == EditorTool.eraser ? widget.eraseColor : widget.drawColor;

  (int, int)? _cellFromLocalPosition(Offset local, Size size) {
    final cellW = size.width / widget.frame.width;
    final cellH = size.height / widget.frame.height;
    final x = (local.dx / cellW).floor().clamp(0, widget.frame.width - 1);
    final y = (local.dy / cellH).floor().clamp(0, widget.frame.height - 1);
    return (x, y);
  }

  void _paintAt((int, int) cell) {
    widget.onFrameChanged(
      widget.frame.setPixel(cell.$1, cell.$2, _activeColor),
    );
  }

  void _handleStart(Offset local, Size size) {
    widget.onDrawingChanged?.call(true);
    final cell = _cellFromLocalPosition(local, size);
    if (cell == null) return;
    switch (widget.tool) {
      case EditorTool.pixel:
      case EditorTool.eraser:
        _paintAt(cell);
      case EditorTool.line:
        setState(() {
          _lineStart = cell;
          _lineEnd = cell;
        });
      case EditorTool.fill:
        widget.onFrameChanged(
          floodFill(widget.frame, cell.$1, cell.$2, _activeColor),
        );
    }
  }

  void _handleUpdate(Offset local, Size size) {
    final cell = _cellFromLocalPosition(local, size);
    if (cell == null) return;
    switch (widget.tool) {
      case EditorTool.pixel:
      case EditorTool.eraser:
        _paintAt(cell);
      case EditorTool.line:
        setState(() => _lineEnd = cell);
      case EditorTool.fill:
        break;
    }
  }

  void _handleEnd() {
    if (widget.tool == EditorTool.line &&
        _lineStart != null &&
        _lineEnd != null) {
      var frame = widget.frame;
      for (final (x, y) in bresenhamLine(
        _lineStart!.$1,
        _lineStart!.$2,
        _lineEnd!.$1,
        _lineEnd!.$2,
      )) {
        frame = frame.setPixel(x, y, _activeColor);
      }
      widget.onFrameChanged(frame);
    }
    setState(() {
      _lineStart = null;
      _lineEnd = null;
    });
    widget.onDrawingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.frame.width / widget.frame.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _handleStart(event.localPosition, size),
            onPointerMove: (event) => _handleUpdate(event.localPosition, size),
            onPointerUp: (_) => _handleEnd(),
            onPointerCancel: (_) => _handleEnd(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _CanvasPainter(
                  frame: widget.frame,
                  lineStart: _lineStart,
                  lineEnd: _lineEnd,
                  previewColor: _activeColor,
                ),
                size: size,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CanvasPainter extends CustomPainter {
  _CanvasPainter({
    required this.frame,
    required this.lineStart,
    required this.lineEnd,
    required this.previewColor,
  });

  final PixelFrame frame;
  final (int, int)? lineStart;
  final (int, int)? lineEnd;
  final int previewColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / frame.width;
    final cellH = size.height / frame.height;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < frame.height; y++) {
      for (var x = 0; x < frame.width; x++) {
        paint.color = rgb565ToColor(frame.getPixel(x, y));
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }

    if (lineStart != null && lineEnd != null) {
      paint.color = rgb565ToColor(previewColor).withValues(alpha: 0.6);
      for (final (x, y) in _previewLine()) {
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }
  }

  List<(int, int)> _previewLine() {
    if (lineStart == null || lineEnd == null) return const [];
    final points = <(int, int)>[];
    var x0 = lineStart!.$1, y0 = lineStart!.$2;
    final x1 = lineEnd!.$1, y1 = lineEnd!.$2;
    final dx = (x1 - x0).abs();
    final dy = -(y1 - y0).abs();
    final sx = x0 < x1 ? 1 : -1;
    final sy = y0 < y1 ? 1 : -1;
    var err = dx + dy;
    while (true) {
      points.add((x0, y0));
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
    return points;
  }

  @override
  bool shouldRepaint(covariant _CanvasPainter oldDelegate) =>
      oldDelegate.frame != frame ||
      oldDelegate.lineStart != lineStart ||
      oldDelegate.lineEnd != lineEnd;
}
