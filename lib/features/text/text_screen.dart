import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/storage/favorites_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/favorite_item.dart';
import '../../models/scroll_direction_mode.dart';
import '../../models/target_screen.dart';
import '../../models/text_content.dart';
import '../../widgets/color_swatch_picker.dart';
import '../../widgets/dual_lens_row.dart';
import '../../widgets/lens_with_label.dart';
import '../../widgets/save_favorite_dialog.dart';
import '../../widgets/scrolling_text_preview.dart';
import '../../widgets/sequential_text_preview.dart';
import '../../widgets/target_screen_selector.dart';

class TextScreen extends ConsumerStatefulWidget {
  const TextScreen({super.key, this.initial});

  final TextContent? initial;

  @override
  ConsumerState<TextScreen> createState() => _TextScreenState();
}

class _TextScreenState extends ConsumerState<TextScreen> {
  late final TextEditingController _textController;
  late TextContent _content;
  TargetScreen _target = TargetScreen.simultaneous;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _content = widget.initial ?? const TextContent(text: '');
    _textController = TextEditingController(text: _content.text);
    _textController.addListener(() {
      setState(() => _content = _content.copyWith(text: _textController.text));
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final connected =
        ref.read(connectionStateProvider).value == BleConnectionState.connected;
    if (!connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lunettes non connectées.')));
      return;
    }
    if (_content.text.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(bleServiceProvider).sendText(_target, _content);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Texte envoyé.')));
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
    if (_content.text.trim().isEmpty) return;
    final name = await showSaveFavoriteDialog(
      context,
      initialName: _content.text,
    );
    if (name == null || name.isEmpty) return;
    await ref
        .read(favoritesProvider.notifier)
        .add(
          FavoriteItem(
            id: const Uuid().v4(),
            name: name,
            type: FavoriteType.text,
            createdAt: DateTime.now(),
            targetScreen: _target,
            textContent: _content,
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
        title: const Text('Texte défilant'),
        actions: [
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
              child: _target == TargetScreen.sequential
                  ? SequentialTextPreview(content: _content, lensWidth: 130)
                  : DualLensRow(
                      rightLens: LensWithLabel(
                        label: 'Droite',
                        lens: ScrollingTextPreview(
                          content: _content,
                          width: 130,
                          active: _target.showsRight,
                        ),
                      ),
                      leftLens: LensWithLabel(
                        label: 'Gauche',
                        lens: ScrollingTextPreview(
                          content: _content,
                          width: 130,
                          active: _target.showsLeft,
                        ),
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
              options: TargetScreen.values,
            ),
            const SizedBox(height: 24),
            const Text(
              'Message',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Votre texte…'),
            ),
            const SizedBox(height: 16),
            const Text(
              'Vitesse de défilement',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Slider(
              value: _content.speed.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '${_content.speed}',
              onChanged: (v) => setState(
                () => _content = _content.copyWith(speed: v.round()),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Taille du texte',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            Slider(
              value: _content.size.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              label: '${_content.size}',
              onChanged: (v) =>
                  setState(() => _content = _content.copyWith(size: v.round())),
            ),
            const SizedBox(height: 16),
            const Text(
              'Direction / mode',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ScrollDirectionMode.values.map((mode) {
                return ChoiceChip(
                  label: Text(mode.label),
                  selected: _content.direction == mode,
                  onSelected: (_) => setState(
                    () => _content = _content.copyWith(direction: mode),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Police',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: GlassesFont.values.map((font) {
                return ChoiceChip(
                  label: Text(font.label),
                  selected: _content.font == font,
                  onSelected: (_) =>
                      setState(() => _content = _content.copyWith(font: font)),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couleur du texte',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ColorSwatchPicker(
              value: _content.colorFg,
              onChanged: (c) =>
                  setState(() => _content = _content.copyWith(colorFg: c)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Couleur de fond',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ColorSwatchPicker(
              value: _content.colorBg,
              onChanged: (c) =>
                  setState(() => _content = _content.copyWith(colorBg: c)),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _sending ? null : _send,
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
