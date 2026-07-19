import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/constants.dart';
import '../../core/storage/favorites_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/color_convert.dart';
import '../../models/favorite_item.dart';
import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../widgets/color_swatch_picker.dart';
import '../../widgets/pixel_frame_painter.dart';
import '../../widgets/save_favorite_dialog.dart';
import '../../widgets/target_screen_selector.dart';
import 'editor_tool.dart';
import 'pixel_art_canvas.dart';

const int _eraseColor = 0x0000;

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, this.initialAnimation, this.initialTarget});

  final PixelAnimation? initialAnimation;
  final TargetScreen? initialTarget;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final List<PixelFrame> _frames = widget.initialAnimation != null
      ? List.of(widget.initialAnimation!.frames)
      : [PixelFrame.blank(EyzoGrid.defaultWidth, EyzoGrid.defaultHeight, fillRgb565: _eraseColor)];
  int _currentIndex = 0;
  late int _frameDelayMs = widget.initialAnimation?.frameDelayMs ?? 150;
  EditorTool _tool = EditorTool.pixel;
  Color _drawColor = Colors.white;
  late TargetScreen _target = widget.initialTarget ?? TargetScreen.both;
  bool _sending = false;

  PixelFrame get _currentFrame => _frames[_currentIndex];

  void _updateCurrentFrame(PixelFrame frame) {
    setState(() => _frames[_currentIndex] = frame);
  }

  void _addFrame() {
    setState(() {
      _frames.insert(_currentIndex + 1, _currentFrame.copyWith());
      _currentIndex++;
    });
  }

  void _deleteFrame() {
    if (_frames.length <= 1) return;
    setState(() {
      _frames.removeAt(_currentIndex);
      _currentIndex = _currentIndex.clamp(0, _frames.length - 1);
    });
  }

  void _clearFrame() {
    setState(() {
      _frames[_currentIndex] = PixelFrame.blank(
        _currentFrame.width,
        _currentFrame.height,
        fillRgb565: _eraseColor,
      );
    });
  }

  PixelAnimation get _animation => PixelAnimation(frames: _frames, frameDelayMs: _frameDelayMs);

  Future<void> _send() async {
    final connected = ref.read(connectionStateProvider).value == BleConnectionState.connected;
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lunettes non connectées.')));
      return;
    }
    setState(() => _sending = true);
    try {
      if (_frames.length > 1) {
        await ref.read(bleServiceProvider).sendAnimation(_target, _animation);
      } else {
        await ref.read(bleServiceProvider).sendStaticImage(_target, _currentFrame);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dessin envoyé.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Échec de l\'envoi : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveFavorite() async {
    final name = await showSaveFavoriteDialog(context, initialName: 'Mon dessin');
    if (name == null || name.isEmpty) return;
    await ref.read(favoritesProvider.notifier).add(
          FavoriteItem(
            id: const Uuid().v4(),
            name: name,
            type: FavoriteType.animation,
            createdAt: DateTime.now(),
            targetScreen: _target,
            animation: _animation,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajouté aux favoris.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditeur pixel-art'),
        actions: [
          IconButton(onPressed: _saveFavorite, icon: const Icon(Icons.bookmark_add_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 240,
              child: PixelArtCanvas(
                frame: _currentFrame,
                tool: _tool,
                drawColor: colorToRgb565(_drawColor),
                eraseColor: _eraseColor,
                onFrameChanged: _updateCurrentFrame,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            alignment: WrapAlignment.center,
            children: EditorTool.values.map((tool) {
              return ChoiceChip(
                label: Text(tool.label),
                selected: _tool == tool,
                onSelected: (_) => setState(() => _tool = tool),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _clearFrame,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Effacer la frame'),
          ),
          const SizedBox(height: 8),
          const Text('Couleur', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          ColorSwatchPicker(value: _drawColor, onChanged: (c) => setState(() => _drawColor = c)),
          const SizedBox(height: 24),
          Row(
            children: [
              const Text('Frames', style: TextStyle(color: AppColors.textSecondary)),
              const Spacer(),
              IconButton(
                onPressed: _frames.length > 1 ? _deleteFrame : null,
                icon: const Icon(Icons.delete_outline),
              ),
              IconButton(onPressed: _addFrame, icon: const Icon(Icons.add_box_outlined)),
            ],
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _frames.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _currentIndex;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = index),
                  child: Container(
                    width: 48,
                    decoration: BoxDecoration(
                      border: Border.all(color: selected ? AppColors.textPrimary : AppColors.border, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(painter: PixelFramePainter(_frames[index])),
                  ),
                );
              },
            ),
          ),
          if (_frames.length > 1) ...[
            const SizedBox(height: 16),
            const Text('Délai entre frames', style: TextStyle(color: AppColors.textSecondary)),
            Slider(
              value: _frameDelayMs.toDouble(),
              min: 50,
              max: 1000,
              divisions: 19,
              label: '$_frameDelayMs ms',
              onChanged: (v) => setState(() => _frameDelayMs = v.round()),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Écran cible', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TargetScreenSelector(value: _target, onChanged: (v) => setState(() => _target = v)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Envoi…' : 'Envoyer aux lunettes'),
          ),
        ],
      ),
    );
  }
}
