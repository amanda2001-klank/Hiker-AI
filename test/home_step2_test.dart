import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_venture_flutter/core/database/database_helper.dart';
import 'package:app_venture_flutter/features/fitness/data/fitness_profile_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    DatabaseHelper.customDbPath = 'test_home_step2_${DateTime.now().microsecondsSinceEpoch}.db';
  });

  tearDown(() async {
    try {
      await DatabaseHelper.instance.close();
    } catch (_) {}
  });

  test('SQLite Version 5 to Version 6 Migration & backend_user_id Test', () async {
    final dbHelper = DatabaseHelper.instance;
    // Initialize DB (creates version 6 directly)
    final db = await dbHelper.database;

    // Verify users table contains backend_user_id column
    final tableInfo = await db.rawQuery('PRAGMA table_info(users);');
    final columns = tableInfo.map((c) => c['name'] as String).toList();
    expect(columns.contains('backend_user_id'), isTrue);
  });

  test('Backend UUID to Local Integer ID Mapping and Isolation Test', () async {
    final dbHelper = DatabaseHelper.instance;
    final profileRepo = FitnessProfileRepository(dbHelper);

    // Map user 1 with backend UUID
    final localId1 = await profileRepo.getOrCreateLocalUserId(
      email: 'alice@venture.com',
      username: 'Alice',
      backendUserId: 'uuid-uuid-1111',
    );

    // Map user 2 with different backend UUID
    final localId2 = await profileRepo.getOrCreateLocalUserId(
      email: 'bob@venture.com',
      username: 'Bob',
      backendUserId: 'uuid-uuid-2222',
    );

    expect(localId1, isNot(equals(localId2)));

    // Re-querying with same backend UUID should return same local ID without duplication
    final localId1Again = await profileRepo.getOrCreateLocalUserId(
      email: 'alice@venture.com',
      username: 'Alice',
      backendUserId: 'uuid-uuid-1111',
    );
    expect(localId1Again, equals(localId1));
  });
}
