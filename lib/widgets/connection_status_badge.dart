import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ble/ble_connection_state.dart';
import '../core/ble/ble_providers.dart';
import '../core/theme/app_theme.dart';

/// Indicateur de statut de connexion, visible en permanence (voir specs.md §4.1).
class ConnectionStatusBadge extends ConsumerWidget {
  const ConnectionStatusBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(connectionStateProvider);
    final battery = ref.watch(batteryLevelProvider).value;

    final state = stateAsync.value ?? BleConnectionState.disconnected;

    final (Color dotColor, String label) = switch (state) {
      BleConnectionState.connected => (AppColors.connected, 'Connecté'),
      BleConnectionState.connecting => (AppColors.textSecondary, 'Connexion…'),
      BleConnectionState.disconnected => (AppColors.disconnected, 'Déconnecté'),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            if (state == BleConnectionState.connected && battery != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.battery_std, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 2),
              Text('$battery%', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}
