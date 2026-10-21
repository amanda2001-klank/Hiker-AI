import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/trail_repository.dart';
import '../data/pre_hike_repository.dart';
import '../data/hiking_session_repository.dart';
import '../../fitness/data/fitness_profile_repository.dart';
import '../../fitness/data/experience_assessment_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/database/database_helper.dart';

class PreHikeScreen extends ConsumerStatefulWidget {
  final Object? extraData;
  const PreHikeScreen({super.key, this.extraData});

  @override
  ConsumerState<PreHikeScreen> createState() => _PreHikeScreenState();
}

class _PreHikeScreenState extends ConsumerState<PreHikeScreen> {
  bool waterChecked = false;
  bool gearChecked = false;
  bool routeChecked = false;
  bool weatherChecked = false;

  bool _isLoading = true;
  PreHikeRecommendationModel? _recommendations;
  bool _isStartingHike = false;

  TrailModel? _trail;
  String _date = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    final extra = widget.extraData;
    if (extra is TrailModel) {
      _trail = extra;
    } else if (extra is Map<String, dynamic>) {
      _trail = extra['trail'] as TrailModel?;
      if (extra['date'] != null) {
        _date = extra['date'].toString();
      }
    }
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email;
      final backendUserId = authState.user?.userId;
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final assessmentRepo = ref.read(experienceAssessmentRepositoryProvider);
      final db = await ref.read(databaseHelperProvider).database;

      int userId = 1;
      if (email != null) {
        userId = await profileRepo.getOrCreateLocalUserId(
          email: email,
          username: authState.user?.username ?? 'User',
          backendUserId: backendUserId,
        );
      }

      final assessment = await assessmentRepo.getLatestAssessmentForUser(userId);

      // Read latest valid 7-day assessment from seven_day_activity_assessments with Freshness Policy (Phase 7B)
      final sevenDayRes = await db.query(
        'seven_day_activity_assessments',
        where: 'user_id = ? AND formula_version = ?',
        whereArgs: [userId, 'v1.0-google-fit-7d'],
        orderBy: 'assessed_at DESC',
        limit: 1,
      );

      double? fitnessScore;
      if (sevenDayRes.isNotEmpty) {
        final row = sevenDayRes.first;
        final endDateStr = row['assessment_end_date']?.toString();
        final scoreVal = (row['calculated_score'] as num?)?.toDouble();

        if (endDateStr != null && scoreVal != null && scoreVal >= 0.0 && scoreVal <= 100.0) {
          final endDate = DateTime.tryParse(endDateStr);
          if (endDate != null) {
            final today = DateTime.now();
            final todayDate = DateTime(today.year, today.month, today.day);
            final normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);

            final diffDays = todayDate.difference(normalizedEndDate).inDays;

            // Freshness policy: 0 to 7 calendar days old, and not future-dated
            if (diffDays >= 0 && diffDays <= 7) {
              fitnessScore = scoreVal;
            }
          }
        }
      }

      final repo = ref.read(preHikeRepositoryProvider);
      final recs = await repo.getPreHikeRecommendations(
        _date,
        trail: _trail,
        fitnessScore: fitnessScore,
        experienceLevel: assessment?.experienceLevel,
      );

      if (mounted) {
        setState(() {
          _recommendations = recs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startHike() async {
    if (_isStartingHike) return;

    setState(() {
      _isStartingHike = true;
    });

    try {
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email ?? 'user@venture.com';
      final username = authState.user?.username ?? 'User';
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

      final sessionRepo = ref.read(hikingSessionRepositoryProvider);
      final sessionId = await sessionRepo.startHikeSession(
        userId: userId,
        trailId: _trail?.id,
      );

      if (!mounted) return;

      context.go('/live-monitoring', extra: {'sessionId': sessionId, 'trail': _trail});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting hike session: $e')),
      );
      setState(() {
        _isStartingHike = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = waterChecked && gearChecked && routeChecked && weatherChecked;

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Hike Preparation & Checklist')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_trail != null) ...[
            Card(
              color: const Color(0xFFF1F7F5),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected Trail: ${_trail!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Planned Date: $_date', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pre-Hike Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (_recommendations != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _recommendations!.completenessStatus == 'Personalized' ? const Color(0xFFE6F8F2) : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _recommendations!.completenessStatus,
                    style: TextStyle(
                      color: _recommendations!.completenessStatus == 'Personalized' ? const Color(0xFF25C9A0) : Colors.orange.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recommendations != null) ...[
            ..._recommendations!.recommendations.map((rec) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF25C9A0), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rec)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Text('Special Notes & Precautions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._recommendations!.specialNotes.map((note) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info, color: Color(0xFF086477), size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(note)),
                ],
              ),
            )),
          ],
          const SizedBox(height: 24),
          const Text('Pre-Hike Safety Checklist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          CheckboxListTile(
            title: const Text('Water & Hydration (Targeted intake checked)'),
            value: waterChecked,
            onChanged: (val) => setState(() => waterChecked = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Safety Gear & First Aid Pack'),
            value: gearChecked,
            onChanged: (val) => setState(() => gearChecked = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Route Map & Offline GPS Reviewed'),
            value: routeChecked,
            onChanged: (val) => setState(() => routeChecked = val ?? false),
          ),
          CheckboxListTile(
            title: const Text('Weather Forecast & Warnings Checked'),
            value: weatherChecked,
            onChanged: (val) => setState(() => weatherChecked = val ?? false),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (allChecked && !_isStartingHike) ? _startHike : null,
            child: _isStartingHike
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Text('Begin Live Monitoring'),
          ),
        ],
      ),
    );
  }
}
