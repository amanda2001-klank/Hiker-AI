enum Component3SafetyCategory { fatigue, physicalStrain, heatExposure }

class Component3SafetyTrigger {
  final Component3SafetyCategory category;
  final String title;
  final String recommendation;

  const Component3SafetyTrigger({
    required this.category,
    required this.title,
    required this.recommendation,
  });
}

class Component3SafetyInputs {
  final double? sleepHours;
  final Duration? hikeDuration;
  final double? liveHeartRateBpm;
  final double? restingHeartRateBpm;
  final double? temperatureC;
  final double? humidityPercent;
  final bool weatherVerified;

  const Component3SafetyInputs({
    this.sleepHours,
    this.hikeDuration,
    this.liveHeartRateBpm,
    this.restingHeartRateBpm,
    this.temperatureC,
    this.humidityPercent,
    this.weatherVerified = false,
  });
}

class Component3SafetyTriggerEngine {
  const Component3SafetyTriggerEngine();

  List<Component3SafetyTrigger> evaluate(Component3SafetyInputs input) {
    final result = <Component3SafetyTrigger>[];

    final sleep = input.sleepHours;
    final duration = input.hikeDuration;

    final validSleep =
        sleep != null && sleep.isFinite && sleep >= 0 && sleep <= 24;

    final validDuration = duration != null && !duration.isNegative;

    if ((validSleep && sleep < 6) ||
        (validDuration && duration.inSeconds >= 7200)) {
      result.add(
        const Component3SafetyTrigger(
          category: Component3SafetyCategory.fatigue,
          title: 'Fatigue-related caution',
          recommendation: 'Consider reducing effort and taking a rest break.',
        ),
      );
    }

    final hr = input.liveHeartRateBpm;
    final resting = input.restingHeartRateBpm;

    final validHr = hr != null && hr.isFinite && hr >= 30 && hr <= 240;

    final validResting =
        resting != null && resting.isFinite && resting >= 30 && resting <= 150;

    if (validHr && validResting && hr - resting >= 60) {
      result.add(
        const Component3SafetyTrigger(
          category: Component3SafetyCategory.physicalStrain,
          title: 'Physical-strain-related caution',
          recommendation:
              'Consider slowing down and checking perceived effort.',
        ),
      );
    }

    final temp = input.temperatureC;
    final humidity = input.humidityPercent;

    final validWeather =
        input.weatherVerified &&
        temp != null &&
        humidity != null &&
        temp.isFinite &&
        humidity.isFinite &&
        temp >= -50 &&
        temp <= 60 &&
        humidity >= 0 &&
        humidity <= 100;

    if (validWeather && ((temp >= 30 && humidity >= 70) || temp >= 35)) {
      result.add(
        const Component3SafetyTrigger(
          category: Component3SafetyCategory.heatExposure,
          title: 'Heat-exposure caution',
          recommendation:
              'Consider shade, pacing adjustments and a rest break.',
        ),
      );
    }

    return result;
  }
}
