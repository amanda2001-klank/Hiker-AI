import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Optional phone GPS altitude readings, never simulated.
/// No background collection; caller owns and cancels the returned subscription.
class PhoneGpsAltitudeService {
  // Diagnostics only: no coordinates stored or transmitted.
  static final ValueNotifier<String> diagnostic = ValueNotifier<String>(
    'GPS not started',
  );
  static Future<Stream<double>> start() async {
    diagnostic.value = 'Waiting for first GPS fix';
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Location services are disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission not granted');
    }
    return Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 5,
          ),
        )
        .map((p) {
          // Observe every GPS sample BEFORE existing quality filtering.
          final valid =
              p.altitude.isFinite &&
              p.altitude >= -500 &&
              p.altitude <= 9000 &&
              p.accuracy.isFinite &&
              p.accuracy <= 30 &&
              p.altitudeAccuracy.isFinite &&
              p.altitudeAccuracy > 0 &&
              p.altitudeAccuracy <= 10;
          diagnostic.value =
              'GPS hAcc ${p.accuracy.toStringAsFixed(1)} m | '
              'vAcc ${p.altitudeAccuracy.toStringAsFixed(1)} m | '
              '${valid ? 'ACCEPTED' : 'REJECTED: low accuracy/invalid altitude'}';
          return p;
        })
        .where(
          (p) =>
              p.altitude.isFinite &&
              p.altitude >= -500 &&
              p.altitude <= 9000 &&
              p.accuracy.isFinite &&
              p.accuracy <= 30 &&
              p.altitudeAccuracy.isFinite &&
              p.altitudeAccuracy > 0 &&
              p.altitudeAccuracy <= 10,
        )
        .map((p) => p.altitude);
  }
}
