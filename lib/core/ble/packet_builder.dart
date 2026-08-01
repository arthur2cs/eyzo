import 'dart:convert';
import 'dart:typed_data';

import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../models/text_content.dart';
import '../utils/color_convert.dart';
import 'eyzo_protocol.dart';

/// Construit les trames binaires envoyées sur la caractéristique Commande.
/// Format détaillé en specs.md §6.2/§6.3.
class EyzoPacketBuilder {
  EyzoPacketBuilder._();

  static List<Uint8List> setText(TargetScreen screen, TextContent content) {
    final payload = BytesBuilder();
    payload.addByte(content.font.id);
    payload.addByte(content.size);
    payload.add(_uint16le(colorToRgb565(content.colorFg)));
    payload.add(_uint16le(colorToRgb565(content.colorBg)));
    payload.addByte(content.speed);
    payload.addByte(content.direction.byte);
    final textBytes = utf8.encode(content.renderedText);
    payload.add(_uint16le(textBytes.length));
    payload.add(textBytes);
    return _chunk(
      cmd: EyzoProtocol.cmdSetText,
      screen: screen,
      payload: payload.toBytes(),
    );
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
    final payload = BytesBuilder();
    payload.addByte(frame.width);
    payload.addByte(frame.height);
    payload.addByte(frameIndex);
    payload.addByte(totalFrames);
    payload.add(_uint16le(frameDelayMs));
    payload.add(_uint16le(frame.pixelsRgb565.length));
    payload.add(frame.pixelsRgb565);
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
