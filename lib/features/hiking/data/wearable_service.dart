import 'dart:async';
import 'package:flutter/services.dart';
import 'sensor_data_model.dart';

enum WearableConnectionStatus { disconnected, connecting, connected, error }

class WearableService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.app_venture_flutter/wearable');
  static const EventChannel _eventChannel = EventChannel('com.example.app_venture_flutter/wearable_stream');

  WearableConnectionStatus _status = WearableConnectionStatus.disconnected;
  DateTime? _lastSyncTime;
  final List<String> _supportedSensors = ['Heart Rate', 'Step Count', 'Distance', 'Calories', 'Elevation'];
  StreamSubscription? _eventSubscription;
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  WearableConnectionStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<String> get supportedSensors => _supportedSensors;

  final StreamController<SensorDataModel> _sensorController = StreamController<SensorDataModel>.broadcast();
  Stream<SensorDataModel> get sensorStream => _sensorController.stream;

  Future<bool> connectDevice(String deviceIdentifier) async {
    _status = WearableConnectionStatus.connecting;
    try {
      final connected = await _methodChannel.invokeMethod<bool>('connect');
      if (connected != true) {
        _status = WearableConnectionStatus.disconnected;
        return false;
      }
      _status = WearableConnectionStatus.connected; // Node discovered, telemetry not yet confirmed.
      _startListeningToWatchStream();
      return true;
    } catch (e) {
      _status = WearableConnectionStatus.error;
      _errorController.add('Watch discovery failed: $e');
      return false;
    }
  }

  void _startListeningToWatchStream() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((dynamic event) {
      if (event is! Map) return;
      try {
        final data = Map<String, dynamic>.from(event);
        final rawTs = data['timestamp'];
        final ms = rawTs is num ? rawTs.toInt() : int.tryParse(rawTs?.toString() ?? '');
        if (ms == null || ms < 946684800000) return;
        final stamp = DateTime.fromMillisecondsSinceEpoch(ms);
        final age = DateTime.now().difference(stamp);
        if (age.isNegative && age.inSeconds < -5) return;
        if (age > const Duration(seconds: 15)) return;

        double? finite(dynamic raw) {
          if (raw is num && raw.toDouble().isFinite) return raw.toDouble();
          return null;
        }
        final hr = finite(data['heartRate']);
        final stepsRaw = data['stepCount'];
        final steps = stepsRaw is num && stepsRaw >= 0 ? stepsRaw.toInt() : null;
        final sensorData = SensorDataModel(
          timestamp: stamp,
          heartRate: hr != null && hr >= 30 && hr <= 240 ? hr : null,
          hrv: null,
          spo2: null,
          stepCount: steps,
          speedMs: null,
          distanceKm: finite(data['distanceKm']),
          elevationM: finite(data['elevationM']),
          dataSource: 'Watch6 telemetry (received)',
          dataFreshness: age.isNegative ? Duration.zero : age,
          measurementQuality: 'unverified',
        );
        _lastSyncTime = DateTime.now();
        _sensorController.add(sensorData);
      } catch (e) {
        _errorController.add('Telemetry parse error: $e');
      }
    }, onError: (Object e) {
      _status = WearableConnectionStatus.error;
      _errorController.add('Telemetry stream error: $e');
    });
  }

  Future<void> startExerciseSession() async {
    try {
      await _methodChannel.invokeMethod('startExercise');
    } catch (_) {}
  }

  Future<void> pauseExerciseSession() async {
    try {
      await _methodChannel.invokeMethod('pauseExercise');
    } catch (_) {}
  }

  Future<void> resumeExerciseSession() async {
    try {
      await _methodChannel.invokeMethod('resumeExercise');
    } catch (_) {}
  }

  Future<void> stopExerciseSession() async {
    try {
      await _methodChannel.invokeMethod('stopExercise');
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _status = WearableConnectionStatus.disconnected;
    _eventSubscription?.cancel();
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
  }

  void dispose() {
    _eventSubscription?.cancel();
    _sensorController.close();
    _errorController.close();
  }
}
