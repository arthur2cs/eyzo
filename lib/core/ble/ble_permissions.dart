import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Demande les permissions nécessaires au scan/connexion BLE (voir specs.md §4.1).
/// Couvre à la fois le modèle Android 12+ (BLUETOOTH_SCAN/CONNECT) et le modèle
/// legacy Android 8-11 (ACCESS_FINE_LOCATION).
Future<bool> requestBlePermissions() async {
  if (!Platform.isAndroid) return true;

  final statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
  ].request();

  return statuses.values.every((status) => status.isGranted || status.isLimited);
}

Future<bool> hasBlePermissions() async {
  if (!Platform.isAndroid) return true;
  final scan = await Permission.bluetoothScan.status;
  final connect = await Permission.bluetoothConnect.status;
  final location = await Permission.locationWhenInUse.status;
  return scan.isGranted && connect.isGranted && (location.isGranted || location.isLimited);
}
