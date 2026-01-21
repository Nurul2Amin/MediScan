import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';

class SettingsState {
  final bool isLoading;
  final String? error;

  SettingsState({
    this.isLoading = false,
    this.error,
  });

  SettingsState copyWith({
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    return SettingsState();
  }

  Future<void> updateProfile({
    required String fullName,
    required String phone,
    required Map<String, dynamic> preferences,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final supabase = ref.read(supabaseProvider);
      final user = ref.read(userProvider);
      
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Update profiles table (role is immutable, so we don't include it)
      await supabase.from('profiles').update({
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'preferences': preferences,
      }).eq('user_id', user.id);

      // Invalidate userProfileProvider to refresh UI
      ref.invalidate(userProfileProvider);

      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      rethrow;
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
