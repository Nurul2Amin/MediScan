import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/presentation/pages/auth/login_page.dart';
import 'package:prescription_scanner/presentation/pages/auth/signup_page.dart';
import 'package:prescription_scanner/presentation/pages/home/home_page.dart';
import 'package:prescription_scanner/presentation/pages/owner/owner_dashboard.dart';
import 'package:prescription_scanner/presentation/pages/settings/settings_page.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.value?.session != null;
      final currentPath = state.uri.toString();
      final isAuthPage = currentPath == '/login' || currentPath == '/signup';

      if (authState.isLoading) return null;

      if (!isLoggedIn) {
        return isAuthPage ? null : '/login';
      }

      if (userProfile.isLoading) return null;

      final profile = userProfile.value;
      
      if (currentPath == '/owner' && profile?.role != 'pharmacy_owner') {
        return '/home';
      }

      if (currentPath == '/' || isAuthPage) {
        if (profile?.role == 'pharmacy_owner') {
          return '/owner';
        } else {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardPage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});
