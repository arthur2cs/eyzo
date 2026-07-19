// Test unitaire du protocole BLE (voir specs.md §6) : vérifie le format de trame
// (en-tête, chunking, checksum) indépendamment de l'UI/Hive.
import 'package:flutter_test/flutter_test.dart';

import 'package:eyzo/core/ble/eyzo_protocol.dart';
import 'package:eyzo/core/ble/packet_builder.dart';
import 'package:eyzo/models/target_screen.dart';
import 'package:eyzo/models/text_content.dart';

void main() {
  test('setText produit une trame unique avec en-tête et checksum valides', () {
    const content = TextContent(text: 'Salut');
    final chunks = EyzoPacketBuilder.setText(TargetScreen.left, content);

    expect(chunks.length, 1);
    final frame = chunks.first;

    expect(frame[0], EyzoProtocol.startOfFrame);
    expect(frame[1], EyzoProtocol.cmdSetText);
    expect(frame[2], TargetScreen.left.byte);

    var checksum = 0;
    for (var i = 0; i < frame.length - 1; i++) {
      checksum ^= frame[i];
    }
    expect(frame.last, checksum);
  });

  test('un payload volumineux est découpé en plusieurs chunks numérotés', () {
    final longText = 'A' * 400;
    final chunks = EyzoPacketBuilder.setText(
      TargetScreen.simultaneous,
      TextContent(text: longText),
    );

    expect(chunks.length, greaterThan(1));
    for (var i = 0; i < chunks.length; i++) {
      final seq = chunks[i][3] | (chunks[i][4] << 8);
      expect(seq, i);
    }
  });
}
