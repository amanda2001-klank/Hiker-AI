import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'live_monitoring_controller.dart';

/// Diagnostics ONLY. Does not authorize TFLite inference or alerts.
/// Posts Watch6 event-derived readings, never demo readings.
class TelemetryDiagnosticsPanel extends ConsumerStatefulWidget {
  const TelemetryDiagnosticsPanel({super.key});

  @override
  ConsumerState<TelemetryDiagnosticsPanel> createState() =>
      _TelemetryDiagnosticsPanelState();
}

class _TelemetryDiagnosticsPanelState
    extends ConsumerState<TelemetryDiagnosticsPanel> {
  ProviderSubscription<LiveMonitoringState>? _subscription;
  Timer? _staleTimer;
  Map<String, dynamic>? _latest;
  DateTime? _lastReceived;
  bool _busy = false;
  bool _initialized = false;
  String _status = 'Waiting for real Watch6 telemetry';

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<LiveMonitoringState>(
      liveMonitoringControllerProvider,
      (previous, next) {
        if (next.isDemoMode || next.state != MonitoringState.monitoring) {
          if (mounted) {
            setState(() {
              _latest = null;
              _lastReceived = null;
              _status = next.isDemoMode
                  ? 'Demo excluded from research diagnostics'
                  : 'Watch6 telemetry unavailable / inactive';
            });
          }
          return;
        }
        // Ignore non-event state updates that reuse the same sensor object.
        if (identical(previous?.currentData, next.currentData)) return;
        final reading = next.currentData;
        if (!reading.dataSource.startsWith('Watch6 telemetry')) return;
        final now = DateTime.now();
        final deltaMs = now.difference(reading.timestamp).inMilliseconds;
        if (deltaMs < -5000 || deltaMs > 10000) return;
        _lastReceived = now;
        unawaited(_sendReading(reading.timestamp.millisecondsSinceEpoch,
            reading.heartRate, reading.stepCount, reading.distanceKm,
            reading.elevationM));
      },
    );
    _staleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final last = _lastReceived;
      if (!mounted || last == null) return;
      if (DateTime.now().difference(last) > const Duration(seconds: 15)) {
        setState(() {
          _latest = null;
          _lastReceived = null;
          _status = 'No fresh packet; diagnostics unavailable';
        });
      }
    });
  }

  Future<void> _sendReading(int timestampMs, double? heartRate,
      int? steps, double? distanceKm, double? elevationM) async {
    if (_busy) return; // bounded traffic; never queue stale packets
    _busy = true;
    try {
      final dio = ref.read(apiClientProvider).dio;
      // Reset this user's test history once per panel lifecycle.
      if (!_initialized) {
        await dio.post('/telemetry-diagnostics/reset');
        _initialized = true;
      }
      final response = await dio.post(
        '/telemetry-diagnostics/packet',
        data: {
          'packet': {
            'timestamp': timestampMs.toString(),
            'heartRate': heartRate,
            'stepCount': steps,
            'distanceKm': distanceKm,
            'calories': null, // testing copy does not expose calories
            'elevationM': elevationM,
          }
        },
      );
      if (!mounted) return;
      final raw = response.data;
      if (raw is! Map) throw const FormatException('Unexpected API response');
      final body = Map<String, dynamic>.from(raw);
      setState(() {
        _latest = body;
        _status = 'Research diagnostics only - device origin unverified';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _latest = null;
        _status = error.response?.statusCode == 401 ||
                error.response?.statusCode == 403
            ? 'Backend login required (offline login has no JWT)'
            : 'Diagnostics API unavailable (${error.response?.statusCode ?? 'network'})';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _latest = null;
          _status = 'Diagnostics response unavailable';
        });
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _subscription?.close();
    _staleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = _latest;
    final telemetry = diagnostic?['telemetry'];
    final sensor = telemetry is Map
        ? telemetry
        : const <String, dynamic>{};
    String rawValue(String key) {
      final value = sensor[key];
      return value == null ? 'Unavailable' : value.toString();
    }
    final history = diagnostic?['history'];
    final availability = diagnostic?['feature_availability'];
    final fields = availability is Map ? availability['packet_fields_present'] : null;
    final present = fields is Map ? fields : const <String, dynamic>{};
    String field(String key) => present[key] == true ? 'Received (unverified)' : 'Unavailable';
    final featureCount = availability is Map
        ? availability['missing_or_unverified_feature_count']
        : null;
    final count = history is Map ? history['packet_count'] : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Input Diagnostics (Research)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_status),
            const SizedBox(height: 8),
            Text('Packets in current backend history: ${count ?? 'Unavailable'}'),
            Text('Backend packet status: ${rawValue('status')}'),
            Text('Latest backend HR: ${rawValue('heart_rate_bpm')} BPM'),
            Text('Latest backend Steps: ${rawValue('step_count')}'),
            Text('Packet age: ${rawValue('packet_age_seconds')} seconds'),
            Text('HR: ${field('heart_rate_bpm')}'),
            Text('Steps: ${field('step_count')}'),
            Text('Distance: ${field('distance_km')}'),
            Text('Calories: ${field('calories_kcal')}'),
            Text('Elevation: ${field('elevation_m')}'),
            Text('Unverified / unavailable AI features: ${featureCount ?? '12'} of 12'),
            const SizedBox(height: 8),
            const Text(
              'A fresh packet does not prove per-sensor freshness. '
              'No TFLite risk inference, percentages or safety alerts are enabled.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
