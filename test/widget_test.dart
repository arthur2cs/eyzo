// Test unitaire du protocole BLE (voir specs.md §6) : vérifie le format de trame
// (en-tête, chunking, checksum) indépendamment de l'UI/Hive.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:eyzo/core/ble/eyzo_protocol.dart';
import 'package:eyzo/core/ble/packet_builder.dart';
import 'package:eyzo/models/pixel_animation.dart';
import 'package:eyzo/models/scroll_direction_mode.dart';
import 'package:eyzo/models/target_screen.dart';
import 'package:eyzo/models/text_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void expectValidFraming(
    List<Uint8List> chunks, {
    required int cmd,
    required int screen,
  }) {
    for (var i = 0; i < chunks.length; i++) {
      final frame = chunks[i];
      expect(frame[0], EyzoProtocol.startOfFrame);
      expect(frame[1], cmd);
      expect(frame[2], screen);

      final seq = frame[3] | (frame[4] << 8);
      final total = frame[5] | (frame[6] << 8);
      expect(seq, i);
      expect(total, chunks.length);

      var checksum = 0;
      for (var j = 0; j < frame.length - 1; j++) {
        checksum ^= frame[j];
      }
      expect(frame.last, checksum);
    }
  }

  test(
    'setText (texte statique bien compressible) produit un unique chunk '
    'BLE valide, compressé en zlib',
    () async {
      const content = TextContent(
        text: 'Salut',
        direction: ScrollDirectionMode.static_,
      );
      final chunks = await EyzoPacketBuilder.setText(
        TargetScreen.left,
        content,
      );

      // Fond uni (texte court sur fond noir) : la compression zlib (voir
      // packet_builder.dart) fait tenir le bitmap plein écran (160x128) dans
      // un seul chunk BLE, là où il en fallait plusieurs dizaines en brut.
      expect(chunks.length, 1);
      // format = 1 (zlib) à l'offset 9 du payload SET_TEXT (voir specs.md
      // §6.3), donc à l'offset 9 (en-tête de chunk) + 9 = 18 dans la trame.
      expect(chunks[0][18], EyzoProtocol.pixelFormatZlib);

      expectValidFraming(
        chunks,
        cmd: EyzoProtocol.cmdSetText,
        screen: TargetScreen.left.byte,
      );
    },
  );

  test(
    'un texte défilant plus long est découpé en plusieurs chunks numérotés',
    () async {
      // Assez long pour dépasser un chunk BLE même après compression zlib
      // (voir maxChunkPayload), sans dépasser maxPayloadSize.
      final chunks = await EyzoPacketBuilder.setText(
        TargetScreen.simultaneous,
        TextContent(
          text: 'Bonjour ' * 2,
          direction: ScrollDirectionMode.leftward,
        ),
      );

      expect(chunks.length, greaterThan(1));
      expectValidFraming(
        chunks,
        cmd: EyzoProtocol.cmdSetText,
        screen: TargetScreen.simultaneous.byte,
      );
    },
  );

  test(
    'un texte défilant trop volumineux est rejeté avant l\'envoi',
    () async {
      final content = TextContent(
        text: 'A' * 200,
        size: 10,
        direction: ScrollDirectionMode.leftward,
      );

      await expectLater(
        EyzoPacketBuilder.setText(TargetScreen.simultaneous, content),
        throwsArgumentError,
      );
    },
  );

  test(
    'setAnimation regroupe toutes les frames dans une seule commande BLE '
    'valide',
    () {
      final animation = PixelAnimation(
        frames: [
          PixelFrame.blank(4, 4, fillRgb565: 0xffff),
          PixelFrame.blank(4, 4, fillRgb565: 0xffff),
          PixelFrame.blank(4, 4, fillRgb565: 0x0000),
        ],
        frameDelayMs: 80,
      );

      final chunks = EyzoPacketBuilder.setAnimation(
        TargetScreen.simultaneous,
        animation,
      );

      expectValidFraming(
        chunks,
        cmd: EyzoProtocol.cmdSetAnimation,
        screen: TargetScreen.simultaneous.byte,
      );

      // Reconstitue le payload SET_ANIMATION (voir specs.md §6.3) à partir
      // des chunks pour vérifier son en-tête fixe : width(1) | height(1) |
      // frame_count(1) | frame_delay_ms(2 LE) | format(1) | data.
      final payload = <int>[
        for (final chunk in chunks) ...chunk.sublist(9, chunk.length - 1),
      ];
      expect(payload[0], 4); // width
      expect(payload[1], 4); // height
      expect(payload[2], 3); // frame_count
      expect(payload[3] | (payload[4] << 8), 80); // frame_delay_ms
      expect(
        payload[5],
        anyOf(EyzoProtocol.pixelFormatRaw, EyzoProtocol.pixelFormatZlib),
      );
    },
  );

  test(
    'des frames très similaires compressées ensemble tiennent en bien '
    'moins que leur poids brut cumulé',
    () {
      // 10 frames quasi identiques (40x32, un pixel qui varie un peu) :
      // 25 600 octets bruts cumulés — la compression zlib sur le bloc
      // combiné (voir packet_builder.dart) doit exploiter la ressemblance
      // entre frames, pas juste celle à l'intérieur d'une frame.
      final frames = List.generate(
        10,
        (i) => PixelFrame.blank(40, 32, fillRgb565: 0x1234 + i),
      );
      final animation = PixelAnimation(frames: frames, frameDelayMs: 100);

      final chunks = EyzoPacketBuilder.setAnimation(
        TargetScreen.simultaneous,
        animation,
      );
      final totalWireBytes = chunks.fold<int>(0, (sum, c) => sum + c.length);

      expect(totalWireBytes, lessThan(500));
    },
  );

  test(
    'une animation avec trop de frames est rejetée avant l\'envoi',
    () {
      final animation = PixelAnimation(
        frames: List.generate(
          EyzoProtocol.maxAnimationFrames + 1,
          (_) => PixelFrame.blank(4, 4),
        ),
      );

      expect(
        () => EyzoPacketBuilder.setAnimation(TargetScreen.simultaneous, animation),
        throwsArgumentError,
      );
    },
  );
}
