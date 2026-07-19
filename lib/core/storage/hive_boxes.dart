import 'package:hive_flutter/hive_flutter.dart';

/// Initialisation Hive — stockage 100% local, pas de compte/cloud (voir specs.md §4.6).
class HiveBoxes {
  HiveBoxes._();

  static const String settings = 'eyzo_settings';
  static const String favorites = 'eyzo_favorites';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>(settings);
    await Hive.openBox<dynamic>(favorites);
  }
}
