import 'package:flutter/services.dart';

/// Lit les octets d'une URI content:// (utilisé quand le clavier transmet un GIF
/// via une URI plutôt que des données inline — voir specs.md §4.3).
/// Passe par un canal natif Android (ContentResolver) : aucune API pure Dart
/// ne permet d'ouvrir une URI content:// directement.
class ContentUriReader {
  static const _channel = MethodChannel('eyzo/content_uri');

  Future<Uint8List> read(String uri) async {
    final bytes = await _channel.invokeMethod<Uint8List>('readContentUri', {
      'uri': uri,
    });
    if (bytes == null) {
      throw Exception('Lecture du contenu impossible.');
    }
    return bytes;
  }
}
