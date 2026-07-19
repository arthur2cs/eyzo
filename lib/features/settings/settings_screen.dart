import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/theme/app_theme.dart';
import '../connection/connection_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionStateProvider).value ?? BleConnectionState.disconnected;
    final lastDeviceName = ref.watch(settingsStoreProvider).lastDeviceName;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Appareil', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(lastDeviceName ?? 'Aucun appareil appairé'),
            subtitle: Text(
              connectionState == BleConnectionState.connected ? 'Connecté' : 'Déconnecté',
            ),
            trailing: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConnectionScreen()),
              ),
              child: const Text('Gérer'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('À propos', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Card(
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '—';
              final buildNumber = snapshot.data?.buildNumber ?? '';
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Eyzo'),
                subtitle: Text('Version $version${buildNumber.isNotEmpty ? '+$buildNumber' : ''}'),
              );
            },
          ),
        ),
      ],
    );
  }
}
