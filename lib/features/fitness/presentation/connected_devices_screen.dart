import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/fitness_profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/database/database_helper.dart';
import '../../hiking/presentation/live_monitoring_controller.dart';
import '../../hiking/data/wearable_service.dart';

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends ConsumerState<ConnectedDevicesScreen> {
  bool _isLoading = true;
  bool _isConnecting = false;
  List<Map<String, dynamic>> _devices = [];
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email ?? 'user@venture.com';
      final username = authState.user?.username ?? 'User';
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

      final db = await ref.read(databaseHelperProvider).database;
      final rows = await db.query('connected_devices', where: 'user_id = ?', whereArgs: [userId]);

      if (rows.isEmpty) {
        await db.insert('connected_devices', {
          'user_id': userId,
          'device_name': 'Samsung Galaxy Watch6',
          'device_address': 'GHS_WEAROS_01',
          'device_type': 'WearOS Smartwatch',
          'is_connected': 0,
          'last_sync_time': null,
        });
        final updatedRows = await db.query('connected_devices', where: 'user_id = ?', whereArgs: [userId]);
        if (mounted) {
          setState(() {
            _devices = updatedRows;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _devices = rows;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error loading connected devices: $e';
        });
      }
    }
  }

  Future<void> _connectWatch(Map<String, dynamic> device) async {
    setState(() {
      _isConnecting = true;
      _statusMessage = null;
    });

    try {
      final wearable = ref.read(wearableServiceProvider);
      final success = await wearable.connectDevice(device['device_address'] as String);

      if (success) {
        final db = await ref.read(databaseHelperProvider).database;
        final nowStr = DateTime.now().toIso8601String();
        await db.update(
          'connected_devices',
          {
            'is_connected': 1,
            'last_sync_time': nowStr,
          },
          where: 'id = ?',
          whereArgs: [device['id']],
        );

        await _loadDevices();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to Samsung Galaxy Watch6 (Wear OS)!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection failed. Please ensure watch companion is installed and Bluetooth is enabled.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final wearable = ref.watch(wearableServiceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F5),
      appBar: AppBar(title: const Text('Connect Smartwatch (Watch6)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF086477)))
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Paired Wearable Devices',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ensure your Samsung Galaxy Watch6 is running the companion app and paired via Wear OS Data Layer.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_statusMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          ..._devices.map((dev) {
            final isConnected = dev['is_connected'] == 1 || wearable.status == WearableConnectionStatus.connected;
            final lastSync = dev['last_sync_time']?.toString() ?? wearable.lastSyncTime?.toIso8601String() ?? 'Never synchronized';

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD8E5E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F8F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.watch, color: Color(0xFF25C9A0), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dev['device_name'] as String? ?? 'Smartwatch',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dev['device_type'] as String? ?? 'WearOS',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isConnected ? const Color(0xFFE6F8F2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          isConnected ? 'CONNECTED' : 'DISCONNECTED',
                          style: TextStyle(
                            color: isConnected ? const Color(0xFF25C9A0) : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFE0EAE6)),
                  const SizedBox(height: 12),
                  Text('Identifier: ${dev['device_address']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('Last Synchronization: $lastSync', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('Required Permissions: Body Sensors, Activity Recognition, Fine Location', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                  const SizedBox(height: 4),
                  const Text('Supported Sensors: Heart Rate, Steps, Distance, Speed, Elevation, Calories', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isConnected ? const Color(0xFF25C9A0) : const Color(0xFF086477),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isConnecting ? null : () => _connectWatch(dev),
                    child: _isConnecting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(isConnected ? 'Reconnect / Sync Watch' : 'Connect Smartwatch', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
