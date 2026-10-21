import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/fitness/presentation/fitness_home_screen.dart';
import '../../features/fitness/presentation/fitness_profile_screen.dart';
import '../../features/fitness/presentation/experience_assessment_screen.dart';
import '../../features/fitness/presentation/fitness_score_assessment_screen.dart';
import '../../features/fitness/presentation/connected_devices_screen.dart';
import '../../features/hiking/presentation/trail_details_screen.dart';
import '../../features/hiking/presentation/pre_hike_screen.dart';
import '../../features/hiking/presentation/live_monitoring_screen.dart';
import '../../features/hiking/presentation/trail_summary_screen.dart';
import '../../features/hiking/presentation/hiking_history_screen.dart';
import '../../features/hiking/data/trail_repository.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/fitness-home',
        builder: (context, state) {
          final newUser = state.uri.queryParameters['newUser'];
          return FitnessHomeScreen(newUser: newUser);
        },
      ),
      GoRoute(
        path: '/fitness-profile',
        builder: (context, state) => const FitnessProfileScreen(),
      ),
      GoRoute(
        path: '/experience-assessment',
        builder: (context, state) => const ExperienceAssessmentScreen(),
      ),
      GoRoute(
        path: '/fitness-score-assessment',
        builder: (context, state) => const FitnessScoreAssessmentScreen(),
      ),
      GoRoute(
        path: '/connect-watch',
        builder: (context, state) => const ConnectedDevicesScreen(),
      ),
      GoRoute(
        path: '/trail-details',
        builder: (context, state) {
          final trail = state.extra as TrailModel?;
          return TrailDetailsScreen(trail: trail);
        },
      ),
      GoRoute(
        path: '/pre-hike',
        builder: (context, state) {
          final extraData = state.extra;
          return PreHikeScreen(extraData: extraData);
        },
      ),
      GoRoute(
        path: '/live-monitoring',
        builder: (context, state) {
          final extraData = state.extra;
          return LiveMonitoringScreen(extraData: extraData is Map<String, dynamic> ? extraData : null);
        },
      ),
      GoRoute(
        path: '/trail-summary',
        builder: (context, state) {
          final extraData = state.extra;
          return TrailSummaryScreen(extraData: extraData is Map<String, dynamic> ? extraData : null);
        },
      ),
      GoRoute(
        path: '/hiking-history',
        builder: (context, state) => const HikingHistoryScreen(),
      ),
    ],
  );
});
