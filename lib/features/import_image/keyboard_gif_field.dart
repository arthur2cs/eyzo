import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/content_uri_reader.dart';
import '../../core/theme/app_theme.dart';

/// Champ recevant un GIF inséré directement depuis la banque du clavier (Gboard, etc.)
/// via le mécanisme Android commitContent, exposé par Flutter sous
/// `contentInsertionConfiguration` (voir specs.md §4.3).
class KeyboardGifField extends StatefulWidget {
  const KeyboardGifField({super.key, required this.onContentReceived});

  final void Function(Uint8List bytes, bool isGif) onContentReceived;

  @override
  State<KeyboardGifField> createState() => _KeyboardGifFieldState();
}

class _KeyboardGifFieldState extends State<KeyboardGifField> {
  final _controller = TextEditingController();
  final _reader = ContentUriReader();
  bool _loading = false;
  String? _error;

  Future<void> _handleContent(KeyboardInsertedContent content) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = content.hasData
          ? content.data!
          : await _reader.read(content.uri);
      final isGif = content.mimeType.toLowerCase().contains('gif');
      widget.onContentReceived(bytes, isGif);
    } catch (e) {
      setState(() => _error = 'Insertion impossible : $e');
    } finally {
      _controller.clear();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Ouvrez le clavier ici puis choisissez un GIF…',
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.gif_box_outlined),
          ),
          contentInsertionConfiguration: ContentInsertionConfiguration(
            onContentInserted: _handleContent,
            // "image/*" en plus des types explicites : certains claviers/GIF
            // proposent des variantes (image/x-webp, etc.) non couvertes par une
            // liste stricte — voir specs.md §9 (comportement dépendant du clavier).
            allowedMimeTypes: const [
              'image/*',
              'image/gif',
              'image/png',
              'image/jpeg',
              'image/webp',
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Si un GIF ne s\'insère pas depuis le clavier, importez-le depuis la galerie à la place.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
