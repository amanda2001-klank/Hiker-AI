import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/database/database_helper.dart';

class TrailModel {
  final int? id;
  final String name;
  final String? description;
  final String difficulty;
  final double distanceKm;
  final double elevationGainM;
  final int estimatedDurationMins;
  final String? imageUrl;
  final String? location;
  final double latitude;
  final double longitude;
  final bool isDemo;

  TrailModel({
    this.id,
    required this.name,
    this.description,
    required this.difficulty,
    required this.distanceKm,
    required this.elevationGainM,
    required this.estimatedDurationMins,
    this.imageUrl,
    this.location,
    this.latitude = 6.9271,
    this.longitude = 79.8612,
    this.isDemo = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty,
      'distance_km': distanceKm,
      'elevation_gain_m': elevationGainM,
      'estimated_duration_mins': estimatedDurationMins,
      'image_url': imageUrl,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory TrailModel.fromMap(Map<String, dynamic> map) {
    return TrailModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Unknown Trail',
      description: map['description'] as String?,
      difficulty: map['difficulty'] as String? ?? 'Moderate',
      distanceKm: map['distance_km'] != null ? (map['distance_km'] as num).toDouble() : 5.0,
      elevationGainM: map['elevation_gain_m'] != null ? (map['elevation_gain_m'] as num).toDouble() : 300.0,
      estimatedDurationMins: map['estimated_duration_mins'] as int? ?? 120,
      imageUrl: map['image_url'] as String?,
      location: map['location'] as String?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : 6.9271,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : 79.8612,
      isDemo: map['is_demo'] == 1 || map['is_demo'] == true,
    );
  }

  factory TrailModel.fromApiJson(Map<String, dynamic> json) {
    final distanceStr = json['distance']?.toString() ?? '5.0 km';
    final distanceVal = double.tryParse(distanceStr.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 5.0;

    return TrailModel(
      name: json['title'] as String? ?? json['name'] as String? ?? 'Recommended Trail',
      description: json['description'] as String? ?? 'Scenic hiking trail.',
      difficulty: json['level'] as String? ?? json['difficulty'] as String? ?? 'Moderate',
      distanceKm: distanceVal,
      elevationGainM: (json['elevation_gain_m'] as num?)?.toDouble() ?? 350.0,
      estimatedDurationMins: json['estimated_duration_mins'] as int? ?? 150,
      imageUrl: json['image_url'] as String?,
      location: json['location'] as String? ?? 'Mountain Range',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 6.8096,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.4994,
      isDemo: false,
    );
  }
}

class TrailRepository {
  final ApiClient apiClient;
  final DatabaseHelper databaseHelper;

  TrailRepository(this.apiClient, this.databaseHelper);

  Future<List<TrailModel>> getRecommendedTrails() async {
    // PHASE 2 ONLY: Use existing demo trails for navigation testing.
    // Restore the backup to re-enable API/SQLite recommendations.
    // Representative Sri Lankan Hiking Trails Dataset (Demo / Dummy Integration)
    return [
      TrailModel(
        name: "Adam's Peak (Sri Pada) (DEMO)",
        description: 'Iconic pilgrimage peak in the Central Highlands offering breathtaking sunrise views across mountain ranges.',
        difficulty: 'Hard',
        distanceKm: 10.5,
        elevationGainM: 1050.0,
        estimatedDurationMins: 360,
        location: 'Central Highlands, Maskeliya',
        latitude: 6.8096,
        longitude: 80.4994,
        imageUrl: 'https://images.unsplash.com/photo-1551632811-561732d1e306',
        isDemo: true,
      ),
      TrailModel(
        name: 'Ella Rock Trail (DEMO)',
        description: 'Scenic ridge trail passing through lush tea plantations and eucalyptus forests with panoramic valley vistas.',
        difficulty: 'Moderate',
        distanceKm: 7.8,
        elevationGainM: 560.0,
        estimatedDurationMins: 180,
        location: 'Ella, Uva Province',
        latitude: 6.8667,
        longitude: 81.0466,
        imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
        isDemo: true,
      ),
      TrailModel(
        name: "Horton Plains – World's End (DEMO)",
        description: 'High-altitude plateau walk featuring a sheer 4,000 ft drop cliff view and cascading Baker’s Falls.',
        difficulty: 'Easy',
        distanceKm: 9.7,
        elevationGainM: 162.0,
        estimatedDurationMins: 210,
        location: 'Nuwara Eliya District',
        latitude: 6.8014,
        longitude: 80.8037,
        imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
        isDemo: true,
      ),
      TrailModel(
        name: 'Knuckles – Dothalugala Trail (DEMO)',
        description: 'Biodiverse cloud forest trek in the misty Knuckles mountain range with rich endemic flora and fauna.',
        difficulty: 'Moderate',
        distanceKm: 7.2,
        elevationGainM: 380.0,
        estimatedDurationMins: 250,
        location: 'Knuckles Conservation Forest',
        latitude: 7.3672,
        longitude: 80.8756,
        imageUrl: 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05',
        isDemo: true,
      ),
      TrailModel(
        name: 'Pidurutalagala Trail (DEMO)',
        description: 'Serene forest walk on Sri Lanka’s highest peak offering tranquil highland weather and rich pine scents.',
        difficulty: 'Easy',
        distanceKm: 6.0,
        elevationGainM: 320.0,
        estimatedDurationMins: 150,
        location: 'Nuwara Eliya',
        latitude: 7.0014,
        longitude: 80.7853,
        imageUrl: 'https://images.unsplash.com/photo-1519681393784-d120267933ba',
        isDemo: true,
      ),
      TrailModel(
        name: 'Hantana Mountain Range (DEMO)',
        description: 'Rolling grassy hills overlooking Kandy valley, popular for sunset treks and panoramic training hikes.',
        difficulty: 'Moderate',
        distanceKm: 8.2,
        elevationGainM: 510.0,
        estimatedDurationMins: 200,
        location: 'Kandy',
        latitude: 7.2731,
        longitude: 80.6356,
        imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
        isDemo: true,
      ),
      TrailModel(
        name: 'Kirigalpotta Peak Trail (DEMO)',
        description: 'Challenging backcountry wilderness trek to Sri Lanka’s second-highest peak traversing pristine grasslands.',
        difficulty: 'Hard',
        distanceKm: 14.0,
        elevationGainM: 620.0,
        estimatedDurationMins: 330,
        location: 'Horton Plains National Park',
        latitude: 6.8083,
        longitude: 80.7678,
        imageUrl: 'https://images.unsplash.com/photo-1426604966848-d7adac902bff',
        isDemo: true,
      ),
      TrailModel(
        name: 'Riverston Peak Gap (DEMO)',
        description: 'Mini World’s End precipice walk across windy gap ridges with dramatic escarpment drop-offs.',
        difficulty: 'Easy',
        distanceKm: 5.5,
        elevationGainM: 290.0,
        estimatedDurationMins: 120,
        location: 'Matale District',
        latitude: 7.5456,
        longitude: 80.7389,
        imageUrl: 'https://images.unsplash.com/photo-1510784722466-f2aa9c52fd69',
        isDemo: true,
      ),
    ];
  }
}

final trailRepositoryProvider = Provider<TrailRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  return TrailRepository(apiClient, dbHelper);
});
