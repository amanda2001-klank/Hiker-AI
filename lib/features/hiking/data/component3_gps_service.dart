import 'dart:async';
import 'package:geolocator/geolocator.dart';

class Component3GpsReading {
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double speedMps;
  final double altitudeM;
  final double accuracyM;

  const Component3GpsReading({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.speedMps,
    required this.altitudeM,
    required this.accuracyM,
  });
}

/// Research-only GPS source. No AI inference or notifications.
class Component3GpsService {
  StreamSubscription<Position>? _subscription;

  final _controller =
      StreamController<Component3GpsReading>.broadcast();

  Stream<Component3GpsReading> get readings => _controller.stream;

  String status = 'Not started';

  Future<bool> start() async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) {
      status = 'Location services disabled';
      return false;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      status = 'Location permission denied';
      return false;
    }

    status = 'Waiting for GPS fix';

    _subscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (position) {
        final age = DateTime.now().difference(position.timestamp);

        if (age.isNegative ||
            age > const Duration(seconds: 15) ||
            !position.latitude.isFinite ||
            !position.longitude.isFinite ||
            !position.accuracy.isFinite ||
            position.accuracy < 0 ||
            position.accuracy > 50 ||
            !position.speed.isFinite ||
            !position.altitude.isFinite ||
            position.latitude.abs() > 90 ||
            position.longitude.abs() > 180) {
          status = 'GPS reading rejected: invalid or inaccurate';
          return;
        }

        status = 'GPS reading received';

        _controller.add(
          Component3GpsReading(
            timestamp: position.timestamp,
            latitude: position.latitude,
            longitude: position.longitude,
            speedMps: position.speed < 0 ? 0 : position.speed,
            altitudeM: position.altitude,
            accuracyM: position.accuracy,
          ),
        );
      },
      onError: (Object error) {
        status = 'GPS stream unavailable: $error';
      },
    );

    return true;
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    status = 'Stopped';
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}