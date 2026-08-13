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

  /// Taille max de payload par chunk BLE. Valeur de repli conservatrice
  /// avant toute négociation MTU ; ajustée à la hausse par
  /// [EyzoBleService] une fois le MTU réellement négocié connu (voir
  /// `_updateChunkPayloadSize`) — moins de chunks pour une même quantité de
  /// données, donc moins d'allers-retours BLE et un envoi plus rapide,
  /// particulièrement sensible pour les animations/GIF (beaucoup de chunks
  /// cumulés sur toutes les frames).
  static int maxChunkPayload = 180;

  /// Taille fixe de l'en-tête de chunk BLE (SOF+CMD+SCREEN+SEQ+TOTAL+LEN,
  /// voir specs.md §6.2), hors payload et checksum.
  static const int chunkHeaderLen = 9;

  /// Taille du checksum XOR en fin de chunk BLE (voir specs.md §6.2).
  static const int chunkChecksumLen = 1;

  /// MTU cible demandé à la connexion pour maximiser le débit utile.
  static const int requestedMtu = 247;

  /// Taille max du payload réassemblé pour une seule commande, **avant**
  /// compression (tenu en synchro avec `MAX_PAYLOAD_SIZE` dans config.h côté
  /// firmware, deux buffers de cette taille alloués en PSRAM : réassemblage
  /// + décompression). Doit couvrir le plus gros cas d'usage : une animation
  /// complète envoyée en un seul bloc (voir `setAnimation` dans
  /// packet_builder.dart) — jusqu'à ~1,2 Mo en résolution de travail native
  /// (160x128) au nombre de frames par défaut de l'app (30, voir
  /// image_conversion.dart), avec de la marge. Une image plein écran
  /// (~41 Ko) ou un bitmap de texte défilant tiennent très largement dedans.
  static const int maxPayloadSize = 1500000;

  /// Nombre max de frames d'une animation (tenu en synchro avec
  /// `MAX_ANIMATION_FRAMES` dans config.h côté firmware, dimensionne
  /// l'allocation PSRAM par écran des animations déjà affichées).
  static const int maxAnimationFrames = 64;

  // --- Commandes ---
  static const int cmdSetText = 0x01;
  static const int cmdSetStaticImage = 0x02;
  static const int cmdSetAnimation = 0x03;
  static const int cmdClearScreen = 0x04;
  static const int cmdPing = 0x05;
  static const int cmdGetStatus = 0x06;

  /// Format des données pixels dans les payloads SET_TEXT / SET_STATIC_IMAGE /
  /// SET_ANIMATION (voir packet_builder.dart) : brutes ou compressées
  /// zlib (RFC1950, `package:archive` côté app, `zlib_turbo` côté firmware,
  /// voir firmware/README.md). Le firmware ne recompresse jamais rien : ce
  /// champ ne s'applique qu'au sens App -> ESP32.
  static const int pixelFormatRaw = 0x00;
  static const int pixelFormatZlib = 0x01;

  // --- Caractéristique Événement (ESP32 -> téléphone), voir ble_manager.cpp
  // et protocol.h côté firmware — miroir exact. ---
  static const int eventSof = 0xAA;
  static const int evtAck = 0x01; // payload: cmd, screen
  static const int evtNack = 0x02; // payload: cmd, screen, errorCode
  static const int evtStatus = 0x03; // payload: connected, leftOk, rightOk, pairingMode
  static const int evtPairing = 0x04; // payload: active (0/1)

  static const int errChecksum = 0x01;
  static const int errOverflow = 0x02;
  static const int errUnknownCmd = 0x03;
  static const int errSeqMismatch = 0x04;
  static const int errDecompress = 0x05;

  /// Délai max d'attente de l'ACK/NACK applicatif du firmware après le
  /// dernier chunk d'une commande (voir _writeChunks dans
  /// eyzo_ble_service.dart) — au-delà, on considère la commande perdue.
  static const Duration ackTimeout = Duration(seconds: 5);
}
