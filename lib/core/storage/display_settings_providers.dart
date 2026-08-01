import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_providers.dart';
import 'settings_store.dart';

/// Contrôleur réactif pour l'espace inter-écran (mm) — voir [DualLensRow] et
/// [SequentialTextPreview] pour son utilisation dans l'aperçu.
class InterLensGapController extends StateNotifier<double> {
  InterLensGapController(this._store) : super(_store.interLensGapMm);

  final SettingsStore _store;

  Future<void> setMm(double value) async {
    await _store.setInterLensGapMm(value);
    state = value;
  }
}

final interLensGapProvider =
    StateNotifierProvider<InterLensGapController, double>((ref) {
      return InterLensGapController(ref.watch(settingsStoreProvider));
    });
