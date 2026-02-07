import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prescription_scanner/data/models/user_profile.dart';
import 'package:prescription_scanner/data/providers.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

// 3. User Provider (Current User)
final userProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

// 4. User Profile Provider (Fetches from public.profiles)
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(userProvider);
  final supabase = ref.watch(supabaseProvider);

  if (user == null) return null;

  try {
    debugPrint('Fetching profile for user: ${user.id}');
    final response = await supabase
        .from('profiles')
        .select()
        .eq('user_id', user.id)
        .single();
    debugPrint('Profile found: $response');
    return UserProfile.fromJson(response);
  } catch (e) {
    debugPrint('Profile not found or error: $e');
    return null;
  }
});
