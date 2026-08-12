import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ble/ble_connection_state.dart';
import '../../core/ble/ble_permissions.dart';
import '../../core/ble/ble_providers.dart';
import '../../core/ble/eyzo_protocol.dart';
import '../../core/theme/app_theme.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  String? _connectingId;
  String? _error;

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _error = null;
      _results.clear();
    });

    final granted = await requestBlePermissions();
    if (!granted) {
      setState(() => _error = 'Permissions Bluetooth/localisation refusées.');
      return;
    }

    setState(() => _scanning = true);
    _scanSub?.cancel();
    _scanSub = ref.read(bleServiceProvider).startScan().listen((results) {
      if (!mounted) return;
      setState(() {
        _results
          ..clear()
          ..addAll(results..sort(_compareResults));
      });
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) setState(() => _scanning = false);
    });
  }

  bool _isEyzoDevice(ScanResult result) =>
      result.device.platformName.startsWith(EyzoProtocol.deviceNamePrefix);

  /// Épingle les lunettes en tête de liste (identifiées par leur nom
  /// annoncé, voir `EyzoProtocol.deviceNamePrefix`) : sans ça, le tri par
  /// RSSI seul les fait remonter/descendre à chaque tick de scan au fil des
  /// autres appareils détectés, ce qui fait rater le tap au moment de
  /// s'appairer.
  int _compareResults(ScanResult a, ScanResult b) {
    final aIsEyzo = _isEyzoDevice(a);
    final bIsEyzo = _isEyzoDevice(b);
    if (aIsEyzo != bIsEyzo) return aIsEyzo ? -1 : 1;
    return b.rssi.compareTo(a.rssi);
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connectingId = device.remoteId.str;
      _error = null;
    });
    try {
      await ref.read(bleServiceProvider).connect(device);
      await ref
          .read(settingsStoreProvider)
          .saveLastDevice(
            id: device.remoteId.str,
            name: device.platformName.isNotEmpty
                ? device.platformName
                : device.remoteId.str,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Connexion impossible : $e');
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }

  Future<void> _forgetDevice() async {
    await ref.read(bleServiceProvider).disconnect();
    await ref.read(settingsStoreProvider).clearLastDevice();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState =
        ref.watch(connectionStateProvider).value ??
        BleConnectionState.disconnected;
    final currentDeviceName = ref.read(settingsStoreProvider).lastDeviceName;

    return Scaffold(
      appBar: AppBar(title: const Text('Connexion aux lunettes')),
      body: SafeArea(
        child: Column(
          children: [
            if (connectionState == BleConnectionState.connected)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connecté à ${currentDeviceName ?? 'lunettes Eyzo'}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton(
                          onPressed: _forgetDevice,
                          child: const Text('Oublier'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _startScan,
                  icon: _scanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.background,
                          ),
                        )
                      : const Icon(Icons.bluetooth_searching),
                  label: Text(
                    _scanning
                        ? 'Recherche en cours…'
                        : 'Rechercher les lunettes',
                  ),
                ),
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _scanning
                            ? 'Recherche des appareils BLE à proximité…'
                            : 'Aucun appareil détecté.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final result = _results[index];
                        final device = result.device;
                        final name = device.platformName.isNotEmpty
                            ? device.platformName
                            : 'Appareil inconnu';
                        final isConnecting =
                            _connectingId == device.remoteId.str;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(name),
                            subtitle: Text(
                              '${device.remoteId.str} • RSSI ${result.rssi}',
                            ),
                            trailing: isConnecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : OutlinedButton(
                                    onPressed: () => _connect(device),
                                    child: const Text('Appairer'),
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
