import 'dart:async';
import 'sensor_data_model.dart';

class PhoneSensorService {
  bool _isTracking = false;
  final StreamController<SensorDataModel> _locationController = StreamController<SensorDataModel>.broadcast();
  Stream<SensorDataModel> get locationStream => _locationController.stream;

  bool get isTracking => _isTracking;

  Future<bool> requestPermissions() async {
    // Simulated permission request for phone GPS and sensors
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
  }

  void stopTracking() {
    _isTracking = false;
  }

  void dispose() {
    _locationController.close();
  }
}
