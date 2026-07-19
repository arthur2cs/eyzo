import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// ACCESS_FINE_LOCATION est déclarée avec `maxSdkVersion="30"` dans le manifest
/// (voir AndroidManifest.xml) : sur Android 12+ (API 31+), le système l'exclut
/// purement et simplement de l'app, donc la permission ne peut jamais être
/// accordée — la demander/l'exiger sur ces versions bloque le scan en
/// permanence même si l'utilisateur a tout accepté. Elle n'est requise que
/// sur Android 8-11 (API < 31).
Future<bool> _needsLocationPermission() async {
  if (!Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  return info.version.sdkInt < 31;
}

/// Demande les permissions nécessaires au scan/connexion BLE (voir specs.md §4.1).
/// Couvre à la fois le modèle Android 12+ (BLUETOOTH_SCAN/CONNECT) et le modèle
/// legacy Android 8-11 (ACCESS_FINE_LOCATION).
Future<bool> requestBlePermissions() async {
  if (!Platform.isAndroid) return true;

  final needsLocation = await _needsLocationPermission();
  final statuses = await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    if (needsLocation) Permission.locationWhenInUse,
  ].request();

  return statuses.values.every(
    (status) => status.isGranted || status.isLimited,
  );
}

Future<bool> hasBlePermissions() async {
  if (!Platform.isAndroid) return true;
  final scan = await Permission.bluetoothScan.status;
  final connect = await Permission.bluetoothConnect.status;
  if (!scan.isGranted || !connect.isGranted) return false;
  if (!await _needsLocationPermission()) return true;
  final location = await Permission.locationWhenInUse.status;
  return location.isGranted || location.isLimited;
}
