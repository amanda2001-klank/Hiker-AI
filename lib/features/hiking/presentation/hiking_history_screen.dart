import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/hiking_session_repository.dart';
import '../../fitness/data/fitness_profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class HikingHistoryScreen extends ConsumerStatefulWidget {
  const HikingHistoryScreen({super.key});

  @override
  ConsumerState<HikingHistoryScreen> createState() => _HikingHistoryScreenState();
}

class _HikingHistoryScreenState extends ConsumerState<HikingHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _historyItems = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email ?? 'user@venture.com';
      final username = authState.user?.username ?? 'User';
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

      final sessionRepo = ref.read(hikingSessionRepositoryProvider);
      final history = await sessionRepo.getHikingHistoryForUser(userId);

      if (mounted) {
        setState(() {
          _historyItems = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load hiking history: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hiking History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          : _historyItems.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No completed hikes found in history.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          final trailName = item['trail_name'] as String? ?? 'Pine Mountain Trail';
          final hikingDate = item['hiking_date'] as String? ?? '2026-03-01';
          final distance = item['distance_km']?.toString() ?? '8.5';
          final durationMins = item['duration_minutes']?.toString() ?? '135';
          final calories = item['calories_burned']?.toString() ?? '780';
          final sessionId = item['hiking_session_id'] as int?;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(trailName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Date: $hikingDate • $distance km • $durationMins mins • $calories kcal'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                if (sessionId != null) {
                  context.push('/trail-summary', extra: {'sessionId': sessionId, 'distance': double.tryParse(distance) ?? 8.5});
                }
              },
            ),
          );
        },
      ),
    );
  }
}
