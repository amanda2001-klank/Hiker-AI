import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_venture_flutter/features/hiking/data/weather_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/hiking/data/sensor_data_model.dart';
import 'package:app_venture_flutter/features/hiking/data/wearable_service.dart';
import 'package:app_venture_flutter/features/hiking/data/phone_sensor_service.dart';
import 'package:app_venture_flutter/features/hiking/presentation/live_monitoring_controller.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  test('SensorDataModel Initial State Test', () {
    final model = SensorDataModel.initial();
    expect(model.heartRate, isNull);
    expect(model.hrv, isNull);
    expect(model.spo2, isNull);
    expect(model.stepCount, isNull);
    expect(model.dataSource, equals('idle'));
  });

  test('WearableService Connection Simulation Test', () async {
    final wearable = WearableService();
    expect(wearable.status, equals(WearableConnectionStatus.disconnected));

    final connected = await wearable.connectDevice('TEST_WATCH');
    expect(connected, isFalse);
    expect(wearable.status, isNot(equals(WearableConnectionStatus.connected)));
    expect(wearable.lastSyncTime, isNull);

    wearable.disconnect();
    expect(wearable.status, equals(WearableConnectionStatus.disconnected));
    wearable.dispose();
  });

  test('PhoneSensorService Tracking Test', () async {
    final phone = PhoneSensorService();
    expect(phone.isTracking, isFalse);

    final perm = await phone.requestPermissions();
    expect(perm, isTrue);

    phone.startTracking();
    expect(phone.isTracking, isTrue);

    phone.stopTracking();
    expect(phone.isTracking, isFalse);
    phone.dispose();
  });

  test('LiveMonitoringNotifier Explicit Demo Mode Test', () {
    final wearable = WearableService();
    final phone = PhoneSensorService();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final weather = container.read(weatherRepositoryProvider);
    final notifier = LiveMonitoringNotifier(wearable, phone, weather);

    expect(notifier.state.isDemoMode, isFalse);

    notifier.toggleDemoMode(true);
    expect(notifier.state.isDemoMode, isTrue);
    expect(notifier.state.currentData.dataSource, contains('Explicit DEMO Simulation Mode'));

    notifier.toggleDemoMode(false);
    expect(notifier.state.isDemoMode, isFalse);

    notifier.dispose();
  });
}
