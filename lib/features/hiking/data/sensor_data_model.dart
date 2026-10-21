class SensorDataModel {
  final DateTime timestamp;
  final double? heartRate;
  final double? hrv;
  final double? spo2;
  final int? stepCount;
  final double? speedMs;
  final double? distanceKm;
  final double? caloriesBurned;
  final double? elevationM;
  final String dataSource; // 'wearable', 'phone_gps', 'demo'
  final Duration dataFreshness;
  final String measurementQuality; // 'high', 'medium', 'low', 'unavailable'

  SensorDataModel({
    required this.timestamp,
    this.heartRate,
    this.hrv,
    this.spo2,
    required this.stepCount,
    required this.speedMs,
    required this.distanceKm,
    this.caloriesBurned,
    required this.elevationM,
    required this.dataSource,
    required this.dataFreshness,
    required this.measurementQuality,
  });

  factory SensorDataModel.initial() {
    return SensorDataModel(
      timestamp: DateTime.now(),
      heartRate: null,
      hrv: null,
      spo2: null,
      stepCount: null,
      speedMs: null,
      distanceKm: null,
      elevationM: null,
      dataSource: 'idle',
      dataFreshness: Duration.zero,
      measurementQuality: 'unavailable',
    );
  }
}
