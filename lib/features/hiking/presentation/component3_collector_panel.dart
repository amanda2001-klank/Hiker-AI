import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_monitoring_controller.dart';

/// Research-only diagnostic display. Never triggers model inference.
class Component3CollectorPanel extends ConsumerWidget {
  const Component3CollectorPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMonitoringControllerProvider);
    final collector = ref.read(liveMonitoringControllerProvider.notifier);
    final history = collector.component3RawHistory;
    final gps = collector.component3LatestGps;
    final gpsAge = gps == null
        ? null
        : DateTime.now().difference(gps.timestamp);

    final gpsFresh = live.state == MonitoringState.monitoring &&
        !live.isDemoMode &&
        gpsAge != null &&
        !gpsAge.isNegative &&
        gpsAge <= const Duration(seconds: 15);

    final latest = history.isEmpty ? null : history.last;

    String value(Object? item, String unit) =>
        item == null ? 'Unavailable' : '$item $unit';

    final active = live.state == MonitoringState.monitoring &&
        !live.isDemoMode;
    final sourceFresh = active && latest != null &&
        DateTime.now().difference(
              DateTime.fromMillisecondsSinceEpoch(
                latest['timestamp_ms'] as int,
              ),
            ) <= const Duration(seconds: 10);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Component 3 — Raw Data Diagnostics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Accepted Watch6 packets: ${collector.component3PacketCount}'),
            Text('Live source status: ${sourceFresh ? "Recent packet" : "Unavailable / not monitoring"}'),
            Text('Latest HR: ${sourceFresh ? value(latest['heart_rate_bpm'], "bpm") : "Unavailable"}'),
            Text('Latest steps: ${sourceFresh ? value(latest['step_count'], "steps") : "Unavailable"}'),
            Text('Last timestamp: ${sourceFresh ? latest['received_at'] : "Unavailable"}'),
            Text('GPS service status: ${collector.component3GpsStatus}'),
            Text('Phone GPS: ${gpsFresh ? "Recent GPS reading" : "Unavailable / stale"}'),
            Text('GPS speed: ${gpsFresh ? value(gps!.speedMps, "m/s") : "Unavailable"}'),
            Text('GPS altitude: ${gpsFresh ? value(gps!.altitudeM, "m") : "Unavailable"}'),
            Text('GPS horizontal accuracy: ${gpsFresh ? value(gps!.accuracyM, "m") : "Unavailable"}'),
            Text('GPS timestamp: ${gpsFresh ? gps!.timestamp.toIso8601String() : "Unavailable"}'),
            const Text('Weather: Not verified'),
            const Text('Individual sensor freshness: Not verified'),
            const Text('AI risk inference: DISABLED'),
            const Text('Risk notifications: DISABLED'),
          ],
        ),
      ),
    );
  }
}