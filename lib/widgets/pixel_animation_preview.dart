import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/pixel_animation.dart';
import 'glasses_screen_frame.dart';
import 'pixel_frame_painter.dart';

/// Aperçu animé d'une [PixelAnimation] dans un cadre simulant l'écran des lunettes.
class PixelAnimationPreview extends StatefulWidget {
  const PixelAnimationPreview({
    super.key,
    required this.animation,
    this.width = 160,
    this.active = true,
  });

  final PixelAnimation animation;
  final double width;

  /// Si false, simule un écran éteint (verre non ciblé par l'envoi en cours).
  final bool active;

  @override
  State<PixelAnimationPreview> createState() => _PixelAnimationPreviewState();
}

class _PixelAnimationPreviewState extends State<PixelAnimationPreview> {
  Timer? _timer;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PixelAnimationPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _frameIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.animation.frames.length <= 1) return;
    _timer = Timer.periodic(
      Duration(milliseconds: widget.animation.frameDelayMs),
      (_) {
        if (!mounted) return;
        setState(
          () =>
              _frameIndex = (_frameIndex + 1) % widget.animation.frames.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return GlassesScreenFrame(
        width: widget.width,
        backgroundColor: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(
            Icons.power_settings_new,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    if (widget.animation.frames.isEmpty) {
      return GlassesScreenFrame(
        width: widget.width,
        child: const SizedBox.shrink(),
      );
    }
    final frame =
        widget.animation.frames[_frameIndex % widget.animation.frames.length];
    return GlassesScreenFrame(
      width: widget.width,
      child: CustomPaint(
        painter: PixelFramePainter(frame),
        size: Size.infinite,
      ),
    );
  }
}
