import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mp3tageditor/core/services/shared_prefs_service.dart';
import 'package:mp3tageditor/features/onboarding/presentation/onboarding_screen.dart';
import 'package:mp3tageditor/features/main/presentation/main_screen.dart';
import 'package:mp3tageditor/features/editor/presentation/editor_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.read(sharedPrefsServiceProvider);
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  return GoRouter(
    initialLocation: hasSeenOnboarding ? '/' : '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/editor',
        builder: (context, state) {
          final filePath = state.extra as String?;
          if (filePath == null) return const MainScreen();
          return EditorScreen(filePath: filePath);
        },
      ),
    ],
  );
});
