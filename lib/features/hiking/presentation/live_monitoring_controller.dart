import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sensor_data_model.dart';
import '../data/wearable_service.dart';
import '../data/phone_sensor_service.dart';
import '../data/component3_raw_input_collector.dart';
import '../data/component3_gps_service.dart';
import '../data/component3_sensor_window.dart';
import '../data/weather_repository.dart';
import '../data/component3_safety_trigger_engine.dart';
import '../data/component3_safety_alert_gate.dart';

import 'package:geolocator/geolocator.dart';

enum MonitoringState {
  idle,
  connecting,
  monitoring,
  paused,
  sensorUnavailable,
  error,
}

class LiveMonitoringState {
  final MonitoringState state;
  final SensorDataModel currentData;
  final bool isDemoMode;
  final String? errorMessage;
  final int? sessionId;

  const LiveMonitoringState({
    required this.state,
    required this.currentData,
    required this.isDemoMode,
    this.errorMessage,
    this.sessionId,
  });

  factory LiveMonitoringState.initial() => LiveMonitoringState(
    state: MonitoringState.idle,
    currentData: SensorDataModel.initial(),
    isDemoMode: false,
  );

  LiveMonitoringState copyWith({
    MonitoringState? state,
    SensorDataModel? currentData,
    bool? isDemoMode,
    String? errorMessage,
    int? sessionId,
  }) {
    return LiveMonitoringState(
      state: state ?? this.state,
      currentData: currentData ?? this.currentData,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      errorMessage: errorMessage ?? this.errorMessage,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

class LiveMonitoringNotifier extends StateNotifier<LiveMonitoringState> {
  // STEP393E4C_INPUT_SYNC
  // Actual user inputs only; no fabricated defaults.
  double? _safetySleepHours;
  double? _safetyRestingHeartRate;
  Duration _safetyHikeDuration = Duration.zero;

  void updateSafetyInputs({
    required double? sleepHours,
    required double? restingHeartRate,
    required Duration hikeDuration,
  }) {
    _safetySleepHours =
        sleepHours != null &&
            sleepHours.isFinite &&
            sleepHours >= 0 &&
            sleepHours <= 24
        ? sleepHours
        : null;

    _safetyRestingHeartRate =
        restingHeartRate != null &&
            restingHeartRate.isFinite &&
            restingHeartRate >= 30 &&
            restingHeartRate <= 150
        ? restingHeartRate
        : null;

    _safetyHikeDuration = hikeDuration.isNegative
        ? Duration.zero
        : hikeDuration;
  }

  // Read-only safety evaluation. Does NOT post notifications.
  List<Component3SafetyTrigger> get component3LiveSafetyTriggers {
    if (!mounted ||
        state.isDemoMode ||
        state.state != MonitoringState.monitoring) {
      return const [];
    }

    final now = DateTime.now();
    final history = component3RawHistory;
    final latest = history.isEmpty ? null : history.last;

    final timestamp = latest?['timestamp_ms'];
    final hr = latest?['heart_rate_bpm'];

    final hrFresh =
        timestamp is int &&
        hr is num &&
        hr.isFinite &&
        !now
            .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
            .isNegative &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp)) <=
            const Duration(seconds: 10);

    final weather = component3LatestWeather;

    return const Component3SafetyTriggerEngine().evaluate(
      Component3SafetyInputs(
        sleepHours: _safetySleepHours,
        restingHeartRateBpm: _safetyRestingHeartRate,
        hikeDuration: _safetyHikeDuration,
        liveHeartRateBpm: hrFresh ? hr.toDouble() : null,
        temperatureC: weather?.temperatureCelsius,
        humidityPercent: weather?.humidityPercent,
        weatherVerified: component3WeatherVerified,
      ),
    );
  }

  // STEP393E4D_AUTO_RULE_ALERTS
  // Non-diagnostic rule-based cautions, not TFLite risk predictions.
  final Component3SafetyAlertGate _ruleAlertGate = Component3SafetyAlertGate();

  final Set<Component3SafetyCategory> _ruleAlertsSending = {};
  final Map<Component3SafetyCategory, DateTime> _ruleRetryAfter = {};

  String _ruleAlertCategory(Component3SafetyCategory category) {
    switch (category) {
      case Component3SafetyCategory.fatigue:
        return 'fatigue_caution';
      case Component3SafetyCategory.physicalStrain:
        return 'physical_strain_caution';
      case Component3SafetyCategory.heatExposure:
        return 'heat_exposure_caution';
    }
  }

  void _checkAutomaticRuleAlerts() {
    if (!mounted) return;

    final active =
        state.state == MonitoringState.monitoring && !state.isDemoMode;

    final ready = active && _guidanceSessionReady && _guidanceSessionId != null;

    final triggers = ready
        ? component3LiveSafetyTriggers
        : <Component3SafetyTrigger>[];

    final now = DateTime.now();

    final eligible = _ruleAlertGate.evaluate(
      now: now,
      monitoringActive: active,
      guidanceSessionReady: ready,
      activeCategories: triggers.map((trigger) => trigger.category),
    );

    final sessionId = _guidanceSessionId;
    if (!ready || sessionId == null) return;

    for (final category in eligible) {
      final retryAfter = _ruleRetryAfter[category];

      if (_ruleAlertsSending.contains(category) ||
          (retryAfter != null && now.isBefore(retryAfter))) {
        // Undo only this unattempted reservation.
        _ruleAlertGate.releaseFailedDelivery(category, now);
        continue;
      }

      _ruleAlertsSending.add(category);
      unawaited(_deliverRuleAlert(category, sessionId, now));
    }
  }

  Future<void> _deliverRuleAlert(
    Component3SafetyCategory category,
    String sessionId,
    DateTime reservedAt,
  ) async {
    final name = _ruleAlertCategory(category);
    var phoneSent = false;
    var watchSent = false;

    bool currentSession() =>
        mounted &&
        !state.isDemoMode &&
        state.state == MonitoringState.monitoring &&
        _guidanceSessionReady &&
        _guidanceSessionId == sessionId;

    try {
      if (!currentSession()) return;

      // Recheck the current condition before delivery.
      if (!component3LiveSafetyTriggers.any(
        (trigger) => trigger.category == category,
      )) {
        return;
      }

      try {
        phoneSent =
            await _guidancePhoneChannel.invokeMethod<bool>(
              'showSensorGuidance',
              {'category': name},
            ) ==
            true;
      } catch (error) {
        debugPrint('AUTO_RULE PHONE_ERROR=$name ${error.runtimeType}');
      }

      debugPrint('AUTO_RULE PHONE category=$name sent=$phoneSent');

      if (!currentSession()) return;

      try {
        watchSent =
            await _guidanceWatchChannel.invokeMethod<bool>(
              'sendSensorGuidance',
              {'category': name, 'session_id': sessionId},
            ) ==
            true;
      } catch (error) {
        debugPrint('AUTO_RULE WATCH_ERROR=$name ${error.runtimeType}');
      }

      debugPrint('AUTO_RULE WATCH category=$name sent=$watchSent');
    } finally {
      // Never clear a new session's gate from an old async delivery.
      if (_guidanceSessionId == sessionId && mounted) {
        if (!phoneSent && !watchSent) {
          _ruleAlertGate.releaseFailedDelivery(category, reservedAt);
          _ruleRetryAfter[category] = DateTime.now().add(
            const Duration(seconds: 30),
          );
        }
        _ruleAlertsSending.remove(category);
      }
    }
  }

  final WearableService _wearableService;
  final PhoneSensorService _phoneSensorService;
  final WeatherRepository _weatherRepository;
  final Component3RawInputCollector _component3Collector =
      Component3RawInputCollector();

  int get component3PacketCount => _component3Collector.packetCount;

  List<Map<String, dynamic>> get component3RawHistory =>
      _component3Collector.history;

  final Component3GpsService _component3Gps = Component3GpsService();
  StreamSubscription<Component3GpsReading>? _component3GpsSub;
  Component3GpsReading? _latestGps;

  Component3GpsReading? get component3LatestGps => _latestGps;
  String get component3GpsStatus => _component3Gps.status;
  Component3VerifiedWeather? _latestWeather;
  DateTime? _lastWeatherAttempt;
  bool _phoneWeatherBusy = false;
  int _weatherGeneration = 0;

  Component3VerifiedWeather? get component3LatestWeather =>
      component3WeatherVerified ? _latestWeather : null;

  bool get component3WeatherVerified {
    final weather = _latestWeather;
    if (weather == null ||
        state.isDemoMode ||
        state.state != MonitoringState.monitoring) {
      return false;
    }
    final age = DateTime.now().difference(weather.receivedAt);
    return !age.isNegative && age <= const Duration(minutes: 15);
  }

  // Approximate location for weather API only.
  // Does not bypass GPS validation for AI movement inputs.
  // STEP357_PHONE_LOCATION
  // Weather-only approximate phone location. No hiking GPS tracking.
  Future<void> _tryCoarseWeather() async {
    if (!mounted ||
        _phoneWeatherBusy ||
        state.isDemoMode ||
        state.state != MonitoringState.monitoring) {
      return;
    }

    final now = DateTime.now();
    final previous = _lastWeatherAttempt;
    final retryInterval = _latestWeather == null
        ? const Duration(seconds: 20)
        : const Duration(minutes: 5);

    if (previous != null && now.difference(previous) < retryInterval) {
      return;
    }

    _phoneWeatherBusy = true;
    _lastWeatherAttempt = now;
    final generation = _weatherGeneration;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        debugPrint('PHONE_WEATHER: Location services disabled');
        return;
      }

      final permission = await Geolocator.checkPermission();

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        debugPrint('PHONE_WEATHER: Location permission unavailable');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final age = DateTime.now().difference(position.timestamp);

      if (age.isNegative ||
          age > const Duration(minutes: 2) ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite ||
          !position.accuracy.isFinite ||
          position.accuracy < 0 ||
          position.accuracy > 5000 ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180) {
        debugPrint('PHONE_WEATHER: Location unavailable or stale');
        return;
      }

      final weather = await _weatherRepository.getVerifiedAiWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted ||
          generation != _weatherGeneration ||
          state.isDemoMode ||
          state.state != MonitoringState.monitoring) {
        return;
      }

      if (weather == null) {
        debugPrint('PHONE_WEATHER: API returned no usable weather');
        return;
      }

      _latestWeather = weather;
      _component3Window.acceptWeather(weather);
      state = state.copyWith();

      debugPrint(
        'PHONE_WEATHER: SUCCESS '
        'temperature=${weather.temperatureCelsius} '
        'humidity=${weather.humidityPercent}',
      );
    } catch (error) {
      debugPrint('PHONE_WEATHER: ERROR ${error.runtimeType}');
    } finally {
      _phoneWeatherBusy = false;
    }
  }

  Future<void> _fetchComponent3Weather(Component3GpsReading gps) async {
    if (state.isDemoMode ||
        (state.state != MonitoringState.monitoring &&
            state.state != MonitoringState.connecting)) {
      return;
    }

    final now = DateTime.now();
    final previous = _lastWeatherAttempt;

    final retryInterval = _latestWeather == null
        ? const Duration(seconds: 20)
        : const Duration(minutes: 5);
    if (previous != null && now.difference(previous) < retryInterval) {
      return;
    }

    _lastWeatherAttempt = now;
    final generation = ++_weatherGeneration;

    final weather = await _weatherRepository.getVerifiedAiWeather(
      latitude: gps.latitude,
      longitude: gps.longitude,
    );

    if (!mounted ||
        generation != _weatherGeneration ||
        state.isDemoMode ||
        (state.state != MonitoringState.monitoring &&
            state.state != MonitoringState.connecting)) {
      return;
    }

    _latestWeather = weather;
    if (weather != null) {
      _component3Window.acceptWeather(weather);
    }
    state = state.copyWith();
  }

  final Component3SensorWindow _component3Window = Component3SensorWindow();

  int get component3SensorWindowCount => _component3Window.count;
  List<Component3SensorSample>? get component3LatestTenSamples =>
      _component3Window.latestTen;
  Timer? _simulationTimer;
  Timer? _freshnessTimer;
  StreamSubscription<SensorDataModel>? _sensorSub;
  StreamSubscription<String>? _errorSub;
  DateTime? _lastPacketReceived;
  int _simulationStep = 0;

  LiveMonitoringNotifier(
    this._wearableService,
    this._phoneSensorService,
    this._weatherRepository,
  ) : super(LiveMonitoringState.initial());

  void setSessionId(int sessionId) {
    state = state.copyWith(sessionId: sessionId);
  }

  void toggleDemoMode(bool enabled) {
    if (enabled) {
      startDemoSimulation();
    } else {
      stopSimulation();
      state = state.copyWith(isDemoMode: false);
    }
  }

  // STEP371C_GUIDANCE_SESSION
  // Session for sensor guidance only. Not an AI risk prediction.
  static const MethodChannel _guidanceWatchChannel = MethodChannel(
    'com.example.app_venture_flutter/wearable',
  );

  String? _guidanceSessionId;
  bool _guidanceSessionStarting = false;
  bool _guidanceSessionReady = false;

  // Exposed for future guidance delivery and device diagnostics.
  bool get component3GuidanceSessionReady => _guidanceSessionReady;

  int _guidanceSessionGeneration = 0;

  Future<void> _startGuidanceSession() async {
    if (_guidanceSessionId != null ||
        _guidanceSessionStarting ||
        !mounted ||
        state.isDemoMode ||
        state.state != MonitoringState.monitoring) {
      return;
    }

    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    final generation = ++_guidanceSessionGeneration;

    _guidanceSessionId = sessionId;
    _guidanceSessionStarting = true;
    _guidanceSessionReady = false;

    try {
      final sent = await _guidanceWatchChannel.invokeMethod<bool>(
        'setGuidanceSession',
        {'command': 'START', 'session_id': sessionId},
      );

      if (!mounted ||
          generation != _guidanceSessionGeneration ||
          _guidanceSessionId != sessionId) {
        return;
      }

      _guidanceSessionReady = sent == true;

      debugPrint(
        'GUIDANCE_SESSION START_SENT=${sent == true} '
        'id=$sessionId',
      );
    } catch (error) {
      debugPrint('GUIDANCE_SESSION START_ERROR=${error.runtimeType}');
    } finally {
      if (generation == _guidanceSessionGeneration) {
        _guidanceSessionStarting = false;
      }
    }
  }

  void _stopGuidanceSession() {
    _ruleAlertGate.resetSession();
    _ruleAlertsSending.clear();
    _ruleRetryAfter.clear();
    _resetGuidanceTracking();

    final sessionId = _guidanceSessionId;

    _guidanceSessionId = null;
    _guidanceSessionReady = false;
    _guidanceSessionStarting = false;
    _guidanceSessionGeneration++;

    if (sessionId == null) {
      return;
    }

    unawaited(_sendGuidanceStop(sessionId));
  }

  Future<void> _sendGuidanceStop(String sessionId) async {
    try {
      await _guidanceWatchChannel.invokeMethod<bool>('setGuidanceSession', {
        'command': 'STOP',
        'session_id': sessionId,
      });

      debugPrint('GUIDANCE_SESSION STOP_SENT');
    } catch (error) {
      debugPrint('GUIDANCE_SESSION STOP_ERROR=${error.runtimeType}');
    }
  }

  // STEP376_AUTOMATIC_GUIDANCE
  // Sensor availability only; no model inference or risk classification.
  static const MethodChannel _guidancePhoneChannel = MethodChannel(
    'com.example.app_venture_flutter/component3_phone_guidance',
  );

  final Map<String, DateTime> _guidanceIssueSince = {};
  final Map<String, DateTime> _guidanceLastSent = {};
  final Set<String> _guidanceSending = {};

  void _resetGuidanceTracking() {
    _guidanceIssueSince.clear();
    _guidanceLastSent.clear();
    _guidanceSending.clear();
  }

  void _checkAutomaticGuidance() {
    if (!mounted ||
        state.isDemoMode ||
        !(state.state == MonitoringState.monitoring ||
            state.state == MonitoringState.sensorUnavailable) ||
        !_guidanceSessionReady ||
        _guidanceSessionId == null) {
      return;
    }

    final now = DateTime.now();
    final history = component3RawHistory;
    final latest = history.isEmpty ? null : history.last;
    final timestamp = latest?['timestamp_ms'];
    final heartRate = latest?['heart_rate_bpm'];

    final hrFresh =
        timestamp is int &&
        heartRate is num &&
        heartRate.isFinite &&
        !now
            .difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
            .isNegative &&
        now.difference(DateTime.fromMillisecondsSinceEpoch(timestamp)) <=
            const Duration(seconds: 10);

    _trackGuidanceIssue('heart_rate_unavailable', !hrFresh, now);

    // STEP393E2_LIFECYCLE_FIX
    if (state.state == MonitoringState.monitoring) {
      _trackGuidanceIssue(
        'weather_unavailable',
        !component3WeatherVerified,
        now,
      );
    } else {
      _guidanceIssueSince.remove('weather_unavailable');
    }
  }

  void _trackGuidanceIssue(String category, bool activeIssue, DateTime now) {
    if (!activeIssue) {
      _guidanceIssueSince.remove(category);
      return;
    }

    final started = _guidanceIssueSince.putIfAbsent(category, () => now);

    if (now.difference(started) < const Duration(seconds: 45)) {
      return;
    }

    final lastSent = _guidanceLastSent[category];
    if (lastSent != null &&
        now.difference(lastSent) < const Duration(minutes: 5)) {
      return;
    }

    if (_guidanceSending.contains(category)) {
      return;
    }

    final sessionId = _guidanceSessionId;
    if (sessionId == null) {
      return;
    }

    _guidanceSending.add(category);
    _guidanceLastSent[category] = now;

    unawaited(_deliverSensorGuidance(category, sessionId));
  }

  Future<void> _deliverSensorGuidance(String category, String sessionId) async {
    try {
      if (!mounted ||
          !(state.state == MonitoringState.monitoring ||
              (category == 'heart_rate_unavailable' &&
                  state.state == MonitoringState.sensorUnavailable)) ||
          state.isDemoMode ||
          !_guidanceSessionReady ||
          _guidanceSessionId != sessionId) {
        return;
      }

      try {
        final phoneSent = await _guidancePhoneChannel.invokeMethod<bool>(
          'showSensorGuidance',
          {'category': category},
        );
        debugPrint('AUTO_GUIDANCE PHONE category=$category sent=$phoneSent');
      } catch (error) {
        debugPrint('AUTO_GUIDANCE PHONE_ERROR=${error.runtimeType}');
      }

      if (!mounted ||
          !(state.state == MonitoringState.monitoring ||
              (category == 'heart_rate_unavailable' &&
                  state.state == MonitoringState.sensorUnavailable)) ||
          state.isDemoMode ||
          !_guidanceSessionReady ||
          _guidanceSessionId != sessionId) {
        return;
      }

      try {
        final watchSent = await _guidanceWatchChannel.invokeMethod<bool>(
          'sendSensorGuidance',
          {'category': category, 'session_id': sessionId},
        );
        debugPrint('AUTO_GUIDANCE WATCH category=$category sent=$watchSent');
      } catch (error) {
        debugPrint('AUTO_GUIDANCE WATCH_ERROR=${error.runtimeType}');
      }
    } finally {
      _guidanceSending.remove(category);
    }
  }

  Future<void> startMonitoring() async {
    if (state.state == MonitoringState.monitoring ||
        state.state == MonitoringState.connecting) {
      return;
    }
    _stopGuidanceSession();
    stopSimulation();
    await _sensorSub?.cancel();
    await _errorSub?.cancel();
    _freshnessTimer?.cancel();
    _component3Collector.reset();
    _component3Window.reset();
    _latestGps = null;
    _latestWeather = null;
    _lastWeatherAttempt = null;
    _weatherGeneration++;
    await _component3GpsSub?.cancel();
    _component3GpsSub = null;
    await _component3Gps.stop();
    _lastPacketReceived = null;
    state = state.copyWith(
      state: MonitoringState.connecting,
      currentData: SensorDataModel.initial(),
      isDemoMode: false,
    );
    try {
      final connected = await _wearableService.connectDevice('Watch6');
      if (!connected) {
        state = state.copyWith(
          state: MonitoringState.sensorUnavailable,
          errorMessage: 'Galaxy Watch6 node not reachable',
        );
        return;
      }
      // GPS is independent of the Watch6 telemetry stream.
      _component3GpsSub = _component3Gps.readings.listen((reading) {
        if (state.state == MonitoringState.paused || state.isDemoMode) {
          return;
        }
        _latestGps = reading;
        _component3Window.acceptGps(reading);
        state = state.copyWith();
        unawaited(_fetchComponent3Weather(reading));
      });

      // GPS permission or GPS availability must never block Watch6.
      // STEP357_PHONE_LOCATION: hiking GPS tracking deferred.
      _sensorSub = _wearableService.sensorStream.listen((reading) {
        if (state.isDemoMode || state.state == MonitoringState.paused) {
          return;
        }
        _lastPacketReceived = DateTime.now();

        final acceptedPacket = _component3Collector.acceptWatchReading(
          reading,
          isDemoMode: state.isDemoMode,
          receivedAt: _lastPacketReceived,
        );
        if (acceptedPacket != null) {
          _component3Window.acceptWatchPacket(acceptedPacket);
        }

        state = state.copyWith(
          state: MonitoringState.monitoring,
          currentData: reading,
        );
        if (acceptedPacket != null) {
          unawaited(_startGuidanceSession());
        }
      });
      _errorSub = _wearableService.errorStream.listen((message) {
        state = state.copyWith(
          state: MonitoringState.error,
          currentData: SensorDataModel.initial(),
          errorMessage: message,
        );
      });
      _freshnessTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        // STEP357_PHONE_LOCATION: weather independent of GPS and Watch6 packets.
        unawaited(_tryCoarseWeather());
        if (state.isDemoMode || state.state == MonitoringState.paused) {
          return;
        }
        _checkAutomaticGuidance();
        _checkAutomaticRuleAlerts();
        final last = _lastPacketReceived;
        if (last == null) {
          return;
        }
        if (DateTime.now().difference(last) > const Duration(seconds: 15)) {
          state = state.copyWith(
            state: MonitoringState.sensorUnavailable,
            currentData: SensorDataModel.initial(),
            errorMessage: 'Watch data unavailable or stale',
          );
        }
      });
      // A discovered node is not proof that the exercise has started.
      // Exercise start remains manual until Watch package/signature compatibility is confirmed.
    } catch (e) {
      state = state.copyWith(
        state: MonitoringState.error,
        currentData: SensorDataModel.initial(),
        errorMessage: e.toString(),
      );
    }
  }

  void pauseMonitoring() {
    if (state.state != MonitoringState.monitoring &&
        state.state != MonitoringState.sensorUnavailable) {
      return;
    }
    _stopGuidanceSession();

    _component3Collector.reset();
    _component3Window.reset();
    _latestGps = null;
    _latestWeather = null;
    _lastWeatherAttempt = null;
    _weatherGeneration++;
    unawaited(_component3Gps.stop());
    state = state.copyWith(
      state: MonitoringState.paused,
      currentData: SensorDataModel.initial(),
    );
    stopSimulation();
  }

  void resumeMonitoring() {
    if (state.state != MonitoringState.paused) {
      return;
    }
    _lastPacketReceived = null;
    _component3Collector.reset();
    _component3Window.reset();
    _latestGps = null;
    _latestWeather = null;
    _lastWeatherAttempt = null;
    _weatherGeneration++;
    state = state.copyWith(
      state: MonitoringState.connecting,
      currentData: SensorDataModel.initial(),
    );

    // Resume GPS independently; do not block Watch6 monitoring.
    // STEP357_PHONE_LOCATION: hiking GPS tracking deferred.
    if (state.isDemoMode) startDemoSimulation();
  }

  void startDemoSimulation() {
    _stopGuidanceSession();
    stopSimulation();
    state = state.copyWith(
      isDemoMode: true,
      state: MonitoringState.monitoring,
      currentData: SensorDataModel(
        timestamp: DateTime.now(),
        heartRate: 122.0,
        hrv: 50.0,
        spo2: 99.0,
        stepCount: 1200,
        speedMs: 1.3,
        distanceKm: 1.5,
        elevationM: 320.0,
        dataSource: 'Explicit DEMO Simulation Mode',
        dataFreshness: Duration.zero,
        measurementQuality: 'simulated',
      ),
    );

    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _simulationStep++;
      final hr = 120.0 + (_simulationStep % 15);
      final steps = 1200 + (_simulationStep * 25);
      final dist = 1.5 + (_simulationStep * 0.05);
      final elev = 320.0 + (_simulationStep * 1.2);

      state = state.copyWith(
        currentData: SensorDataModel(
          timestamp: DateTime.now(),
          heartRate: hr,
          hrv: 50.0,
          spo2: 99.0,
          stepCount: steps,
          speedMs: 1.3,
          distanceKm: double.parse(dist.toStringAsFixed(2)),
          elevationM: double.parse(elev.toStringAsFixed(1)),
          dataSource: 'Explicit DEMO Simulation Mode',
          dataFreshness: Duration.zero,
          measurementQuality: 'simulated',
        ),
      );
    });
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _stopGuidanceSession();
    stopSimulation();
    _weatherGeneration++;
    _wearableService.dispose();
    _phoneSensorService.dispose();
    unawaited(_component3GpsSub?.cancel());
    unawaited(_component3Gps.dispose());
    super.dispose();
  }
}

final wearableServiceProvider = Provider<WearableService>(
  (ref) => WearableService(),
);
final phoneSensorServiceProvider = Provider<PhoneSensorService>(
  (ref) => PhoneSensorService(),
);

final liveMonitoringControllerProvider =
    StateNotifierProvider<LiveMonitoringNotifier, LiveMonitoringState>((ref) {
      final wearable = ref.watch(wearableServiceProvider);
      final phone = ref.watch(phoneSensorServiceProvider);
      final weather = ref.read(weatherRepositoryProvider);
      return LiveMonitoringNotifier(wearable, phone, weather);
    });
