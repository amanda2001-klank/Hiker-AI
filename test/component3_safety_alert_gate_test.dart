import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/hiking/data/component3_safety_alert_gate.dart';
import 'package:app_venture_flutter/features/hiking/data/component3_safety_trigger_engine.dart';

void main() {
  final start = DateTime.utc(2026, 10, 21, 10);
  const fatigue = Component3SafetyCategory.fatigue;
  const heat = Component3SafetyCategory.heatExposure;

  List<Component3SafetyCategory> check(
    Component3SafetyAlertGate gate,
    DateTime now, {
    bool active = true,
    bool ready = true,
    List<Component3SafetyCategory> categories = const [fatigue],
  }) => gate.evaluate(
    now: now,
    monitoringActive: active,
    guidanceSessionReady: ready,
    activeCategories: categories,
  );

  test('No alert before 45 seconds persistence', () {
    final gate = Component3SafetyAlertGate();
    expect(check(gate, start), isEmpty);
    expect(check(gate, start.add(const Duration(seconds: 44))), isEmpty);
    expect(check(gate, start.add(const Duration(seconds: 45))), [fatigue]);
  });

  test('Same category suppressed during five-minute cooldown', () {
    final gate = Component3SafetyAlertGate();
    check(gate, start);
    final first = start.add(const Duration(seconds: 45));
    expect(check(gate, first), [fatigue]);
    expect(check(gate, first.add(const Duration(minutes: 4))), isEmpty);
    expect(check(gate, first.add(const Duration(minutes: 5))), [fatigue]);
  });

  test('Inactive session cannot generate alerts', () {
    final gate = Component3SafetyAlertGate();
    expect(check(gate, start, active: false), isEmpty);
    expect(
      check(gate, start.add(const Duration(minutes: 1)), ready: false),
      isEmpty,
    );
    expect(check(gate, start.add(const Duration(minutes: 2))), isEmpty);
  });

  test('Condition disappearing resets persistence', () {
    final gate = Component3SafetyAlertGate();
    check(gate, start);
    check(gate, start.add(const Duration(seconds: 20)), categories: []);
    final resumed = start.add(const Duration(seconds: 30));
    expect(check(gate, resumed), isEmpty);
    expect(check(gate, resumed.add(const Duration(seconds: 45))), [fatigue]);
  });

  test('Different categories are tracked independently', () {
    final gate = Component3SafetyAlertGate();
    check(gate, start, categories: [fatigue, heat]);
    expect(
      check(
        gate,
        start.add(const Duration(seconds: 45)),
        categories: [fatigue, heat],
      ),
      containsAll([fatigue, heat]),
    );
  });

  test('Failed delivery reservation can be released safely', () {
    final gate = Component3SafetyAlertGate();
    check(gate, start);
    final attempt = start.add(const Duration(seconds: 45));
    expect(check(gate, attempt), [fatigue]);
    gate.releaseFailedDelivery(fatigue, attempt);
    expect(check(gate, attempt.add(const Duration(seconds: 1))), [fatigue]);
  });
}
