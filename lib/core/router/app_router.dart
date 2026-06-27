import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/auth/presentation/onboarding_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/shell/shell_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/explore/presentation/explore_page.dart';
import '../../features/create/presentation/create_page.dart';
import '../../features/search/presentation/search_page.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../../features/story/presentation/story_detail_page.dart' show PinDetailPage;
import '../../features/profile/presentation/settings_page.dart';
import '../../features/auth/presentation/phone_auth_page.dart';
import '../providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      if (authState.isInitializing) return null;

      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc == '/splash' ||
          loc == '/onboarding' ||
          loc == '/login' ||
          loc == '/register';

      if (!isAuthenticated && !isAuthRoute) return '/login';
      if (isAuthenticated &&
          (loc == '/login' ||
              loc == '/register' ||
              loc == '/splash' ||
              loc == '/onboarding')) {
        return '/feed';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/pin/:id',
        builder: (context, state) =>
            PinDetailPage(storyId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/user/:userId',
        builder: (context, state) =>
            UserProfilePage(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/phone-auth',
        builder: (context, state) => PhoneAuthPage(
          isLinking: state.extra == true,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                builder: (context, state) => const ExplorePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/create',
                builder: (context, state) => const CreatePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
