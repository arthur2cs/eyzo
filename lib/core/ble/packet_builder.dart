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
    final payload = _imagePayload(
      frame: frame,
      frameIndex: 0,
      totalFrames: 1,
      frameDelayMs: 0,
    );
    return _chunk(
      cmd: EyzoProtocol.cmdSetStaticImage,
      screen: screen,
      payload: payload,
    );
  }

  static List<Uint8List> _setAnimationFrame(
    TargetScreen screen,
    PixelFrame frame, {
    required int frameIndex,
    required int totalFrames,
    required int frameDelayMs,
  }) {
    final payload = _imagePayload(
      frame: frame,
      frameIndex: frameIndex,
      totalFrames: totalFrames,
      frameDelayMs: frameDelayMs,
    );
    return _chunk(
      cmd: EyzoProtocol.cmdSetAnimationFrame,
      screen: screen,
      payload: payload,
    );
  }

  /// Une entrée de la liste retournée = l'ensemble des chunks BLE d'une frame de l'animation.
  static List<List<Uint8List>> setAnimation(
    TargetScreen screen,
    PixelAnimation animation,
  ) {
    return [
      for (var i = 0; i < animation.frames.length; i++)
        _setAnimationFrame(
          screen,
          animation.frames[i],
          frameIndex: i,
          totalFrames: animation.frames.length,
          frameDelayMs: animation.frameDelayMs,
        ),
    ];
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

  static Uint8List _imagePayload({
    required PixelFrame frame,
    required int frameIndex,
    required int totalFrames,
    required int frameDelayMs,
  }) {
    // pixel_len (uint16) reste dans ses bornes : la résolution de travail
    // max (160x128, voir GlassesDisplay) donne 40 960 octets bruts, la
    // compression ne peut que réduire ce chiffre.
    final (format, data) = _encodePixels(frame.pixelsRgb565);

    final payload = BytesBuilder();
    payload.addByte(frame.width);
    payload.addByte(frame.height);
    payload.addByte(format);
    payload.addByte(frameIndex);
    payload.addByte(totalFrames);
    payload.add(_uint16le(frameDelayMs));
    payload.add(_uint16le(data.length));
    payload.add(data);
    return payload.toBytes();
  }

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
