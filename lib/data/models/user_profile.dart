class UserProfile {
  final String userId;
  final String role; // 'customer' or 'pharmacy_owner'
  final String? fullName;
  final String? phone;
  final Map<String, dynamic> preferences;

  UserProfile({
    required this.userId,
    required this.role,
    this.fullName,
    this.phone,
    Map<String, dynamic>? preferences,
  }) : preferences = preferences ?? {};

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'customer',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      preferences: json['preferences'] != null
          ? Map<String, dynamic>.from(json['preferences'] as Map)
          : {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'full_name': fullName,
      'phone': phone,
      'preferences': preferences,
    };
  }
  
  bool get isOwner => role == 'pharmacy_owner';

  // Helper getters for preferences with defaults
  int get defaultRadiusM => preferences['default_radius_m'] as int? ?? 5000;
  String get sortMode => preferences['sort_mode'] as String? ?? 'balanced';
  bool get requireFullMatch => preferences['require_full_match'] as bool? ?? false;
  int get maxResults => preferences['max_results'] as int? ?? 20;
  
  // Owner-only preferences
  int get lowStockThreshold => preferences['low_stock_threshold'] as int? ?? 10;
  bool get showLowStockOnly => preferences['show_low_stock_only'] as bool? ?? false;
}
