import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/presentation/pages/auth/login_page.dart';
import 'package:prescription_scanner/presentation/pages/home/home_page.dart';
import 'package:prescription_scanner/presentation/pages/owner/owner_dashboard.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final userProfile = ref.watch(userProfileProvider);

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // 1. Check Auth State
      final isLoggedIn = authState.value?.session != null;
      final isLoggingIn = state.uri.toString() == '/login';

      if (authState.isLoading) return null; // Loading

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      // 2. Check User Profile (Role)
      if (userProfile.isLoading) return null; // Still fetching profile

      final profile = userProfile.value;
      
      // If logging in and we have a profile, redirect based on role
      if (isLoggingIn || state.uri.toString() == '/') {
        if (profile?.role == 'pharmacy_owner') {
          return '/owner';
        } else {
          return '/home';
        }
      }

      return null; // No redirect needed
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
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerDashboardPage(),
      ),
    ],
  );
});
