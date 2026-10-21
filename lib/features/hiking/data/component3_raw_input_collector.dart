import 'sensor_data_model.dart';

/// Research-only raw input collector.
/// Does not calculate the TFLite model's 12 features.
/// Device provenance and individual sensor freshness are not proven.
class Component3RawInputCollector {
  final List<Map<String, dynamic>> _history = [];
  DateTime? _lastTimestamp;

  List<Map<String, dynamic>> get history =>
      _history.map((e) => Map<String, dynamic>.from(e)).toList();

  int get packetCount => _history.length;

  void reset() {
    _history.clear();
    _lastTimestamp = null;
  }

  double? _finite(double? value) =>
      value != null && value.isFinite ? value : null;

  Map<String, dynamic>? acceptWatchReading(
    SensorDataModel reading, {
    required bool isDemoMode,
    DateTime? receivedAt,
  }) {
    final now = receivedAt ?? DateTime.now();
    final age = now.difference(reading.timestamp);

    if (isDemoMode ||
        !reading.dataSource.startsWith('Watch6 telemetry') ||
        reading.measurementQuality == 'simulated' ||
        age.isNegative ||
        age > const Duration(seconds: 10) ||
        (_lastTimestamp != null &&
            !reading.timestamp.isAfter(_lastTimestamp!))) {
      return null;
    }

    final hr = _finite(reading.heartRate);
    final steps = reading.stepCount;
    final distance = _finite(reading.distanceKm);
    final elevation = _finite(reading.elevationM);
    final speed = _finite(reading.speedMs);

    final packet = <String, dynamic>{
      'timestamp_ms': reading.timestamp.millisecondsSinceEpoch,
      'received_at': now.toUtc().toIso8601String(),
      'source_claim': reading.dataSource,
      'source_authenticated': false,
      'per_sensor_freshness_verified': false,
      'heart_rate_bpm':
          hr != null && hr >= 30 && hr <= 240 ? hr : null,
      'step_count': steps != null && steps >= 0 ? steps : null,
      'distance_km': distance != null && distance >= 0 ? distance : null,
      'elevation_m': elevation,
      'speed_mps': speed != null && speed >= 0 ? speed : null,
      'temperature_c': null,
      'humidity_pct': null,
      'rest_event': null,
      'model_features_verified': false,
      'inference_authorized': false,
    };

    _lastTimestamp = reading.timestamp;
    _history.add(packet);

    // Bounded diagnostic history only.
    if (_history.length > 120) {
      _history.removeAt(0);
    }

    return Map<String, dynamic>.from(packet);
  }
}