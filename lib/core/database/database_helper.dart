import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static String? customDbPath;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(customDbPath ?? 'app_venture.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 7,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. users
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        backend_user_id TEXT UNIQUE,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        profile_image_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_users_backend_user_id ON users(backend_user_id)');

    // 2. fitness_profiles
    await db.execute('''
      CREATE TABLE fitness_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        full_name TEXT NOT NULL,
        age INTEGER NOT NULL,
        gender TEXT NOT NULL,
        height_cm REAL NOT NULL,
        weight_kg REAL NOT NULL,
        bmi REAL NOT NULL,
        medical_history TEXT,
        physical_limitations TEXT,
        fitness_notes TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 3. experience_assessments
    await db.execute('''
      CREATE TABLE experience_assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        q1_answer TEXT NOT NULL,
        q2_answer TEXT NOT NULL,
        q3_answer TEXT NOT NULL,
        q4_answer TEXT NOT NULL,
        calculated_score REAL NOT NULL,
        experience_level TEXT NOT NULL,
        assessed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 4. fitness_assessments
    await db.execute('''
      CREATE TABLE fitness_assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        dataset_reference TEXT,
        calculated_score REAL NOT NULL,
        fitness_level TEXT NOT NULL,
        assessed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 5. connected_devices
    await db.execute('''
      CREATE TABLE connected_devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        device_type TEXT NOT NULL,
        is_connected INTEGER NOT NULL,
        last_sync_time TEXT,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 6. daily_activities
    await db.execute('''
      CREATE TABLE daily_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        steps INTEGER NOT NULL,
        calories_burned REAL NOT NULL,
        distance_km REAL NOT NULL,
        avg_heart_rate REAL NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // 7. trails
    await db.execute('''
      CREATE TABLE trails (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        difficulty TEXT NOT NULL,
        distance_km REAL NOT NULL,
        elevation_gain_m REAL NOT NULL,
        estimated_duration_mins INTEGER NOT NULL,
        route_geometry TEXT,
        image_url TEXT,
        location TEXT
      )
    ''');

    // 8. hiking_sessions
    await db.execute('''
      CREATE TABLE hiking_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        trail_id INTEGER,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT NOT NULL,
        current_heart_rate REAL,
        distance_covered_km REAL,
        calories_burned REAL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (trail_id) REFERENCES trails (id) ON DELETE SET NULL
      )
    ''');

    // 9. hiking_history
    await db.execute('''
      CREATE TABLE hiking_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        hiking_session_id INTEGER NOT NULL,
        trail_name TEXT,
        hiking_date TEXT,
        distance_km REAL,
        duration_minutes INTEGER,
        calories_burned REAL,
        status TEXT,
        summary_notes TEXT,
        max_heart_rate REAL,
        max_elevation_m REAL,
        completed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (hiking_session_id) REFERENCES hiking_sessions (id) ON DELETE CASCADE
      )
    ''');

    // 10. weather_cache
    await db.execute('''
      CREATE TABLE weather_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        location_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        temperature_celsius REAL NOT NULL,
        weather_condition TEXT NOT NULL,
        humidity_percent INTEGER NOT NULL,
        cached_at TEXT NOT NULL,
        rain_probability REAL,
        wind_speed REAL,
        provider_name TEXT,
        forecast_date TEXT
      )
    ''');

    // 11. seven_day_activity_assessments (Version 7 Additive Table)
    await db.execute('''
      CREATE TABLE seven_day_activity_assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        assessment_start_date TEXT NOT NULL,
        assessment_end_date TEXT NOT NULL,
        calculated_score REAL NOT NULL,
        component_a REAL NOT NULL,
        component_b REAL NOT NULL,
        component_c REAL NOT NULL,
        component_e REAL NOT NULL,
        formula_version TEXT NOT NULL,
        data_source TEXT NOT NULL,
        data_completeness TEXT NOT NULL,
        assessed_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      if (oldVersion < 3) {
        var userCols = await txn.rawQuery("PRAGMA table_info(users)");
        bool hasUsername = userCols.any((c) => c['name'] == 'username');
        if (!hasUsername) {
          await txn.execute("ALTER TABLE users ADD COLUMN username TEXT NOT NULL DEFAULT 'User'");
        }
        bool hasProfileImage = userCols.any((c) => c['name'] == 'profile_image_url');
        if (!hasProfileImage) {
          await txn.execute("ALTER TABLE users ADD COLUMN profile_image_url TEXT");
        }
      }

      if (oldVersion < 4) {
        var trailCols = await txn.rawQuery("PRAGMA table_info(trails)");
        if (!trailCols.any((c) => c['name'] == 'image_url')) {
          await txn.execute("ALTER TABLE trails ADD COLUMN image_url TEXT");
        }
        if (!trailCols.any((c) => c['name'] == 'location')) {
          await txn.execute("ALTER TABLE trails ADD COLUMN location TEXT");
        }

        var weatherCols = await txn.rawQuery("PRAGMA table_info(weather_cache)");
        if (!weatherCols.any((c) => c['name'] == 'rain_probability')) {
          await txn.execute("ALTER TABLE weather_cache ADD COLUMN rain_probability REAL");
        }
        if (!weatherCols.any((c) => c['name'] == 'wind_speed')) {
          await txn.execute("ALTER TABLE weather_cache ADD COLUMN wind_speed REAL");
        }
        if (!weatherCols.any((c) => c['name'] == 'provider_name')) {
          await txn.execute("ALTER TABLE weather_cache ADD COLUMN provider_name TEXT");
        }
        if (!weatherCols.any((c) => c['name'] == 'forecast_date')) {
          await txn.execute("ALTER TABLE weather_cache ADD COLUMN forecast_date TEXT");
        }
      }

      if (oldVersion < 5) {
        var histCols = await txn.rawQuery("PRAGMA table_info(hiking_history)");
        if (!histCols.any((c) => c['name'] == 'trail_name')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN trail_name TEXT");
        }
        if (!histCols.any((c) => c['name'] == 'hiking_date')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN hiking_date TEXT");
        }
        if (!histCols.any((c) => c['name'] == 'distance_km')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN distance_km REAL");
        }
        if (!histCols.any((c) => c['name'] == 'duration_minutes')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN duration_minutes INTEGER");
        }
        if (!histCols.any((c) => c['name'] == 'calories_burned')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN calories_burned REAL");
        }
        if (!histCols.any((c) => c['name'] == 'status')) {
          await txn.execute("ALTER TABLE hiking_history ADD COLUMN status TEXT");
        }
      }

      if (oldVersion < 6) {
        var userCols = await txn.rawQuery("PRAGMA table_info(users)");
        bool hasBackendUserId = userCols.any((c) => c['name'] == 'backend_user_id');
        if (!hasBackendUserId) {
          await txn.execute("ALTER TABLE users ADD COLUMN backend_user_id TEXT");
          await txn.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_users_backend_user_id ON users(backend_user_id)");
        }
      }

      if (oldVersion < 7) {
        await txn.execute('''
          CREATE TABLE IF NOT EXISTS seven_day_activity_assessments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            assessment_start_date TEXT NOT NULL,
            assessment_end_date TEXT NOT NULL,
            calculated_score REAL NOT NULL,
            component_a REAL NOT NULL,
            component_b REAL NOT NULL,
            component_c REAL NOT NULL,
            component_e REAL NOT NULL,
            formula_version TEXT NOT NULL,
            data_source TEXT NOT NULL,
            data_completeness TEXT NOT NULL,
            assessed_at TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
      }
    });
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

final databaseHelperProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);
