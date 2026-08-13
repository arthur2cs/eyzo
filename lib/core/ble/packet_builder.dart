import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../models/text_content.dart';
import '../utils/text_bitmap_renderer.dart';
import 'eyzo_protocol.dart';

/// Construit les trames binaires envoyées sur la caractéristique Commande.
/// Format détaillé en specs.md §6.2/§6.3.
class EyzoPacketBuilder {
  EyzoPacketBuilder._();

  /// Rend [content] en bitmap RGB565 (voir text_bitmap_renderer.dart, fidèle
  /// à l'aperçu) et construit la trame `SET_TEXT` correspondante. Le firmware
  /// ne fait plus de rendu de police : il affiche/défile ce bitmap tel quel.
  static Future<List<Uint8List>> setText(
    TargetScreen screen,
    TextContent content,
  ) async {
    final bitmap = await renderTextBitmap(content);
    final pixels = bitmap.frame.pixelsRgb565;

    // Validation sur la taille brute (avant compression) : c'est elle qui
    // borne le buffer de décompression PSRAM côté firmware (MAX_PAYLOAD_SIZE,
    // voir ble_manager.cpp), la taille effectivement transmise sur le lien
    // BLE étant elle réduite par la compression ci-dessous.
    final rawLen = 7 + pixels.length;
    if (rawLen > EyzoProtocol.maxPayloadSize) {
      throw ArgumentError(
        'Texte trop volumineux pour être envoyé ($rawLen octets) : '
        'réduisez le message ou la taille de police.',
      );
    }

    final (format, data) = _encodePixels(pixels);

    final payload = BytesBuilder();
    payload.addByte(content.direction.byte);
    payload.addByte(content.speed);
    payload.add(_uint16le(bitmap.colorBgRgb565));
    payload.add(_uint16le(bitmap.frame.width));
    payload.addByte(bitmap.frame.height);
    payload.addByte(format);
    payload.add(data);

    return _chunk(
      cmd: EyzoProtocol.cmdSetText,
      screen: screen,
      payload: payload.toBytes(),
    );
  }

  /// Compresse [raw] en zlib (RFC1950 — décompressable par la lib
  /// `zlib_turbo` côté firmware, voir firmware/README.md) si ça réduit
  /// effectivement la taille transmise sur le lien BLE ; sinon renvoie les
  /// données brutes telles quelles (jamais de régression de taille pour un
  /// contenu peu compressible, ex. image très texturée/bruitée).
  static (int format, Uint8List data) _encodePixels(Uint8List raw) {
    final compressed = const ZLibEncoder().encodeBytes(raw);
    if (compressed.length < raw.length) {
      return (EyzoProtocol.pixelFormatZlib, compressed);
    }
    return (EyzoProtocol.pixelFormatRaw, raw);
  }

  static List<Uint8List> setStaticImage(TargetScreen screen, PixelFrame frame) {
    final (format, data) = _encodePixels(frame.pixelsRgb565);

    final payload = BytesBuilder();
    payload.addByte(frame.width);
    payload.addByte(frame.height);
    payload.addByte(format);
    payload.add(_uint16le(data.length));
    payload.add(data);

    return _chunk(
      cmd: EyzoProtocol.cmdSetStaticImage,
      screen: screen,
      payload: payload.toBytes(),
    );
  }

  /// Compresse toute l'animation **en un seul bloc** (une seule commande BLE)
  /// plutôt que frame par frame : zlib peut alors référencer les frames
  /// voisines, souvent très similaires d'une frame à l'autre pour un GIF
  /// (fond fixe, petite partie qui bouge), ce qu'une compression indépendante
  /// par frame ne permet jamais d'exploiter — et une seule commande au lieu
  /// d'une par frame réduit d'autant le nombre d'allers-retours BLE (voir
  /// specs.md §6.3/§9).
  static List<Uint8List> setAnimation(
    TargetScreen screen,
    PixelAnimation animation,
  ) {
    final frames = animation.frames;
    if (frames.isEmpty) return [];

    final width = frames.first.width;
    final height = frames.first.height;
    final frameCount = frames.length;
    if (frameCount > EyzoProtocol.maxAnimationFrames) {
      throw ArgumentError(
        'Trop de frames pour être envoyées ($frameCount, max '
        '${EyzoProtocol.maxAnimationFrames}).',
      );
    }

    final frameBytes = width * height * 2;
    final rawLen = 6 + frameBytes * frameCount;
    if (rawLen > EyzoProtocol.maxPayloadSize) {
      throw ArgumentError(
        'Animation trop volumineuse pour être envoyée ($rawLen octets) : '
        'réduisez la résolution de travail ou le nombre de frames.',
      );
    }

    final rawPixels = Uint8List(frameBytes * frameCount);
    var offset = 0;
    for (final frame in frames) {
      rawPixels.setRange(offset, offset + frameBytes, frame.pixelsRgb565);
      offset += frameBytes;
    }

    final (format, data) = _encodePixels(rawPixels);

    final payload = BytesBuilder();
    payload.addByte(width);
    payload.addByte(height);
    payload.addByte(frameCount);
    payload.add(_uint16le(animation.frameDelayMs));
    payload.addByte(format);
    payload.add(data);

    return _chunk(
      cmd: EyzoProtocol.cmdSetAnimation,
      screen: screen,
      payload: payload.toBytes(),
    );
  }

  static Uint8List clearScreen(TargetScreen screen) => _chunk(
    cmd: EyzoProtocol.cmdClearScreen,
    screen: screen,
    payload: Uint8List(0),
  ).first;

  static Uint8List ping() => _chunk(
    cmd: EyzoProtocol.cmdPing,
    screen: TargetScreen.simultaneous,
    payload: Uint8List(0),
  ).first;

  static Uint8List getStatus() => _chunk(
    cmd: EyzoProtocol.cmdGetStatus,
    screen: TargetScreen.simultaneous,
    payload: Uint8List(0),
  ).first;

  static List<Uint8List> _chunk({
    required int cmd,
    required TargetScreen screen,
    required Uint8List payload,
  }) {
    final chunks = <Uint8List>[];
    final totalChunks = payload.isEmpty
        ? 1
        : (payload.length / EyzoProtocol.maxChunkPayload).ceil();

    for (var i = 0; i < totalChunks; i++) {
      final start = i * EyzoProtocol.maxChunkPayload;
      final end = (start + EyzoProtocol.maxChunkPayload > payload.length)
          ? payload.length
          : start + EyzoProtocol.maxChunkPayload;
      final chunkPayload = payload.sublist(start, end);

      final header = BytesBuilder();
      header.addByte(EyzoProtocol.startOfFrame);
      header.addByte(cmd);
      header.addByte(screen.byte);
      header.add(_uint16le(i));
      header.add(_uint16le(totalChunks));
      header.add(_uint16le(chunkPayload.length));
      header.add(chunkPayload);

      final bytesSoFar = header.toBytes();
      final checksum = _xorChecksum(bytesSoFar);

      final frame = BytesBuilder();
      frame.add(bytesSoFar);
      frame.addByte(checksum);
      chunks.add(frame.toBytes());
    }
    return chunks;
  }

  static int _xorChecksum(Uint8List bytes) {
    var chk = 0;
    for (final b in bytes) {
      chk ^= b;
    }
    return chk & 0xFF;
  }

  static Uint8List _uint16le(int value) {
    final b = ByteData(2);
    b.setUint16(0, value & 0xFFFF, Endian.little);
    return b.buffer.asUint8List();
  }
}
