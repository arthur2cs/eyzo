import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/storage/favorites_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../widgets/pixel_animation_preview.dart';
import '../../widgets/save_favorite_dialog.dart';
import '../../widgets/target_screen_selector.dart';
import 'preset_animations.dart';

class AnimationsScreen extends ConsumerStatefulWidget {
  const AnimationsScreen({super.key});

  @override
  ConsumerState<AnimationsScreen> createState() => _AnimationsScreenState();
}

class _AnimationsScreenState extends ConsumerState<AnimationsScreen> {
  AnimationPreset _selected = kAnimationPresets.first;
  late PixelAnimation _animation = _selected.build();
  TargetScreen _target = TargetScreen.both;
  bool _sending = false;

  void _select(AnimationPreset preset) {
    setState(() {
      _selected = preset;
      _animation = preset.build();
    });
  }

  Future<void> _send() async {
    final connected = ref.read(connectionStateProvider).value == BleConnectionState.connected;
    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lunettes non connectées.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(bleServiceProvider).sendAnimation(_target, _animation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Animation envoyée.')));
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
    final name = await showSaveFavoriteDialog(context, initialName: _selected.name);
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
        title: const Text('Animations'),
        actions: [
          IconButton(onPressed: _saveFavorite, icon: const Icon(Icons.bookmark_add_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: PixelAnimationPreview(animation: _animation, width: 180)),
          const SizedBox(height: 24),
          const Text('Bibliothèque', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: kAnimationPresets.map((preset) {
              final selected = preset.id == _selected.id;
              return GestureDetector(
                onTap: () => _select(preset),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: selected ? AppColors.textPrimary : AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(preset.icon, size: 28),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          preset.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
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
