import 'package:hive_flutter/hive_flutter.dart';

import 'hive_boxes.dart';

/// Mémorise l'appareil BLE appairé pour la reconnexion automatique (voir specs.md §4.1).
class SettingsStore {
  Box<dynamic> get _box => Hive.box<dynamic>(HiveBoxes.settings);

  static const _lastDeviceIdKey = 'lastDeviceId';
  static const _lastDeviceNameKey = 'lastDeviceName';
  static const _interLensGapMmKey = 'interLensGapMm';

  /// Écrans non collés dans le prototype : valeur de départ raisonnable en
  /// attendant que l'utilisateur affine la mesure réelle via la modale
  /// d'aperçu (voir [DualLensRow]).
  static const double defaultInterLensGapMm = 5.0;

  String? get lastDeviceId => _box.get(_lastDeviceIdKey) as String?;
  String? get lastDeviceName => _box.get(_lastDeviceNameKey) as String?;

  Future<void> saveLastDevice({
    required String id,
    required String name,
  }) async {
    await _box.put(_lastDeviceIdKey, id);
    await _box.put(_lastDeviceNameKey, name);
  }

  Future<void> clearLastDevice() async {
    await _box.delete(_lastDeviceIdKey);
    await _box.delete(_lastDeviceNameKey);
  }

  double get interLensGapMm =>
      (_box.get(_interLensGapMmKey) as num?)?.toDouble() ??
      defaultInterLensGapMm;

  Future<void> setInterLensGapMm(double value) async {
    await _box.put(_interLensGapMmKey, value);
  }
}
