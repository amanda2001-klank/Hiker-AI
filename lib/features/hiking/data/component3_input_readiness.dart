/// Readiness gate for the EXISTING 10 x 12 risk_model.tflite input.
/// Never manufactures unavailable features or interprets model scores.
class Component3InputReadiness {
  final bool ready;
  final List<String> blockers;
  final int freshWatchPackets;

  const Component3InputReadiness({
    required this.ready,
    required this.blockers,
    required this.freshWatchPackets,
  });

  static const featureNames = <String>[
    'hr_pct', 'hr_trend', 'cadence', 'gps_speed_mps',
    'pace_change', 'slope_pct', 'elev_gain_m', 'air_temp_c',
    'humidity_pct', 'heat_index_c', 'min_since_start', 'min_since_rest',
  ];

  static Component3InputReadiness assess({
    required bool monitoringActive,
    required bool demoMode,
    required List<Map<String, dynamic>> watchHistory,
    required bool gpsFresh,
    required bool weatherVerified,
    required bool featureDefinitionsVerified,
    required bool outputMappingValidated,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final blockers = <String>[];
    if (!monitoringActive) blockers.add('Monitoring is not active');
    if (demoMode) blockers.add('Demo data cannot be used for live inference');
    final fresh = watchHistory.where((packet) {
      final timestamp = packet['timestamp_ms'];
      final heartRate = packet['heart_rate_bpm'];
      if (timestamp is! int || heartRate is! num || !heartRate.isFinite ||
          heartRate < 30 || heartRate > 240) {
        return false;
      }
      final age = clock.difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
      return !age.isNegative && age <= const Duration(seconds: 30) &&
          packet['source_claim'] is String &&
          (packet['source_claim'] as String).startsWith('Watch6 telemetry');
    }).length;
    if (fresh < 10) blockers.add('Need 10 fresh, valid Watch6 HR packets ($fresh/10)');
    if (!gpsFresh) blockers.add('Fresh phone GPS input unavailable');
    if (!weatherVerified) blockers.add('Weather temperature and humidity not verified');
    if (!featureDefinitionsVerified) {
      blockers.add('Training-time definitions of 12 features not verified');
    }
    if (!outputMappingValidated) {
      blockers.add('Risk output mapping and interpretation not validated');
    }
    return Component3InputReadiness(
      ready: blockers.isEmpty,
      blockers: List.unmodifiable(blockers),
      freshWatchPackets: fresh,
    );
  }
}
