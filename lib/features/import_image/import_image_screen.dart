import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/constants.dart';
import '../../core/storage/favorites_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_conversion.dart';
import '../../models/favorite_item.dart';
import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../widgets/dual_lens_row.dart';
import '../../widgets/lens_with_label.dart';
import '../../widgets/pixel_animation_preview.dart';
import '../../widgets/save_favorite_dialog.dart';
import '../../widgets/target_screen_selector.dart';
import 'keyboard_gif_field.dart';

class ImportImageScreen extends ConsumerStatefulWidget {
  const ImportImageScreen({super.key});

  @override
  ConsumerState<ImportImageScreen> createState() => _ImportImageScreenState();
}

class _ImportImageScreenState extends ConsumerState<ImportImageScreen> {
  PixelAnimation? _animation;
  (int, int) _gridSize = (EyzoGrid.defaultWidth, EyzoGrid.defaultHeight);
  TargetScreen _target = TargetScreen.both;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  // Conservés pour pouvoir re-décoder si l'utilisateur change la résolution
  // de travail après import (voir specs.md §4.3).
  Uint8List? _sourceBytes;
  bool _sourceIsGif = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final isGif =
        file.path.toLowerCase().endsWith('.gif') ||
        (file.mimeType?.toLowerCase().contains('gif') ?? false);
    await _loadFromBytes(bytes, isGif: isGif);
  }

  Future<void> _loadFromBytes(Uint8List bytes, {required bool isGif}) async {
    setState(() {
      _loading = true;
      _error = null;
      _sourceBytes = bytes;
      _sourceIsGif = isGif;
    });
    try {
      final animation = decodeImageBytesToAnimation(
        bytes,
        isGif: isGif,
        gridWidth: _gridSize.$1,
        gridHeight: _gridSize.$2,
      );
      setState(() => _animation = animation);
    } catch (e) {
      setState(() => _error = 'Import impossible : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onGridSizeChanged((int, int) size) {
    setState(() => _gridSize = size);
    if (_sourceBytes != null) {
      _loadFromBytes(_sourceBytes!, isGif: _sourceIsGif);
    }
  }

  Future<void> _send() async {
    final animation = _animation;
    if (animation == null) return;
    final connected =
        ref.read(connectionStateProvider).value == BleConnectionState.connected;
    if (!connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lunettes non connectées.')));
      return;
    }
    setState(() => _sending = true);
    try {
      if (animation.frames.length > 1) {
        await ref.read(bleServiceProvider).sendAnimation(_target, animation);
      } else {
        await ref
            .read(bleServiceProvider)
            .sendStaticImage(_target, animation.frames.first);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image envoyée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Échec de l\'envoi : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveFavorite() async {
    final animation = _animation;
    if (animation == null) return;
    final name = await showSaveFavoriteDialog(
      context,
      initialName: 'Image importée',
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(favoritesProvider.notifier)
        .add(
          FavoriteItem(
            id: const Uuid().v4(),
            name: name,
            type: FavoriteType.animation,
            createdAt: DateTime.now(),
            targetScreen: _target,
            animation: animation,
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ajouté aux favoris.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import image / GIF'),
        actions: [
          if (_animation != null)
            IconButton(
              onPressed: _saveFavorite,
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Center(
              child: _loading
                  ? const SizedBox(
                      height: 180,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _animation != null
                  ? DualLensRow(
                      rightLens: LensWithLabel(
                        label: 'Droite',
                        lens: PixelAnimationPreview(
                          animation: _animation!,
                          width: 130,
                          active: _target.showsRight,
                        ),
                      ),
                      leftLens: LensWithLabel(
                        label: 'Gauche',
                        lens: PixelAnimationPreview(
                          animation: _animation!,
                          width: 130,
                          active: _target.showsLeft,
                        ),
                      ),
                    )
                  : Container(
                      width: 180,
                      height: 240,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.image_outlined,
                          size: 40,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _loading ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choisir depuis la galerie'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Insérer depuis le clavier (banque GIF)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            KeyboardGifField(
              onContentReceived: (bytes, isGif) =>
                  _loadFromBytes(bytes, isGif: isGif),
            ),
            const SizedBox(height: 24),
            const Text(
              'Résolution de travail',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: EyzoGrid.availableSizes.map((size) {
                final selected = size == _gridSize;
                final isFullRes = size == EyzoGrid.fullResolution;
                return ChoiceChip(
                  label: Text(
                    isFullRes
                        ? '${size.$1}x${size.$2} (plein écran)'
                        : '${size.$1}x${size.$2}',
                  ),
                  selected: selected,
                  onSelected: (_) => _onGridSizeChanged(size),
                );
              }).toList(),
            ),
            if (_gridSize == EyzoGrid.fullResolution)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Résolution native : transfert plus lent aux lunettes, surtout pour les animations multi-frames.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Écran cible',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TargetScreenSelector(
              value: _target,
              onChanged: (v) => setState(() => _target = v),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: (_animation == null || _sending) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Envoi…' : 'Envoyer aux lunettes'),
            ),
          ],
        ),
      ),
    );
  }
}
