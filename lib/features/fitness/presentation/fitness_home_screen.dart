import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/fitness_profile_repository.dart';
import '../data/experience_assessment_repository.dart';
import '../data/daily_activity_repository.dart';
import '../data/seven_day_fitness_engine.dart';
import '../../hiking/data/trail_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/database/database_helper.dart';

class FitnessHomeScreen extends ConsumerStatefulWidget {
  final String? newUser;
  const FitnessHomeScreen({super.key, this.newUser});

  @override
  ConsumerState<FitnessHomeScreen> createState() => _FitnessHomeScreenState();
}

class _FitnessHomeScreenState extends ConsumerState<FitnessHomeScreen> {
  FitnessProfileModel? _profile;
  ExperienceAssessmentModel? _assessment;
  Map<String, dynamic>? _latestFitnessAssessment;
  SevenDayFitnessAssessmentRecord? _latestSevenDayAssessment;
  DailyActivityModel? _latestActivity;
  List<TrailModel> _recommendedTrails = [];
  TrailModel? _selectedTrail;
  String _searchQuery = '';
  String _selectedDifficulty = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email;
      final backendUserId = authState.user?.userId;
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final assessmentRepo = ref.read(experienceAssessmentRepositoryProvider);
      final activityRepo = ref.read(dailyActivityRepositoryProvider);
      final trailRepo = ref.read(trailRepositoryProvider);
      final db = await ref.read(databaseHelperProvider).database;

      int userId = 1;
      if (email != null) {
        userId = await profileRepo.getOrCreateLocalUserId(
          email: email,
          username: authState.user?.username ?? 'User',
          backendUserId: backendUserId,
        );
      }

      final profile = await profileRepo.getProfileByUserId(userId);
      final assessment = await assessmentRepo.getLatestAssessmentForUser(userId);
      final activity = await activityRepo.getLatestActivityForUser(userId);

      final fitRes = await db.query(
        'fitness_assessments',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'assessed_at DESC',
        limit: 1,
      );

      final sevenDayRes = await db.query(
        'seven_day_activity_assessments',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'assessed_at DESC',
        limit: 1,
      );

      List<TrailModel> trails = [];
      try {
        trails = await trailRepo.getRecommendedTrails();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _profile = profile;
          _assessment = assessment;
          _latestActivity = activity;
          _latestFitnessAssessment = fitRes.isNotEmpty ? fitRes.first : null;
          _latestSevenDayAssessment = sevenDayRes.isNotEmpty ? SevenDayFitnessAssessmentRecord.fromMap(sevenDayRes.first) : null;
          _recommendedTrails = trails;
          if (trails.isNotEmpty && _selectedTrail == null) {
            _selectedTrail = trails.first;
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final username = authState.user?.username ?? _profile?.fullName ?? 'Hiker';
    final email = authState.user?.email ?? 'hiker@venture.com';
    final experienceLevel = _assessment?.experienceLevel ?? 'Unknown';
    final fitnessScoreText = _latestFitnessAssessment != null
        ? '${_latestFitnessAssessment!['calculated_score']} / 100 (${_latestFitnessAssessment!['fitness_level']})'
        : 'Not Assessed';

    final filteredTrails = _recommendedTrails.where((t) {
      final matchesSearch = t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesDiff = _selectedDifficulty == 'All' || t.difficulty.toLowerCase() == _selectedDifficulty.toLowerCase();
      return matchesSearch && matchesDiff;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F7F5),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF086477)))
          : SafeArea(
              child: Column(
                children: [
                  // 1. Premium Teal Header
                  Container(
                    color: const Color(0xFF086477),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.explore, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'APP Venture AI',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.person, color: Colors.white),
                                  onPressed: () => context.push('/fitness-profile'),
                                  tooltip: 'Fitness Profile',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout, color: Colors.white),
                                  onPressed: () async {
                                    await ref.read(authControllerProvider.notifier).logout();
                                    if (context.mounted) {
                                      context.go('/login');
                                    }
                                  },
                                  tooltip: 'Logout',
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Welcome back,',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  username,
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.terrain, color: Colors.white, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Experience: $experienceLevel',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Body Content
                  Expanded(
                    child: RefreshIndicator(
                      color: const Color(0xFF086477),
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Today's Activity / Assessments Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          "Today's Activity & Assessments",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Verified User Data & Sync Status',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Assessment Cards Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => context.push('/fitness-score-assessment'),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F7F5),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFD8E5E2)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Fitness Score (CSV)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                              const SizedBox(height: 6),
                                              Text(
                                                fitnessScoreText,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF086477)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _latestFitnessAssessment == null ? 'Take Assessment →' : 'Retake Assessment →',
                                                style: const TextStyle(color: Color(0xFF086477), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => context.push('/experience-assessment'),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F7F5),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFD8E5E2)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Hiking Experience', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                              const SizedBox(height: 6),
                                              Text(
                                                experienceLevel,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF086477)),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                _assessment == null ? 'Assess Experience →' : 'Retake Assessment →',
                                                style: const TextStyle(color: Color(0xFF086477), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Daily Activity Summary / Empty State
                                const Text('Daily Activity Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30))),
                                const SizedBox(height: 12),
                                _latestActivity != null
                                    ? Column(
                                        children: [
                                          GridView.count(
                                            crossAxisCount: 2,
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                            childAspectRatio: 1.8,
                                            children: [
                                              _buildMetricTile(Icons.directions_walk, 'Steps', '${_latestActivity!.steps}', 'steps'),
                                              _buildMetricTile(Icons.local_fire_department, 'Calories burned', '${_latestActivity!.caloriesBurned.toInt()}', 'kcal'),
                                              _buildMetricTile(Icons.straighten, 'Distance', '${_latestActivity!.distanceKm}', 'km'),
                                              _buildMetricTile(Icons.favorite, 'Avg Heart Rate', '${_latestActivity!.avgHeartRate.toInt()}', 'bpm'),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Source: Samsung Galaxy Watch6 • Date: ${_latestActivity!.date}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      )
                                    : Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F7F5),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'No activity data available yet.\nConnect your smartwatch to sync activity.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(color: Colors.grey, fontSize: 13),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 7-Day Activity-Based Fitness Index Card (Phase 4)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          '7-Day Activity-Based Fitness Index',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Formula: v1.0-google-fit-7d',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () => context.push('/fitness-score-assessment'),
                                      child: const Text('Assessment', style: TextStyle(color: Color(0xFF086477))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _latestSevenDayAssessment != null
                                    ? Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Score: ${_latestSevenDayAssessment!.calculatedScore} / 100',
                                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF086477)),
                                          ),
                                          const SizedBox(height: 6),
                                          Text('Period: ${_latestSevenDayAssessment!.assessmentStartDate} to ${_latestSevenDayAssessment!.assessmentEndDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('Completeness: ${_latestSevenDayAssessment!.dataCompleteness}', style: const TextStyle(fontSize: 12, color: Color(0xFF25C9A0), fontWeight: FontWeight.bold)),
                                          Text('Source: ${_latestSevenDayAssessment!.dataSource}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Experimental recent-activity index. Not a medical fitness assessment.',
                                            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      )
                                    : const Text(
                                        'No 7-day activity assessment available.',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Connected Devices Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Connected devices',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                              ),
                              TextButton(
                                onPressed: () => context.push('/connect-watch'),
                                child: const Text('Manage', style: TextStyle(color: Color(0xFF086477))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Connection and data status are shown separately',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFD8E5E2)),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => context.push('/connect-watch'),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F8F2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.watch, color: Color(0xFF25C9A0), size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: const [
                                              Text(
                                                'Galaxy Watch6',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                                              ),
                                              SizedBox(height: 2),
                                              Text(
                                                'SM-R940',
                                                style: TextStyle(fontSize: 12, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F8F2),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Text(
                                            'Connected',
                                            style: TextStyle(color: Color(0xFF25C9A0), fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: const [
                                        Icon(Icons.battery_full, size: 14, color: Colors.grey),
                                        SizedBox(width: 4),
                                        Text('64%', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        SizedBox(width: 16),
                                        Text('Last sync: 12 minutes ago', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: const [
                                        _SensorPill(label: 'Heart rate'),
                                        _SensorPill(label: 'Steps'),
                                        _SensorPill(label: 'Motion'),
                                        _SensorPill(label: 'HRV (IBI)'),
                                        _SensorPill(label: 'SpO₂ (spot check)'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Past Hikes Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Past hikes',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Completed hikes only',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => context.push('/hiking-history'),
                                child: const Text('View all', style: TextStyle(color: Color(0xFF086477))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildPastHikeCard(
                            title: "Little Adam's Peak",
                            date: 'Sun, 20 Sep 2026',
                            distance: '4.6 km',
                            duration: '1h 52m',
                            elevation: '196 m',
                            badgeText: 'Peak Low',
                            badgeColor: const Color(0xFFE6F8F2),
                            badgeTextColor: const Color(0xFF25C9A0),
                            note: 'Completed with no high-risk alerts.',
                          ),
                          const SizedBox(height: 8),
                          _buildPastHikeCard(
                            title: "Horton Plains – World's...",
                            date: 'Sun, 30 Aug 2026',
                            distance: '9.7 km',
                            duration: '3h 38m',
                            elevation: '162 m',
                            badgeText: 'Peak Moderate',
                            badgeColor: const Color(0xFFFBF4E4),
                            badgeTextColor: const Color(0xFFB8860B),
                            note: "One moderate fatigue alert near Baker's Falls.",
                          ),
                          const SizedBox(height: 24),

                          // Trail Discovery & Recommendations
                          const Text(
                            'Find a trail',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search by trail name or location',
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFD8E5E2)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFD8E5E2)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: ['All', 'Easy', 'Moderate', 'Hard'].map((diff) {
                                final isSelected = _selectedDifficulty == diff;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: ChoiceChip(
                                    label: Text(diff),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedDifficulty = diff);
                                    },
                                    selectedColor: const Color(0xFF086477),
                                    backgroundColor: Colors.white,
                                    labelStyle: TextStyle(
                                      color: isSelected ? Colors.white : const Color(0xFF1D2B30),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recommended for you',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5E6CA),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.science, size: 13, color: Color(0xFF8B5A2B)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Mock service',
                                      style: TextStyle(color: Color(0xFF8B5A2B), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Supplied by the Trail Recommendation service',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),

                          if (filteredTrails.isEmpty)
                            const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No trails match your search.')))
                          else
                            for (final trail in filteredTrails)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _selectedTrail?.name == trail.name ? const Color(0xFF086477) : const Color(0xFFD8E5E2),
                                    width: _selectedTrail?.name == trail.name ? 2.0 : 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedTrail = trail;
                                    });
                                    context.push('/trail-details', extra: trail);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            height: 170,
                                            width: double.infinity,
                                            color: Colors.grey.shade300,
                                            child: trail.imageUrl != null && trail.imageUrl!.startsWith('http')
                                                ? Image.network(
                                                    trail.imageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.landscape, size: 64, color: Colors.grey),
                                                  )
                                                : Image.network(
                                                    'https://images.unsplash.com/photo-1551632811-561732d1e306',
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFBF4E4),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                trail.difficulty,
                                                style: const TextStyle(color: Color(0xFFB8860B), fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            right: 12,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: _selectedTrail?.name == trail.name ? const Color(0xFF086477) : Colors.black.withValues(alpha: 0.4),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _selectedTrail?.name == trail.name ? Icons.check : Icons.circle_outlined,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              trail.name,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                                            ),
                                            if (trail.location != null) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(trail.location!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                _buildTrailMeta(Icons.straighten, '${trail.distanceKm} km', 'Distance'),
                                                _buildTrailMeta(Icons.access_time, '${trail.estimatedDurationMins ~/ 60}-${(trail.estimatedDurationMins ~/ 60) + 1} h', 'Est. time'),
                                                _buildTrailMeta(Icons.terrain, '${trail.elevationGainM.toInt()} m', 'Elev. gain'),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F7F5),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: const Color(0xFFD8E5E2)),
                                              ),
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.auto_awesome, size: 16, color: Color(0xFF086477)),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Elevation gain fits a Moderate fitness level; good step up from your recent hike.',
                                                      style: TextStyle(fontSize: 12, color: Color(0xFF086477), fontWeight: FontWeight.w500),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: const Border(top: BorderSide(color: Color(0xFFD8E5E2))),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selected trail',
                      style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedTrail?.name ?? 'Select a trail',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 110,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedTrail != null) {
                      context.push('/pre-hike', extra: _selectedTrail);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF086477),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text('Go', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
      IconData icon,
      String title,
      String value,
      String unit,
      ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF086477)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D2B30),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPastHikeCard({
    required String title,
    required String date,
    required String distance,
    required String duration,
    required String elevation,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required String note,
  }) {
    return InkWell(
      onTap: () => context.push('/hiking-history'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD8E5E2)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b',
                height: 64,
                width: 64,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(color: badgeTextColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.straighten, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(distance, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      const Icon(Icons.access_time, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(duration, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(width: 10),
                      const Icon(Icons.terrain, size: 12, color: Colors.grey),
                      const SizedBox(width: 3),
                      Text(elevation, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTrailMeta(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF086477)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30))),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}

class _SensorPill extends StatelessWidget {
  final String label;
  const _SensorPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E5E2)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Color(0xFF1D2B30), fontWeight: FontWeight.w500),
      ),
    );
  }
}
