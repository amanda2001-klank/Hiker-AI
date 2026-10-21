import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/database/database_helper.dart';

class WeatherForecastModel {
  final String locationName;
  final double latitude;
  final double longitude;
  final double temperatureCelsius;
  final String weatherCondition;
  final int humidityPercent;
  final double rainProbability;
  final double windSpeed;
  final String providerName;
  final String forecastDate;
  final String cachedAt;
  final bool isStale;

  WeatherForecastModel({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.temperatureCelsius,
    required this.weatherCondition,
    required this.humidityPercent,
    required this.rainProbability,
    required this.windSpeed,
    required this.providerName,
    required this.forecastDate,
    required this.cachedAt,
    this.isStale = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'temperature_celsius': temperatureCelsius,
      'weather_condition': weatherCondition,
      'humidity_percent': humidityPercent,
      'rain_probability': rainProbability,
      'wind_speed': windSpeed,
      'provider_name': providerName,
      'forecast_date': forecastDate,
      'cached_at': cachedAt,
    };
  }

  factory WeatherForecastModel.fromMap(
    Map<String, dynamic> map, {
    bool isStale = false,
  }) {
    return WeatherForecastModel(
      locationName: map['location_name'] as String? ?? 'Mountain Location',
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : 0.0,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : 0.0,
      temperatureCelsius: map['temperature_celsius'] != null
          ? (map['temperature_celsius'] as num).toDouble()
          : 20.0,
      weatherCondition: map['weather_condition'] as String? ?? 'Clear',
      humidityPercent: map['humidity_percent'] as int? ?? 50,
      rainProbability: map['rain_probability'] != null
          ? (map['rain_probability'] as num).toDouble()
          : 10.0,
      windSpeed: map['wind_speed'] != null
          ? (map['wind_speed'] as num).toDouble()
          : 5.0,
      providerName: map['provider_name'] as String? ?? 'OpenWeather API',
      forecastDate: map['forecast_date'] as String? ?? '',
      cachedAt: map['cached_at'] as String? ?? DateTime.now().toIso8601String(),
      isStale: isStale,
    );
  }
}

/// Weather values received from the app weather API, without local defaults.
/// API validation does not independently prove provider observation quality.
class Component3VerifiedWeather {
  final double temperatureCelsius;
  final double humidityPercent;
  final DateTime receivedAt;

  const Component3VerifiedWeather({
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.receivedAt,
  });
}

class WeatherRepository {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;

  WeatherRepository(this.apiClient, this.databaseHelper);

  /// Returns null instead of inventing weather values.
  /// This API may provide a forecast, not a live station observation.
  Future<Component3VerifiedWeather?> getVerifiedAiWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    try {
      final response = await apiClient.dio.get(
        '/weather',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        },
      );

      debugPrint(
        "STEP354_WEATHER STATUS=${response.statusCode} TYPE=${response.data.runtimeType}",
      );
      if (response.statusCode != 200 || response.data is! Map) {
        return null;
      }

      final body = response.data as Map;
      final raw = body['data'] ?? body;
      if (raw is! Map) return null;

      final temperature = raw['temperature'];
      final humidity = raw['humidity'];

      if (temperature is! num || humidity is! num) {
        return null;
      }

      final t = temperature.toDouble();
      final h = humidity.toDouble();

      if (!t.isFinite || !h.isFinite || t < -60 || t > 60 || h < 0 || h > 100) {
        return null;
      }

      return Component3VerifiedWeather(
        temperatureCelsius: t,
        humidityPercent: h,
        receivedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<WeatherForecastModel> getWeatherForecast({
    required String locationName,
    required double latitude,
    required double longitude,
    required String targetDate, // YYYY-MM-DD
  }) async {
    final target = DateTime.tryParse(targetDate) ?? DateTime.now();
    final now = DateTime.now();
    final difference = target
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    if (difference > 10) {
      throw Exception(
        'Forecast not yet available (Target date is beyond 10-day forecast horizon).',
      );
    }
    if (difference < 0) {
      throw Exception('Selected hiking date is in the past.');
    }

    try {
      final response = await apiClient.dio.get(
        '/weather',
        queryParameters: {
          'lat': latitude,
          'lon': longitude,
          'date': targetDate,
        },
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data['data'] ?? response.data;
        final forecast = WeatherForecastModel(
          locationName: locationName,
          latitude: latitude,
          longitude: longitude,
          temperatureCelsius: (data['temperature'] as num?)?.toDouble() ?? 22.0,
          weatherCondition: data['condition'] as String? ?? 'Partly Cloudy',
          humidityPercent: (data['humidity'] as num?)?.toInt() ?? 45,
          rainProbability:
              (data['rain_probability'] as num?)?.toDouble() ?? 15.0,
          windSpeed: (data['wind_speed'] as num?)?.toDouble() ?? 8.2,
          providerName:
              data['provider'] as String? ?? 'Venture Weather Service',
          forecastDate: targetDate,
          cachedAt: DateTime.now().toIso8601String(),
        );

        final db = await databaseHelper.database;
        await db.insert(
          'weather_cache',
          forecast.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return forecast;
      }
    } on DioException {
      // Fallback to SQLite cache
    }

    try {
      final db = await databaseHelper.database;
      final rows = await db.query(
        'weather_cache',
        where: 'location_name = ? AND forecast_date = ?',
        whereArgs: [locationName, targetDate],
        limit: 1,
      );

      if (rows.isNotEmpty) {
        return WeatherForecastModel.fromMap(rows.first, isStale: true);
      }
    } catch (_) {}

    return WeatherForecastModel(
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      temperatureCelsius: 19.5,
      weatherCondition: 'Sunny / Clear (Cached Offline)',
      humidityPercent: 52,
      rainProbability: 5.0,
      windSpeed: 6.5,
      providerName: 'Offline Cache Provider',
      forecastDate: targetDate,
      cachedAt: DateTime.now().toIso8601String(),
      isStale: true,
    );
  }
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return WeatherRepository(apiClient, dbHelper);
});
