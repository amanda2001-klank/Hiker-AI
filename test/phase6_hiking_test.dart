import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/core/api/api_client.dart';
import 'package:app_venture_flutter/features/hiking/data/trail_repository.dart';
import 'package:app_venture_flutter/features/hiking/data/weather_repository.dart';
import 'package:app_venture_flutter/features/hiking/data/pre_hike_repository.dart';
import 'package:app_venture_flutter/features/hiking/data/hiking_session_repository.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_phase6_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('Trail API JSON Parsing Test', () {
    final json = {
      'title': 'Alpine Ridge Trail',
      'image_url': 'https://example.com/trail.jpg',
      'distance': '10.5 km',
      'level': 'Hard',
      'time': '3h 30m',
      'location': 'Sierra Nevada',
    };

    final trail = TrailModel.fromApiJson(json);
    expect(trail.name, equals('Alpine Ridge Trail'));
    expect(trail.distanceKm, equals(10.5));
    expect(trail.difficulty, equals('Hard'));
    expect(trail.imageUrl, equals('https://example.com/trail.jpg'));
    expect(trail.location, equals('Sierra Nevada'));
  });

  test('Weather Forecast Horizon Validation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final weatherRepo = WeatherRepository(ApiClient(), dbHelper);

    // Target date 15 days in future should throw exception (horizon is 10 days)
    final futureDate = DateTime.now().add(const Duration(days: 15));
    final dateStr = '${futureDate.year}-${futureDate.month.toString().padLeft(2, '0')}-${futureDate.day.toString().padLeft(2, '0')}';

    expect(
          () async => await weatherRepo.getWeatherForecast(
        locationName: 'Test Peak',
        latitude: 35.0,
        longitude: -118.0,
        targetDate: dateStr,
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('Pre-Hike Recommendation JSON Parsing Test', () {
    final json = {
      'recommendations': ['Bring extra socks', 'Pack trekking poles'],
      'special_notes': ['High winds expected at summit'],
      'from_trail_recommendation': true,
    };

    final model = PreHikeRecommendationModel.fromJson(json);
    expect(model.recommendations.length, equals(2));
    expect(model.specialNotes.first, equals('High winds expected at summit'));
    expect(model.fromTrailRecommendation, isTrue);
  });

  test('Hiking Session Creation and Duplicate Prevention Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);
    final sessionRepo = HikingSessionRepository(dbHelper);

    final userId = await profileRepo.getOrCreateUserIdByEmail('hiker@venture.com', 'Hiker Pro');

    final db = await dbHelper.database;
    await db.insert('trails', {
      'id': 1,
      'name': 'Test Trail',
      'difficulty': 'Easy',
      'distance_km': 5.0,
      'elevation_gain_m': 200.0,
      'estimated_duration_mins': 90,
    });

    // Start first session
    final sessionId1 = await sessionRepo.startHikeSession(userId: userId, trailId: 1);
    expect(sessionId1, isNotNull);

    // Attempt starting second active session (should return existing session ID to prevent duplicates)
    final sessionId2 = await sessionRepo.startHikeSession(userId: userId, trailId: 1);
    expect(sessionId2, equals(sessionId1));

    // Verify active session retrieval
    final activeSession = await sessionRepo.getActiveSession(userId);
    expect(activeSession, isNotNull);
    expect(activeSession!.id, equals(sessionId1));
    expect(activeSession.trailId, equals(1));
    expect(activeSession.status, equals('active'));

    // End session
    await sessionRepo.endHikeSession(sessionId1, totalDistance: 8.5, calories: 750.0);
    final activeAfterEnd = await sessionRepo.getActiveSession(userId);
    expect(activeAfterEnd, isNull);
  });
}
