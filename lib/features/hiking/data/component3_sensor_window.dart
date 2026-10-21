import 'component3_gps_service.dart';
import 'weather_repository.dart';

/// Timestamp-aligned sensor data; NOT the model's 12 calculated features.
class Component3SensorSample {
  final DateTime timestamp;
  final double heartRateBpm;
  final int? stepCount;
  final double speedMps;
  final double altitudeM;
  final double temperatureCelsius;
  final double humidityPercent;

  const Component3SensorSample({
    required this.timestamp,
    required this.heartRateBpm,
    required this.stepCount,
    required this.speedMps,
    required this.altitudeM,
    required this.temperatureCelsius,
    required this.humidityPercent,
  });
}

class Component3SensorWindow {
  final List<Component3SensorSample> _samples = [];
  Component3GpsReading? _gps;
  Component3VerifiedWeather? _weather;
  DateTime? _lastWatchTimestamp;

  int get count => _samples.length;

  void reset() {
    _samples.clear();
    _gps = null;
    _weather = null;
    _lastWatchTimestamp = null;
  }

  void acceptGps(Component3GpsReading reading) {
    _gps = reading;
  }

  void acceptWeather(Component3VerifiedWeather weather) {
    _weather = weather;
  }

  bool acceptWatchPacket(Map<String, dynamic> packet) {
    final rawTime = packet['timestamp_ms'];
    final rawHr = packet['heart_rate_bpm'];
    final source = packet['source_claim'];

    if (rawTime is! int ||
        rawHr is! num ||
        !rawHr.isFinite ||
        rawHr < 30 ||
        rawHr > 240 ||
        source is! String ||
        !source.startsWith('Watch6 telemetry')) {
      return false;
    }

    final time = DateTime.fromMillisecondsSinceEpoch(rawTime);

    if (_lastWatchTimestamp != null && !time.isAfter(_lastWatchTimestamp!)) {
      return false;
    }

    final gps = _gps;
    final weather = _weather;
    if (gps == null || weather == null) return false;

    final gpsAge = time.difference(gps.timestamp);
    final weatherAge = time.difference(weather.receivedAt);

    if (gpsAge.isNegative ||
        gpsAge > const Duration(seconds: 15) ||
        weatherAge.isNegative ||
        weatherAge > const Duration(minutes: 15)) {
      return false;
    }

    final rawSteps = packet['step_count'];

    _samples.add(
      Component3SensorSample(
        timestamp: time,
        heartRateBpm: rawHr.toDouble(),
        stepCount: rawSteps is int && rawSteps >= 0 ? rawSteps : null,
        speedMps: gps.speedMps,
        altitudeM: gps.altitudeM,
        temperatureCelsius: weather.temperatureCelsius,
        humidityPercent: weather.humidityPercent,
      ),
    );

    _lastWatchTimestamp = time;

    if (_samples.length > 120) {
      _samples.removeAt(0);
    }

    return true;
  }

  /// Returns aligned raw samples only; not authorized for inference.
  List<Component3SensorSample>? get latestTen {
    if (_samples.length < 10) return null;
    return List.unmodifiable(_samples.sublist(_samples.length - 10));
  }
}
