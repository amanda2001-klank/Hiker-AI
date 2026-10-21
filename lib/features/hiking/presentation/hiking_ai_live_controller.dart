import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fitness/data/fitness_profile_repository.dart';
import '../data/hiking_ai_input_service.dart';
import '../data/onnx_exertion_service.dart';
import '../data/sensor_data_model.dart';

class HikingAiLiveState {
  final double? estimatedBorg;
  final double? age;
  final String message;
  final bool loading;

  const HikingAiLiveState({
    this.estimatedBorg,
    this.age,
    this.message = 'AI inputs not configured',
    this.loading = false,
  });
}

class HikingAiLiveController extends StateNotifier<HikingAiLiveState> {
  final FitnessProfileRepository _profiles;
  final HikingAiInputService _inputs;
  final OnnxExertionService _onnx;

  HikingAiProfileInputs? _profile;
  Timer? _expiryTimer;
  DateTime? _lastRealReading;
  DateTime? _lastInferenceStarted;
  int _generation = 0;
  int _profileGeneration = 0;
  bool _busy = false;

  HikingAiLiveController(this._profiles, this._inputs, this._onnx)
    : super(const HikingAiLiveState()) {
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = _lastRealReading;
      if (last != null &&
          DateTime.now().difference(last) > const Duration(seconds: 10)) {
        _invalidate('Insufficient data: Watch6 HR unavailable or stale');
      }
    });
  }

  Future<void> loadProfileAge({
    required String email,
    required String username,
  }) async {
    final request = ++_profileGeneration;
    _profile = null;
    _lastRealReading = null;
    state = const HikingAiLiveState(message: 'Loading saved age');

    try {
      if (email.trim().isEmpty || username.trim().isEmpty) {
        throw StateError('Authenticated user required');
      }

      final localId = await _profiles.getOrCreateUserIdByEmail(email, username);

      final age = await _inputs.getSavedAge(localId);
      if (!mounted || request != _profileGeneration) return;

      if (age == null) {
        state = const HikingAiLiveState(
          message: 'Save your Fitness Profile age first',
        );
        return;
      }

      state = HikingAiLiveState(
        age: age,
        message: 'Enter training years and sleep hours',
      );
    } catch (_) {
      if (!mounted || request != _profileGeneration) return;
      state = const HikingAiLiveState(
        message: 'Unable to load saved fitness profile',
      );
    }
  }

  void configureInputs({
    required double? fitnessYears,
    required double? sleepingHours,
  }) {
    _invalidate('Checking AI profile inputs');

    final validated = _inputs.validateInputs(
      age: state.age,
      fitnessYears: fitnessYears,
      sleepingHours: sleepingHours,
    );

    if (validated == null) {
      _profile = null;
      state = HikingAiLiveState(
        age: state.age,
        message: 'Complete valid training years and sleep hours',
      );
      return;
    }

    _profile = validated;
    state = HikingAiLiveState(
      age: validated.age,
      message: 'Ready: waiting for fresh Watch6 HR',
    );
  }

  Future<void> onSensorData(
    SensorDataModel reading, {
    required bool isDemoMode,
  }) async {
    final profile = _profile;
    final hr = reading.heartRate;
    final now = DateTime.now();
    final packetAge = now.difference(reading.timestamp);

    final valid =
        !isDemoMode &&
        reading.dataSource.startsWith('Watch6 telemetry') &&
        reading.measurementQuality != 'simulated' &&
        hr != null &&
        hr.isFinite &&
        hr >= 60 &&
        hr <= 99 &&
        !packetAge.isNegative &&
        packetAge <= const Duration(seconds: 10) &&
        reading.dataFreshness <= const Duration(seconds: 10);

    if (!valid) {
      _invalidate('Insufficient data: fresh real Watch6 HR required');
      return;
    }

    _lastRealReading = now;

    if (profile == null) {
      _invalidate('Complete AI profile inputs first');
      return;
    }

    if (_busy) return;

    if (_lastInferenceStarted != null &&
        now.difference(_lastInferenceStarted!) < const Duration(seconds: 4)) {
      return;
    }

    final request = ++_generation;
    _busy = true;
    _lastInferenceStarted = now;

    state = HikingAiLiveState(
      age: profile.age,
      loading: true,
      message: 'Estimating exertion on device',
    );

    try {
      final score = await _onnx.predictExertion(
        heartRate: hr,
        age: profile.age,
        fitnessYears: profile.fitnessYears,
        sleepingHours: profile.sleepingHours,
      );

      if (!mounted || request != _generation) return;

      final last = _lastRealReading;
      if (last == null ||
          DateTime.now().difference(last) > const Duration(seconds: 10)) {
        _invalidate('Insufficient data: Watch6 HR became stale');
        return;
      }

      state = HikingAiLiveState(
        estimatedBorg: score,
        age: profile.age,
        message: 'Estimated exertion proxy; not a medical diagnosis',
      );
    } catch (_) {
      if (!mounted || request != _generation) return;
      state = HikingAiLiveState(
        age: profile.age,
        message: 'On-device inference unavailable',
      );
    } finally {
      _busy = false;
    }
  }

  void onMonitoringUnavailable() {
    _invalidate('Insufficient data: Watch6 monitoring unavailable');
  }

  void clearPrediction() {
    _invalidate('Waiting for fresh Watch6 HR');
  }

  void _invalidate(String message) {
    ++_generation;
    _lastRealReading = null;
    if (!mounted) return;
    state = HikingAiLiveState(age: state.age, message: message);
  }

  @override
  void dispose() {
    ++_generation;
    _expiryTimer?.cancel();
    super.dispose();
  }
}

final hikingAiLiveControllerProvider =
    StateNotifierProvider<HikingAiLiveController, HikingAiLiveState>((ref) {
      final profiles = ref.watch(fitnessProfileRepositoryProvider);
      final inputs = ref.watch(hikingAiInputServiceProvider);
      return HikingAiLiveController(profiles, inputs, OnnxExertionService());
    });
