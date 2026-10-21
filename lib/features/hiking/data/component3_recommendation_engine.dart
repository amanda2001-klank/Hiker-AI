enum Component3GuidanceLevel {
  information,
  caution,
}

class Component3Recommendation {
  final Component3GuidanceLevel level;
  final String title;
  final String message;

  const Component3Recommendation({
    required this.level,
    required this.title,
    required this.message,
  });
}

class Component3RecommendationEngine {
  const Component3RecommendationEngine();

  List<Component3Recommendation> evaluate({
    required bool monitoringActive,
    required bool demoMode,
    required bool heartRateAvailable,
    required bool heartRateFresh,
    required bool gpsAvailable,
    required bool weatherVerified,
    required bool modelInputsVerified,
  }) {
    final recommendations = <Component3Recommendation>[];

    if (demoMode) {
      return const [
        Component3Recommendation(
          level: Component3GuidanceLevel.information,
          title: 'Simulation Mode',
          message: 'Demo measurements cannot be used for real risk estimation.',
        ),
      ];
    }

    if (!monitoringActive) {
      return const [
        Component3Recommendation(
          level: Component3GuidanceLevel.information,
          title: 'Monitoring Inactive',
          message: 'Start monitoring to collect fresh wearable measurements.',
        ),
      ];
    }

    if (!heartRateAvailable) {
      recommendations.add(const Component3Recommendation(
        level: Component3GuidanceLevel.caution,
        title: 'Heart Rate Unavailable',
        message: 'Check watch fit and sensor contact. Wait for a fresh reading.',
      ));
    } else if (!heartRateFresh) {
      recommendations.add(const Component3Recommendation(
        level: Component3GuidanceLevel.caution,
        title: 'Heart Rate Stale',
        message: 'Wait for updated Watch6 heart-rate measurements.',
      ));
    }

    if (!gpsAvailable) {
      recommendations.add(const Component3Recommendation(
        level: Component3GuidanceLevel.information,
        title: 'GPS Unavailable',
        message: 'GPS-based pace, slope and route information is unavailable.',
      ));
    }

    if (!weatherVerified) {
      recommendations.add(const Component3Recommendation(
        level: Component3GuidanceLevel.information,
        title: 'Weather Unverified',
        message: 'Heat exposure cannot currently be estimated reliably. '
            'Check local weather conditions and seek shade if needed.',
      ));
    }

    if (!modelInputsVerified) {
      recommendations.add(const Component3Recommendation(
        level: Component3GuidanceLevel.caution,
        title: 'AI Risk Estimates Unavailable',
        message: 'Fatigue, Physical Strain and Heat Stress estimates are '
            'withheld until the required model inputs are verified. '
            'Rest when needed, pace yourself and follow general hiking '
            'safety precautions.',
      ));
    }

    return recommendations;
  }
}