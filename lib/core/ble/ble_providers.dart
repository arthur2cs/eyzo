import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/settings_store.dart';
import 'ble_connection_state.dart';
import 'eyzo_ble_service.dart';

final bleServiceProvider = Provider<EyzoBleService>((ref) {
  final service = EyzoBleService();
  ref.onDispose(service.dispose);
  return service;
});

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

final connectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  return ref.watch(bleServiceProvider).connectionState;
});

final batteryLevelProvider = StreamProvider<int?>((ref) {
  return ref.watch(bleServiceProvider).batteryLevel;
});

/// Tente une reconnexion automatique au dernier appareil appairé (voir specs.md §4.1).
final autoReconnectProvider = FutureProvider<void>((ref) async {
  final settings = ref.watch(settingsStoreProvider);
  final lastId = settings.lastDeviceId;
  if (lastId == null) return;

  final service = ref.watch(bleServiceProvider);
  try {
    final device = BluetoothDevice(remoteId: DeviceIdentifier(lastId));
    await service.connect(device);
  } catch (_) {
    // Lunettes hors de portée / éteintes : rien à faire, l'utilisateur pourra rescanner.
  }
});
