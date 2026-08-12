// Test unitaire du protocole BLE (voir specs.md §6) : vérifie le format de trame
// (en-tête, chunking, checksum) indépendamment de l'UI/Hive.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:eyzo/core/ble/eyzo_protocol.dart';
import 'package:eyzo/core/ble/packet_builder.dart';
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
      // format = 1 (zlib) à l'offset 7 du payload SET_TEXT (voir specs.md
      // §6.3), donc à l'offset 9 (en-tête de chunk) + 7 = 16 dans la trame.
      expect(chunks[0][16], EyzoProtocol.pixelFormatZlib);

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
}
