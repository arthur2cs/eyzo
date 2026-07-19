/// Contrat BLE App <-> Firmware ESP32 (voir specs.md §6).
///
/// Ces UUID/valeurs sont des exemples à figer définitivement avec le firmware.
class EyzoProtocol {
  EyzoProtocol._();

  // --- GATT ---
  static const String serviceUuid = '4e4a0001-6f61-4c1e-8c3a-4e4a656f7a30';
  static const String commandCharUuid = '4e4a0002-6f61-4c1e-8c3a-4e4a656f7a30';
  static const String eventCharUuid = '4e4a0003-6f61-4c1e-8c3a-4e4a656f7a30';

  // Battery Service standard BLE (SIG)
  static const String batteryServiceUuid =
      '0000180f-0000-1000-8000-00805f9b34fb';
  static const String batteryLevelCharUuid =
      '00002a19-0000-1000-8000-00805f9b34fb';

  static const String deviceNamePrefix = 'Eyzo';

  // --- Trame ---
  static const int startOfFrame = 0xAA;

  /// Taille max de payload par chunk BLE (conservateur ; à affiner selon MTU négocié réel).
  static const int maxChunkPayload = 180;

  /// MTU cible demandé à la connexion pour maximiser le débit utile.
  static const int requestedMtu = 247;

  // --- Commandes ---
  static const int cmdSetText = 0x01;
  static const int cmdSetStaticImage = 0x02;
  static const int cmdSetAnimationFrame = 0x03;
  static const int cmdClearScreen = 0x04;
  static const int cmdPing = 0x05;
  static const int cmdGetStatus = 0x06;
}
