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

  void _onEvent(List<int> value) {
    // ACK/NACK/statut : parsing détaillé à affiner avec le firmware.
  }

  Future<void> disconnect() async {
    await _device?.disconnect();
    _stateController.add(BleConnectionState.disconnected);
  }

  Future<void> _writeChunks(List<Uint8List> chunks) async {
    final char = _commandChar;
    if (char == null) {
      throw StateError('Non connecté aux lunettes.');
    }
    for (final chunk in chunks) {
      await char.write(
        chunk,
        withoutResponse: char.properties.writeWithoutResponse,
      );
    }
  }

  Future<void> sendText(TargetScreen screen, TextContent content) =>
      _writeChunks(EyzoPacketBuilder.setText(screen, content));

  Future<void> sendStaticImage(TargetScreen screen, PixelFrame frame) =>
      _writeChunks(EyzoPacketBuilder.setStaticImage(screen, frame));

  Future<void> sendAnimation(
    TargetScreen screen,
    PixelAnimation animation,
  ) async {
    final framePackets = EyzoPacketBuilder.setAnimation(screen, animation);
    for (final chunks in framePackets) {
      await _writeChunks(chunks);
    }
  }

  Future<void> clearScreen(TargetScreen screen) =>
      _writeChunks([EyzoPacketBuilder.clearScreen(screen)]);

  Future<void> ping() => _writeChunks([EyzoPacketBuilder.ping()]);

  void dispose() {
    _connSub?.cancel();
    _eventSub?.cancel();
    _batterySub?.cancel();
    _stateController.close();
    _batteryController.close();
  }
}
