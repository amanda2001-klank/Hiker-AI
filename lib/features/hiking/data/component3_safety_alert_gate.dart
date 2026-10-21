import 'component3_safety_trigger_engine.dart';

class Component3SafetyAlertGate {
  static const persistence = Duration(seconds: 45);
  static const cooldown = Duration(minutes: 5);

  final Map<Component3SafetyCategory, DateTime> _issueSince = {};
  final Map<Component3SafetyCategory, DateTime> _lastSent = {};

  // STEP393E4B_DELIVERY_RECOVERY
  // Release a failed delivery reservation only if it still matches
  // the original attempt, preventing older failures from clearing
  // a more recent notification cooldown.
  void releaseFailedDelivery(
    Component3SafetyCategory category,
    DateTime attemptedAt,
  ) {
    if (_lastSent[category] == attemptedAt) {
      _lastSent.remove(category);
    }
  }

  void resetSession() {
    _issueSince.clear();
    _lastSent.clear();
  }

  List<Component3SafetyCategory> evaluate({
    required DateTime now,
    required bool monitoringActive,
    required bool guidanceSessionReady,
    required Iterable<Component3SafetyCategory> activeCategories,
  }) {
    if (!monitoringActive || !guidanceSessionReady) {
      _issueSince.clear();
      return const [];
    }

    final active = activeCategories.toSet();

    for (final category in Component3SafetyCategory.values) {
      if (!active.contains(category)) {
        _issueSince.remove(category);
      }
    }

    final ready = <Component3SafetyCategory>[];

    for (final category in active) {
      final since = _issueSince.putIfAbsent(category, () => now);
      final age = now.difference(since);

      if (age.isNegative || age < persistence) {
        if (age.isNegative) {
          _issueSince[category] = now;
        }
        continue;
      }

      final previous = _lastSent[category];

      if (previous != null) {
        final elapsed = now.difference(previous);
        if (elapsed.isNegative || elapsed < cooldown) {
          continue;
        }
      }

      _lastSent[category] = now;
      ready.add(category);
    }

    return ready;
  }
}
