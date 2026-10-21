import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/component3_recommendation_engine.dart';
import '../data/component3_input_readiness.dart';
import 'live_monitoring_controller.dart';
import 'component3_manual_alert_test_button.dart';

class Component3RiskDashboard extends ConsumerWidget {
  const Component3RiskDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMonitoringControllerProvider);
    final collector = ref.read(liveMonitoringControllerProvider.notifier);
    final history = collector.component3RawHistory;
    final latest = history.isEmpty ? null : history.last;

    final active = live.state == MonitoringState.monitoring && !live.isDemoMode;

    final now = DateTime.now();
    final timestamp = latest?['timestamp_ms'];

    final packetFresh =
        active &&
        timestamp is int &&
        !now
            .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
            .isNegative &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp)) <=
            const Duration(seconds: 10);

    final hr = latest?['heart_rate_bpm'];
    final hrAvailable = hr is num && hr.isFinite;
    final hrFresh = packetFresh && hrAvailable;

    final gps = collector.component3LatestGps;
    final gpsAge = gps == null ? null : now.difference(gps.timestamp);
    final gpsFresh =
        active &&
        gpsAge != null &&
        !gpsAge.isNegative &&
        gpsAge <= const Duration(seconds: 15);

    // Diagnostics only. Live TFLite scores are withheld until verified.
    final readiness = Component3InputReadiness.assess(
      monitoringActive: active,
      demoMode: live.isDemoMode,
      watchHistory: history,
      gpsFresh: gpsFresh,
      weatherVerified: collector.component3WeatherVerified,
      featureDefinitionsVerified: false,
      outputMappingValidated: false,
      now: now,
    );

    final recommendations = const Component3RecommendationEngine().evaluate(
      monitoringActive: active,
      demoMode: live.isDemoMode,
      heartRateAvailable: hrAvailable && packetFresh,
      heartRateFresh: hrFresh,
      gpsAvailable: gpsFresh,
      weatherVerified: collector.component3WeatherVerified,
      modelInputsVerified: false,
    );

    // STEP359_WEATHER_PANEL: fresh provider weather only.
    final weather = collector.component3LatestWeather;
    final weatherAvailable =
        active && collector.component3WeatherVerified && weather != null;

    final temperatureText = weatherAvailable
        ? '${weather.temperatureCelsius.toStringAsFixed(1)} °C'
        : '-- °C';

    final humidityText = weatherAvailable
        ? '${weather.humidityPercent.toStringAsFixed(0)} %'
        : '-- %';
    final windowCount = collector.component3SensorWindowCount;
    final alignedWindow = collector.component3LatestTenSamples;
    Widget riskCard(String title, IconData icon) => Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blueGrey),
        title: Text(title),
        subtitle: const Text('Estimate unavailable - inputs unverified'),
        trailing: const Icon(Icons.hourglass_empty),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Component 3 - AI Risk Indicators',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        riskCard('Fatigue', Icons.battery_alert_outlined),
        riskCard('Physical Strain', Icons.monitor_heart_outlined),
        riskCard('Heat Stress', Icons.thermostat_outlined),
        const SizedBox(height: 12),
        // STEP359_WEATHER_PANEL
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Live Weather Conditions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      weatherAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        color: weatherAvailable ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.thermostat_outlined, size: 28),
                          const SizedBox(height: 6),
                          const Text('Temperature'),
                          Text(
                            temperatureText,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          const Icon(Icons.water_drop_outlined, size: 28),
                          const SizedBox(height: 6),
                          const Text('Humidity'),
                          Text(
                            humidityText,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Source: Open-Meteo weather model using '
                  'approximate phone location. '
                  'Not an on-site sensor measurement.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Live Safety Recommendations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final item in recommendations)
          if (item.title != 'GPS Unavailable')
            Card(
              child: ListTile(
                leading: Icon(
                  item.level == Component3GuidanceLevel.caution
                      ? Icons.warning_amber_outlined
                      : Icons.info_outline,
                  color: item.level == Component3GuidanceLevel.caution
                      ? Colors.orange
                      : Colors.blueGrey,
                ),
                title: Text(item.title),
                subtitle: Text(item.message),
              ),
            ),
        // STEP382_DEV_DIAGNOSTICS
        ExpansionTile(
          title: const Text('Research & Testing Details'),
          leading: const Icon(Icons.science_outlined),
          initiallyExpanded: false,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.view_list_outlined),
                title: const Text('Sensor Window Status'),
                subtitle: Text(
                  'Aligned raw samples: $windowCount/10\n'
                  '10-sample window: ${alignedWindow == null ? "Not ready" : "Available"}\n'
                  'Model 12-feature processing: Not connected',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Research prototype: not a medical diagnosis. '
              'AI risk inference and risk notifications are disabled.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Live AI input readiness',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Fresh Watch6 HR packets: ${readiness.freshWatchPackets}/10',
                    ),
                    const Text(
                      'Inference disabled until required inputs are verified.',
                    ),
                    for (final reason in readiness.blockers)
                      Text('â€¢ $reason', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
            const Component3ManualAlertTestButton(),
          ],
        ),
      ],
    );
  }
}
