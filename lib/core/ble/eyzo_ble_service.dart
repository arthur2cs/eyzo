import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../models/pixel_animation.dart';
import '../../models/target_screen.dart';
import '../../models/text_content.dart';
import 'ble_connection_state.dart';
import 'eyzo_protocol.dart';
import 'packet_builder.dart';

/// Encapsule toute l'interaction BLE avec les lunettes Eyzo :
/// scan, connexion/reconnexion, découverte des services, envoi des commandes,
/// écoute des événements et de la batterie (voir specs.md §6).
class EyzoBleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;

  StreamSubscription<BluetoothConnectionState>? _connSub;
  StreamSubscription<List<int>>? _eventSub;
  StreamSubscription<List<int>>? _batterySub;

  // ACK/NACK applicatif de la commande en cours d'envoi (voir _writeChunks /
  // _onEvent) : un seul transfert à la fois (voir _runExclusive), donc pas
  // besoin de corréler par un identifiant de requête, seulement par
  // cmd+screen pour ignorer un éventuel événement résiduel d'une commande
  // précédente déjà abandonnée (timeout).
  Completer<_AckOutcome>? _pendingAck;
  int? _pendingCmd;
  int? _pendingScreen;

  // Sérialise tous les envois (sendText/sendStaticImage/sendAnimation/...)
  // sur la caractéristique Commande, et permet à un nouvel envoi d'abandonner
  // proprement un envoi précédent encore en vol plutôt que d'attendre sa fin
  // ou d'entrelacer leurs écritures BLE (ce qui casse le réassemblage côté
  // firmware, voir ERR_SEQ_MISMATCH). Voir _runExclusive.
  int _generation = 0;
  Future<void> _lastOperation = Future<void>.value();

  final _stateController = StreamController<BleConnectionState>.broadcast();
  final _batteryController = StreamController<int?>.broadcast();

  Stream<BleConnectionState> get connectionState => _stateController.stream;
  Stream<int?> get batteryLevel => _batteryController.stream;

  BluetoothDevice? get currentDevice => _device;

  bool get isConnected => _device?.isConnected ?? false;

  Stream<List<ScanResult>> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    _stateController.add(BleConnectionState.connecting);
    _device = device;

    _connSub?.cancel();
    _connSub = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        await _onConnected(device);
      } else if (state == BluetoothConnectionState.disconnected) {
        _stateController.add(BleConnectionState.disconnected);
        _batteryController.add(null);
      }
    });

    try {
      await device.connect(autoConnect: false, mtu: null);
    } catch (e) {
      _stateController.add(BleConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _onConnected(BluetoothDevice device) async {
    try {
      await device.requestMtu(EyzoProtocol.requestedMtu);
    } catch (_) {
      // MTU négocié par défaut si la demande échoue, pas bloquant.
    }
    _updateChunkPayloadSize(device);

    try {
      // Réduit l'intervalle de connexion BLE (Android — l'OS le gère seul
      // sur iOS/web, voir requestConnectionPriority) : chaque chunk d'un
      // envoi attend son accusé ATT avant le suivant (voir _writeChunks),
      // donc le coût par chunk domine le temps d'envoi des images/GIF (des
      // centaines de chunks cumulés sur toutes les frames d'une animation).
      await device.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );
    } catch (_) {
      // Non supporté hors Android, pas bloquant.
    }

    final services = await device.discoverServices();

    for (final service in services) {
      if (service.uuid == Guid(EyzoProtocol.serviceUuid)) {
        for (final c in service.characteristics) {
          if (c.uuid == Guid(EyzoProtocol.commandCharUuid)) {
            _commandChar = c;
          } else if (c.uuid == Guid(EyzoProtocol.eventCharUuid)) {
            await c.setNotifyValue(true);
            _eventSub?.cancel();
            _eventSub = c.lastValueStream.listen(_onEvent);
          }
        }
      } else if (service.uuid == Guid(EyzoProtocol.batteryServiceUuid)) {
        for (final c in service.characteristics) {
          if (c.uuid == Guid(EyzoProtocol.batteryLevelCharUuid)) {
            await c.setNotifyValue(true);
            _batterySub?.cancel();
            _batterySub = c.lastValueStream.listen((v) {
              if (v.isNotEmpty) _batteryController.add(v[0]);
            });
            try {
              final v = await c.read();
              if (v.isNotEmpty) _batteryController.add(v[0]);
            } catch (_) {
              // Batterie non lisible : firmware/hardware ne l'expose pas (voir specs.md §6.4).
            }
          }
        }
      }
    }

    _stateController.add(BleConnectionState.connected);
  }

  // Ajuste EyzoProtocol.maxChunkPayload au MTU réellement négocié (peut
  // différer de EyzoProtocol.requestedMtu si le téléphone/l'OS le plafonne
  // plus bas) : moins de chunks pour une même quantité de données envoyée,
  // donc moins d'allers-retours BLE (voir _writeChunks).
  void _updateChunkPayloadSize(BluetoothDevice device) {
    const attOverhead = 3; // opcode + handle (ATT Write Request)
    final usable =
        device.mtuNow -
        attOverhead -
        EyzoProtocol.chunkHeaderLen -
        EyzoProtocol.chunkChecksumLen;
    if (usable > 20) {
      EyzoProtocol.maxChunkPayload = usable;
    }
  }

  // Trame Événement (ESP32 -> téléphone), voir protocol.h côté firmware :
  // | SOF(1)=0xAA | EVT(1) | LEN(1) | PAYLOAD(LEN) | CHK(1, XOR sur SOF..PAYLOAD) |
  void _onEvent(List<int> value) {
    if (value.length < 4) return;
    if (value[0] != EyzoProtocol.eventSof) return;
    final evt = value[1];
    final len = value[2];
    if (value.length != 3 + len + 1) return;

    var chk = 0;
    for (var i = 0; i < 3 + len; i++) {
      chk ^= value[i];
    }
    if (chk != value[3 + len]) return;

    final payload = value.sublist(3, 3 + len);

    switch (evt) {
      case EyzoProtocol.evtAck:
      case EyzoProtocol.evtNack:
        if (payload.length < 2) return;
        final cmd = payload[0];
        final screen = payload[1];
        if (cmd != _pendingCmd || screen != _pendingScreen) {
          return; // événement résiduel d'une commande déjà abandonnée
        }
        final errorCode = evt == EyzoProtocol.evtNack && payload.length > 2
            ? payload[2]
            : null;
        _pendingAck?.complete(
          _AckOutcome(ack: evt == EyzoProtocol.evtAck, errorCode: errorCode),
        );
        break;
      default:
        // Statut/appairage : non exploités côté app pour l'instant (voir
        // firmware/README.md §5).
        break;
    }
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _stateController.add(BleConnectionState.disconnected);
  }

  /// Exécute [op] en exclusivité sur la caractéristique Commande : attend
  /// qu'un éventuel envoi précédent se soit retiré (avec succès, en échec,
  /// ou parce qu'il a lui-même constaté avoir été dépassé), jamais deux
  /// commandes en vol en même temps. Un envoi qui démarre pendant qu'un
  /// autre est encore en cours le fait abandonner proprement (voir
  /// _writeChunks) plutôt que d'attendre sa fin : ça permet à un nouvel
  /// envoi de remplacer immédiatement le précédent (utile en particulier
  /// pour une image/animation volumineuse encore en train de s'envoyer).
  /// Changer d'écran côté app n'affecte jamais cette chaîne : un envoi
  /// continue jusqu'à sa fin (ou jusqu'à être remplacé) même si le widget
  /// qui l'a déclenché a été démonté entretemps.
  Future<void> _runExclusive(Future<void> Function(int generation) op) {
    final myGeneration = ++_generation;
    final previous = _lastOperation;
    final future = () async {
      await previous.catchError((_) {});
      if (myGeneration != _generation) {
        throw const _SupersededException();
      }
      await op(myGeneration);
    }();
    _lastOperation = future.catchError((_) {});
    return future;
  }

  Future<void> _writeChunks(List<Uint8List> chunks, int generation) async {
    final char = _commandChar;
    if (char == null) {
      throw StateError('Non connecté aux lunettes.');
    }
    // cmd/screen sont aux mêmes offsets dans chaque chunk (voir l'en-tête
    // commun §6.2) : identiques pour tous les chunks d'une même commande.
    final cmd = chunks.first[1];
    final screen = chunks.first[2];

    final completer = Completer<_AckOutcome>();
    _pendingAck = completer;
    _pendingCmd = cmd;
    _pendingScreen = screen;
    try {
      // Écriture AVEC réponse : chaque write attend l'accusé ATT du firmware
      // avant d'envoyer le chunk suivant. Sans ça, une rafale de writeWithout
      // Response (ex: ~230 chunks pour une image 160x128) sature la file de
      // réception NimBLE et des chunks sont perdus silencieusement, cassant
      // le réassemblage côté firmware (voir ble_manager.cpp: ERR_SEQ_MISMATCH).
      //
      // Ceci ne garantit que la réception BLE bas niveau de chaque chunk, pas
      // que le firmware ait effectivement réassemblé/affiché la commande
      // complète : on attend ensuite l'ACK/NACK applicatif ci-dessous, sans
      // quoi un rejet silencieux côté firmware (checksum, buffer plein,
      // échec d'allocation...) passerait inaperçu côté app (voir specs.md).
      //
      // Vérifié avant chaque chunk : si un envoi plus récent a démarré
      // entretemps (voir _runExclusive), on abandonne ici plutôt que de
      // continuer à écrire sur la caractéristique en parallèle du nouvel
      // envoi (ce qui entrelacerait les deux trames côté firmware).
      for (final chunk in chunks) {
        if (generation != _generation) {
          throw const _SupersededException();
        }
        await char.write(chunk, withoutResponse: false);
      }
      if (generation != _generation) {
        throw const _SupersededException();
      }

      final outcome = await completer.future.timeout(
        EyzoProtocol.ackTimeout,
        onTimeout: () => throw TimeoutException(
          'Pas de réponse des lunettes après l\'envoi.',
        ),
      );
      if (!outcome.ack) {
        throw StateError(
          'Lunettes : commande refusée'
          '${outcome.errorCode != null ? ' (erreur ${outcome.errorCode})' : ''}.',
        );
      }
    } finally {
      if (identical(_pendingAck, completer)) {
        _pendingAck = null;
        _pendingCmd = null;
        _pendingScreen = null;
      }
    }
  }

  Future<void> sendText(TargetScreen screen, TextContent content) {
    return _runExclusive((generation) async {
      final chunks = await EyzoPacketBuilder.setText(screen, content);
      await _writeChunks(chunks, generation);
    });
  }

  Future<void> sendStaticImage(TargetScreen screen, PixelFrame frame) {
    return _runExclusive((generation) {
      return _writeChunks(
        EyzoPacketBuilder.setStaticImage(screen, frame),
        generation,
      );
    });
  }

  Future<void> sendAnimation(TargetScreen screen, PixelAnimation animation) {
    return _runExclusive((generation) async {
      final framePackets = EyzoPacketBuilder.setAnimation(screen, animation);
      for (final chunks in framePackets) {
        await _writeChunks(chunks, generation);
      }
    });
  }

  Future<void> clearScreen(TargetScreen screen) {
    return _runExclusive(
      (generation) =>
          _writeChunks([EyzoPacketBuilder.clearScreen(screen)], generation),
    );
  }

  Future<void> ping() {
    return _runExclusive(
      (generation) => _writeChunks([EyzoPacketBuilder.ping()], generation),
    );
  }

  void dispose() {
    _connSub?.cancel();
    _eventSub?.cancel();
    _batterySub?.cancel();
    _stateController.close();
    _batteryController.close();
  }
}

/// Résultat de l'ACK/NACK applicatif attendu par [EyzoBleService._writeChunks].
class _AckOutcome {
  const _AckOutcome({required this.ack, this.errorCode});

  final bool ack;

  /// Renseigné uniquement pour un NACK (voir `EyzoProtocol.err*`).
  final int? errorCode;
}

/// Levée quand un envoi est abandonné parce qu'un envoi plus récent l'a
/// remplacé (voir [EyzoBleService._runExclusive]) — distincte d'un échec
/// réel (refus firmware, timeout, déconnexion) pour un message clair côté UI.
class _SupersededException implements Exception {
  const _SupersededException();

  @override
  String toString() => 'Envoi interrompu par un envoi plus récent.';
}
