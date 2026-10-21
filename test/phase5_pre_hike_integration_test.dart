import 'package:flutter_test/flutter_test.dart';
import 'package:app_venture_flutter/features/hiking/data/pre_hike_repository.dart';
import 'package:app_venture_flutter/features/hiking/data/trail_repository.dart';
import 'package:app_venture_flutter/features/hiking/data/weather_repository.dart';

void main() {
  group('Phase 5 Pre-Hike Fitness Personalization Integration Tests', () {
    test('1. Recommendations become Personalized when valid 7-day score, experience, and weather are present', () {
      final trail = TrailModel(
        name: 'Adam\'s Peak',
        difficulty: 'Hard',
        distanceKm: 10.5,
        elevationGainM: 1050.0,
        estimatedDurationMins: 360,
        latitude: 6.8096,
        longitude: 80.4994,
      );

      final weather = WeatherForecastModel(
        locationName: 'Maskeliya',
        temperatureCelsius: 24.0,
        weatherCondition: 'Cloudy',
        humidityPercent: 82,
        cachedAt: DateTime.now().toIso8601String(),
        rainProbability: 20.0,
        windSpeed: 12.0,
        providerName: 'OpenWeather',
        forecastDate: '2026-10-15',
        latitude: 6.8096,
        longitude: 80.4994,
      );

      final model = PreHikeRecommendationModel.generatePersonalized(
        trail: trail,
        fitnessScore: 82.0,
        experienceLevel: 'Advanced',
        weather: weather,
      );

      expect(model.completenessStatus, 'Personalized');
      expect(model.recommendations.any((r) => r.contains('Advanced')), true);
      expect(model.recommendations.any((r) => r.contains('Hydration Strategy')), true);
    });

    test('2. Recommendations revert to General Guidance when fitness score and weather are missing', () {
      final model = PreHikeRecommendationModel.generatePersonalized(
        trail: null,
        fitnessScore: null,
        experienceLevel: null,
        weather: null,
      );

      expect(model.completenessStatus, 'General Guidance');
    });

    test('3. Weather heat stress precautions adjust hydration targets', () {
      final trail = TrailModel(
        name: 'Ella Rock',
        difficulty: 'Moderate',
        distanceKm: 7.8,
        elevationGainM: 560.0,
        estimatedDurationMins: 180,
        latitude: 6.8667,
        longitude: 81.0466,
      );

      final hotWeather = WeatherForecastModel(
        locationName: 'Ella',
        temperatureCelsius: 32.0,
        weatherCondition: 'Sunny',
        humidityPercent: 85,
        cachedAt: DateTime.now().toIso8601String(),
        rainProbability: 5.0,
        windSpeed: 8.0,
        providerName: 'OpenWeather',
        forecastDate: '2026-10-15',
        latitude: 6.8667,
        longitude: 81.0466,
      );

      final model = PreHikeRecommendationModel.generatePersonalized(
        trail: trail,
        fitnessScore: 65.0,
        experienceLevel: 'Intermediate',
        weather: hotWeather,
      );

      expect(model.specialNotes.any((n) => n.contains('Heat Stress Precaution')), true);
    });
  });
}
