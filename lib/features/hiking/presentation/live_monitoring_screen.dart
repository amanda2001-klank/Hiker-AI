import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'live_monitoring_controller.dart';
import '../data/sensor_data_model.dart';
import '../data/component3_safety_trigger_engine.dart';
import 'hiking_ai_live_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/trail_repository.dart';
import '../data/session_telemetry_repository.dart';

class LiveMonitoringScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;
  const LiveMonitoringScreen({super.key, this.extraData});

  @override
  ConsumerState<LiveMonitoringScreen> createState() =>
      _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends ConsumerState<LiveMonitoringScreen> {
  late int? _sessionId;
  late TrailModel? _trail;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  bool _isEndingHike = false;
  // AI_SCREEN_INTEGRATION_V1 -- test copy only.
  final _trainingYears = TextEditingController();
  final _sleepHours = TextEditingController();
  final _restingHeartRate = TextEditingController();
  late final HikingAiLiveController _aiController;
  ProviderSubscription<LiveMonitoringState>? _aiWatchSubscription;
  ProviderSubscription<HikingAiLiveState>? _borgSubscription;
  Future<void> _pendingWrites = Future<void>.value();
  // UI-only last-known readings. Never feed these into AI, alerts or storage.
  double? _lastDisplayedHeartRate;
  DateTime? _lastDisplayedHeartRateAt;
  int? _lastDisplayedSteps;
  DateTime? _lastDisplayedStepsAt;
  static const Duration _displayHold = Duration(seconds: 8);

  String _heartRateLabel(SensorDataModel data, LiveMonitoringState live) {
    if (live.isDemoMode) {
      return data.heartRate == null
          ? 'Unavailable'
          : '${data.heartRate!.toInt()} bpm';
    }
    if (live.state != MonitoringState.monitoring) return 'Unavailable';
    if (data.heartRate != null) return '${data.heartRate!.toInt()} bpm';
    final at = _lastDisplayedHeartRateAt;
    if (at != null &&
        _lastDisplayedHeartRate != null &&
        DateTime.now().difference(at) <= _displayHold) {
      return '${_lastDisplayedHeartRate!.toInt()} bpm (last known)';
    }
    return 'Unavailable';
  }

  String _stepsLabel(SensorDataModel data, LiveMonitoringState live) {
    if (live.isDemoMode) return data.stepCount?.toString() ?? 'Unavailable';
    if (live.state != MonitoringState.monitoring) return 'Unavailable';
    if (data.stepCount != null) return data.stepCount.toString();
    final at = _lastDisplayedStepsAt;
    if (at != null &&
        _lastDisplayedSteps != null &&
        DateTime.now().difference(at) <= _displayHold) {
      return '$_lastDisplayedSteps (last known)';
    }
    return 'Unavailable';
  }

  void _queueWrite(Future<void> Function() action) {
    _pendingWrites = _pendingWrites.then((_) => action()).catchError((
      Object error,
    ) {
      debugPrint('Session metric write failed: $error');
    });
  }

  @override
  void initState() {
    super.initState();
    _aiController = ref.read(hikingAiLiveControllerProvider.notifier);
    _borgSubscription = ref.listenManual<HikingAiLiveState>(
      hikingAiLiveControllerProvider,
      (previous, next) {
        final id = _sessionId;
        if (_isEndingHike ||
            id == null ||
            ref.read(liveMonitoringControllerProvider).isDemoMode ||
            next.estimatedBorg == null) {
          return;
        }
        _queueWrite(
          () => ref
              .read(sessionTelemetryRepositoryProvider)
              .recordBorg(id, next.estimatedBorg!),
        );
      },
    );
    _aiWatchSubscription = ref.listenManual<LiveMonitoringState>(
      liveMonitoringControllerProvider,
      (previous, next) {
        if (_isEndingHike ||
            next.isDemoMode ||
            next.state != MonitoringState.monitoring) {
          _aiController.onMonitoringUnavailable();
          return;
        }
        // Cache only actual incoming samples, not unrelated provider rebuilds.
        // Cached values are exclusively for the two display cards below.
        if (!identical(previous?.currentData, next.currentData)) {
          final sample = next.currentData;
          final now = DateTime.now();
          if (sample.heartRate != null) {
            _lastDisplayedHeartRate = sample.heartRate;
            _lastDisplayedHeartRateAt = now;
          }
          if (sample.stepCount != null) {
            _lastDisplayedSteps = sample.stepCount;
            _lastDisplayedStepsAt = now;
          }
        }
        final id = _sessionId;
        if (id != null) {
          _queueWrite(
            () => ref
                .read(sessionTelemetryRepositoryProvider)
                .recordReading(id, next.currentData),
          );
        }
        _aiController.onSensorData(next.currentData, isDemoMode: false);
      },
    );
    _sessionId = widget.extraData?['sessionId'] as int?;
    _trail = widget.extraData?['trail'] as TrailModel?;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sessionId != null) {
        ref
            .read(liveMonitoringControllerProvider.notifier)
            .setSessionId(_sessionId!);
      }
      ref.read(liveMonitoringControllerProvider.notifier).startMonitoring();
      _startElapsedTimer();
      final user = ref.read(authControllerProvider).user;
      if (user == null) {
        _aiController.onMonitoringUnavailable();
      } else {
        _aiController.loadProfileAge(
          email: user.email,
          username: user.username,
        );
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final state = ref.read(liveMonitoringControllerProvider).state;
        if (state == MonitoringState.monitoring) {
          setState(() {
            _elapsedSeconds++;
            _syncSafetyInputs();
          });
        }
      }
    });
  }

  String _formatElapsedTime(int seconds) {
    final hrs = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _aiWatchSubscription?.close();
    _borgSubscription?.close();
    _trainingYears.dispose();
    _sleepHours.dispose();
    _restingHeartRate.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _confirmEndHike() {
    if (_isEndingHike) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Hiking Session?'),
        content: const Text(
          'Are you sure you want to finish this hike and record your summary?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              _executeEndHike();
            },
            child: const Text('Finish Hike'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeEndHike() async {
    if (_isEndingHike) return;
    setState(() {
      _isEndingHike = true;
    });

    // Stop new collection, wait for all accepted real observations to persist.
    _aiController.onMonitoringUnavailable();
    await _pendingWrites;
    if (!mounted) return;
    context.go('/trail-summary', extra: {'sessionId': _sessionId});
  }

  // STEP389_LIVE_SAFETY: read-only live rule evaluation.
  // This does not post notifications or execute TFLite inference.
  // STEP393E4C_INPUT_SYNC
  void _syncSafetyInputs() {
    if (!mounted || _isEndingHike) return;

    ref
        .read(liveMonitoringControllerProvider.notifier)
        .updateSafetyInputs(
          sleepHours: double.tryParse(_sleepHours.text.trim()),
          restingHeartRate: double.tryParse(_restingHeartRate.text.trim()),
          hikeDuration: Duration(seconds: _elapsedSeconds),
        );
  }

  Widget _buildLiveSafetyCautions(LiveMonitoringState live) {
    final active =
        live.state == MonitoringState.monitoring &&
        !live.isDemoMode &&
        !_isEndingHike;

    final sleepHours = double.tryParse(_sleepHours.text.trim());

    // Shared controller safety evaluation for UI and notifications.
    final triggers = active
        ? ref
              .read(liveMonitoringControllerProvider.notifier)
              .component3LiveSafetyTriggers
        : <Component3SafetyTrigger>[];
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rule-Based Hiking Safety Cautions',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Research prototype guidance; not a medical diagnosis '
              'or an AI risk percentage.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _restingHeartRate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Resting heart rate (BPM, actual)',
                hintText: 'Enter a measured resting HR',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
                _syncSafetyInputs();
              },
            ),
            const SizedBox(height: 8),
            Text(
              sleepHours == null
                  ? 'Sleep hours: not entered. Use the existing '
                        'Last night sleep field below.'
                  : 'Sleep hours input: ${sleepHours.toStringAsFixed(1)} h',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            if (!active)
              const Text('Start live monitoring to evaluate safety rules.')
            else if (triggers.isEmpty)
              const Text(
                'No rule-based cautions currently triggered. '
                'Missing inputs are not treated as safe readings.',
              )
            else
              ...triggers.map(
                (trigger) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: const Color(0xFFFFF4E5),
                    leading: const Icon(
                      Icons.warning_amber_outlined,
                      color: Colors.deepOrange,
                    ),
                    title: Text(trigger.title),
                    subtitle: Text(trigger.recommendation),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AI_AUTH_REFRESH_V1
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final user = next.user;
      if (user != null && previous?.user?.userId != user.userId) {
        ref
            .read(hikingAiLiveControllerProvider.notifier)
            .loadProfileAge(email: user.email, username: user.username);
      }
    });
    final liveState = ref.watch(liveMonitoringControllerProvider);
    final data = liveState.currentData;
    final ai = ref.watch(hikingAiLiveControllerProvider);
    final showEstimate =
        !_isEndingHike &&
        !liveState.isDemoMode &&
        liveState.state == MonitoringState.monitoring &&
        ai.estimatedBorg != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF086477),
        title: const Text(
          'Live Fitness & Hike Monitoring',
          style: TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              liveState.isDemoMode ? Icons.science : Icons.science_outlined,
              color: Colors.white,
            ),
            tooltip: 'Toggle Demo Simulation Mode',
            onPressed: () {
              ref
                  .read(liveMonitoringControllerProvider.notifier)
                  .toggleDemoMode(!liveState.isDemoMode);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (liveState.isDemoMode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF25C9A0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'âš ï¸ DEMO / SIMULATED DATA MODE ACTIVE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          // STEP399D: Working Component 3 safety UI (no AI risk claim).
          _buildLiveSafetyCautions(liveState),
          const SizedBox(height: 12),
          // Header & Session Controls Card
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _trail?.name ?? 'Active Trail Session',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D2B30),
                          ),
                        ),
                      ),
                      Chip(
                        backgroundColor:
                            liveState.state == MonitoringState.monitoring
                            ? const Color(0xFF25C9A0).withValues(alpha: 0.2)
                            : Colors.orange.shade100,
                        label: Text(
                          liveState.state.name.toUpperCase(),
                          style: TextStyle(
                            color: liveState.state == MonitoringState.monitoring
                                ? const Color(0xFF086477)
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Elapsed Time:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        _formatElapsedTime(_elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF086477),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Watch Connection:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        liveState.isDemoMode
                            ? 'DEMO'
                            : (liveState.state == MonitoringState.monitoring
                                  ? 'Watch6 telemetry active'
                                  : 'Waiting / unavailable'),
                        style: const TextStyle(
                          color: Color(0xFF25C9A0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Data Source:',
                        style: TextStyle(color: Colors.grey),
                      ),
                      Text(
                        data.dataSource,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Live Sensor Panel
          const Text(
            'Live Sensor Telemetry',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2B30),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _buildSensorCard(
                'Heart Rate',
                _heartRateLabel(data, liveState),
                Icons.favorite,
                Colors.red,
              ),
              _buildSensorCard(
                'Step Count',
                _stepsLabel(data, liveState),
                Icons.directions_walk,
                const Color(0xFF25C9A0),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // STEP407C_PHONE_WEATHER_PANEL
          Builder(
            builder: (context) {
              final weather = ref
                  .read(liveMonitoringControllerProvider.notifier)
                  .component3LatestWeather;

              return Card(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cloud_outlined, color: Color(0xFF086477)),
                          SizedBox(width: 8),
                          Text(
                            'Phone Weather',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (weather == null)
                        const Text(
                          'Weather unavailable. Check phone location permission, location services and backend connection.',
                        )
                      else ...[
                        Text(
                          'Temperature: ${weather.temperatureCelsius.toStringAsFixed(1)} °C',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Humidity: ${weather.humidityPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Weather API estimate. Not a medical measurement.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // AI_SCREEN_INTEGRATION_V1: real profile inputs only (no defaults).
          const Text(
            'On-device Exertion Estimate',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2B30),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ai.age == null
                        ? 'Saved age: unavailable - complete Fitness Profile'
                        : 'Saved age: ${ai.age!.toStringAsFixed(0)} years',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _trainingYears,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Years of fitness training (actual)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _sleepHours,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Last night sleep (hours, actual)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _syncSafetyInputs();
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: ai.age == null
                        ? null
                        : () {
                            _aiController.configureInputs(
                              fitnessYears: double.tryParse(
                                _trainingYears.text.trim(),
                              ),
                              sleepingHours: double.tryParse(
                                _sleepHours.text.trim(),
                              ),
                            );
                          },
                    child: const Text('Apply AI Inputs'),
                  ),
                  const SizedBox(height: 8),
                  Text(ai.message),
                  if (showEstimate)
                    Text(
                      'Estimated Borg exertion: ${ai.estimatedBorg!.toStringAsFixed(2)} (6-20 scale)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF086477),
                      ),
                    ),
                  const SizedBox(height: 6),
                  const Text(
                    'Non-diagnostic model estimate. Not a medical risk percentage.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Four Risk Indicator Panels (Requirement 5)
          const Text(
            'Physiological Risk Indicators',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2B30),
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            children: [
              _buildRiskCard('Fatigue Risk', 'Model not connected'),
              _buildRiskCard('Physical Strain', 'Model not connected'),
              _buildRiskCard('Heat Stress', 'Model not connected'),
            ],
          ),
          const SizedBox(height: 24),

          // Live Recommendations Panel (Requirement 6)
          const Text(
            'Live Safety Recommendations',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D2B30),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showEstimate
                        ? 'On-device exertion estimate available'
                        : ai.message,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF086477),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    showEstimate
                        ? 'Adjust your pace to your comfort, take breaks as needed, and drink water regularly. If you feel unwell, stop and seek appropriate help.'
                        : 'No AI-based recommendation without fresh real Watch6 HR and complete profile inputs. General safety: pace yourself, rest when needed, and stay hydrated.',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Fatigue, physical-strain and heat-stress model estimates are unavailable until required inputs are verified. Dehydration-specific prediction is future work.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Session Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF086477)),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: () {
                    final notifier = ref.read(
                      liveMonitoringControllerProvider.notifier,
                    );
                    if (liveState.state == MonitoringState.paused) {
                      notifier.resumeMonitoring();
                    } else {
                      notifier.pauseMonitoring();
                    }
                  },
                  child: Text(
                    liveState.state == MonitoringState.paused
                        ? 'Resume Hike'
                        : 'Pause Hike',
                    style: const TextStyle(
                      color: Color(0xFF086477),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _isEndingHike ? null : _confirmEndHike,
                  child: _isEndingHike
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'End Hike',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D2B30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(String title, String statusText) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1D2B30),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
