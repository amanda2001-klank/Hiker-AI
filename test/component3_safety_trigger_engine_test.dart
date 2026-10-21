import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/hiking/data/component3_safety_trigger_engine.dart';

void main() {
  const engine = Component3SafetyTriggerEngine();

  test('No verified context does not generate cautions', () {
    final triggers = engine.evaluate(const Component3SafetyInputs());
    expect(triggers, isEmpty);
  });

  test('Short sleep generates fatigue-related caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(sleepHours: 5),
    );
    expect(
      triggers.any((t) => t.category == Component3SafetyCategory.fatigue),
      isTrue,
    );
  });

  test('Prolonged activity generates fatigue-related caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(hikeDuration: Duration(hours: 2)),
    );
    expect(
      triggers.any((t) => t.category == Component3SafetyCategory.fatigue),
      isTrue,
    );
  });

  test('Measured HR rise generates physical strain caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(
        liveHeartRateBpm: 140,
        restingHeartRateBpm: 75,
      ),
    );
    expect(
      triggers.any(
        (t) => t.category == Component3SafetyCategory.physicalStrain,
      ),
      isTrue,
    );
  });

  test('Missing resting HR prevents physical strain caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(liveHeartRateBpm: 140),
    );
    expect(
      triggers.any(
        (t) => t.category == Component3SafetyCategory.physicalStrain,
      ),
      isFalse,
    );
  });

  test('Verified hot humid weather generates heat caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(
        temperatureC: 32,
        humidityPercent: 75,
        weatherVerified: true,
      ),
    );
    expect(
      triggers.any((t) => t.category == Component3SafetyCategory.heatExposure),
      isTrue,
    );
  });

  test('Unverified weather never generates heat caution', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(
        temperatureC: 38,
        humidityPercent: 85,
        weatherVerified: false,
      ),
    );
    expect(
      triggers.any((t) => t.category == Component3SafetyCategory.heatExposure),
      isFalse,
    );
  });

  test('All three categories may trigger independently', () {
    final triggers = engine.evaluate(
      const Component3SafetyInputs(
        sleepHours: 5,
        liveHeartRateBpm: 145,
        restingHeartRateBpm: 75,
        temperatureC: 32,
        humidityPercent: 80,
        weatherVerified: true,
      ),
    );
    expect(triggers.map((t) => t.category).toSet(), {
      Component3SafetyCategory.fatigue,
      Component3SafetyCategory.physicalStrain,
      Component3SafetyCategory.heatExposure,
    });
  });
}
