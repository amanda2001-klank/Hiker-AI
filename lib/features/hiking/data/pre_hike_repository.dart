import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import 'trail_repository.dart';
import 'weather_repository.dart';

class PreHikeRecommendationModel {
  final List<String> recommendations;
  final List<String> specialNotes;
  final String completenessStatus; // "Personalized", "Partially Personalized", "General Guidance"
  final bool fromTrailRecommendation;

  PreHikeRecommendationModel({
    required this.recommendations,
    required this.specialNotes,
    required this.completenessStatus,
    required this.fromTrailRecommendation,
  });

  factory PreHikeRecommendationModel.fromJson(Map<String, dynamic> json) {
    var recs = json['recommendations'] ?? [];
    var notes = json['special_notes'] ?? [];

    List<String> parsedRecs = recs is List ? recs.map((e) => e.toString()).toList() : [];
    List<String> parsedNotes = notes is List ? notes.map((e) => e.toString()).toList() : [];

    return PreHikeRecommendationModel(
      recommendations: parsedRecs.isNotEmpty ? parsedRecs : [
        'Pack adequate water and electrolyte solutions based on hike duration.',
        'Wear moisture-wicking layers and sturdy hiking boots.',
        'Bring a fully charged power bank and offline trail map.'
      ],
      specialNotes: parsedNotes.isNotEmpty ? parsedNotes : [
        'Check weather updates 24 hours prior to departure.',
        'Inform a family member or emergency contact of your planned route.'
      ],
      completenessStatus: json['completeness_status'] as String? ?? 'General Guidance',
      fromTrailRecommendation: json['from_trail_recommendation'] as bool? ?? false,
    );
  }

  // Evidence-informed rule-based fitness personalization engine (ACSM hydration & RPE guidelines)
  static PreHikeRecommendationModel generatePersonalized({
    TrailModel? trail,
    double? fitnessScore,
    String? experienceLevel,
    WeatherForecastModel? weather,
  }) {
    final recs = <String>[];
    final notes = <String>[];

    final hasUser = fitnessScore != null && experienceLevel != null;
    final hasTrail = trail != null;
    final hasWeather = weather != null;

    String completeness = 'General Guidance';
    if (hasUser && hasTrail && hasWeather) {
      completeness = 'Personalized';
    } else if (hasUser || hasTrail || hasWeather) {
      completeness = 'Partially Personalized';
    }

    // 1. Pacing & Exertion (Rating of Perceived Exertion / RPE & conversational pace)
    final exp = experienceLevel ?? 'Unknown';
    final score = fitnessScore ?? 50.0;

    if (exp == 'Beginner' || score < 50.0) {
      recs.add('Pacing & Exertion [Level: Beginner]: Maintain a conversational pace (Rating of Perceived Exertion 3-4/10). Take 5-minute rest breaks every 30 minutes.');
    } else if (exp == 'Advanced' || score >= 75.0) {
      recs.add('Pacing & Exertion [Level: Advanced]: Maintain a steady, sustained cadence (RPE 5-6/10) with structured endurance fueling every 45 minutes.');
    } else {
      recs.add('Pacing & Exertion [Level: Intermediate]: Maintain a moderate, sustainable rhythm (RPE 4-5/10) with regular rest intervals every 45 minutes.');
    }

    // 2. Trail Demands (Distance & Elevation Rationale)
    final distance = trail?.distanceKm ?? 5.0;
    final elevation = trail?.elevationGainM ?? 300.0;
    final durationMins = trail?.estimatedDurationMins ?? 150;

    if (elevation > 500.0 || distance > 10.0) {
      recs.add('Terrain & Technique: Substantial elevation profile ($elevation m over $distance km). Use trekking poles to distribute load on descents and protect knee joints.');
      notes.add('Elevation Caution: Ascend at a controlled, even cadence to manage cardiovascular load on steep inclines.');
    } else {
      recs.add('Terrain & Technique: Moderate or gentle profile ($elevation m over $distance km). Focus on steady foot placement.');
    }

    // 3. Evidence-Informed Hydration (ACSM guidelines: ~0.4L to 0.8L per hour based on duration & environment)
    final durationHours = durationMins / 60.0;
    double baseHydrationRateLitersPerHour = 0.5; // ~500 ml/hr base

    if (hasWeather) {
      if (weather.temperatureCelsius > 28.0 || weather.humidityPercent > 75.0) {
        baseHydrationRateLitersPerHour = 0.75; // increased for heat/humidity sweat rate
        notes.add('Heat Stress Precaution: Ambient temp ${weather.temperatureCelsius}°C with ${weather.humidityPercent}% humidity increases sweat rate. Include electrolyte replacement beverages.');
      } else if (weather.temperatureCelsius < 15.0) {
        baseHydrationRateLitersPerHour = 0.4;
      }
    }

    final estimatedFluidLiters = (durationHours * baseHydrationRateLitersPerHour).clamp(0.5, 4.0);
    final roundedFluid = estimatedFluidLiters.toStringAsFixed(1);
    recs.add('Hydration Strategy: Based on estimated duration (${durationMins}m) and environmental conditions, target approximately $roundedFluid Liters of fluid intake distributed evenly throughout the hike (~${(baseHydrationRateLitersPerHour * 1000).toInt()} ml/hr). Avoid over-hydration.');

    // 4. Energy Preparation
    final estimatedCalories = (durationMins * 6.0).toInt(); // ~360 kcal/hr average hiking expenditure
    recs.add('Nutrition & Energy: Estimated energy expenditure is ~$estimatedCalories kcal for this duration. Pack easily digestible carbohydrate snacks (trail mix, energy bars) providing ~200-300 kcal per hour.');

    // 5. Data Completeness Notice
    notes.add('Recommendation Completeness: [$completeness]. ${completeness == 'Personalized' ? 'Tailored to your fitness score, experience, trail profile, and real weather.' : 'Some user or weather inputs were missing; guidance is generalized.'}');

    return PreHikeRecommendationModel(
      recommendations: recs,
      specialNotes: notes,
      completenessStatus: completeness,
      fromTrailRecommendation: true,
    );
  }
}

class PreHikeRepository {
  final ApiClient apiClient;

  PreHikeRepository(this.apiClient);

  Future<PreHikeRecommendationModel> getPreHikeRecommendations(
      String date, {
        TrailModel? trail,
        double? fitnessScore,
        String? experienceLevel,
        WeatherForecastModel? weather,
      }) async {
    return PreHikeRecommendationModel.generatePersonalized(
      trail: trail,
      fitnessScore: fitnessScore,
      experienceLevel: experienceLevel,
      weather: weather,
    );
  }
}

final preHikeRepositoryProvider = Provider<PreHikeRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PreHikeRepository(apiClient);
});
