class UserProfile {
  final String userId;
  final String role; // 'customer' or 'pharmacy_owner'
  final String? fullName;
  final String? phone;

  UserProfile({
    required this.userId,
    required this.role,
    this.fullName,
    this.phone,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'customer',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'role': role,
      'full_name': fullName,
      'phone': phone,
    };
  }
  
  bool get isOwner => role == 'pharmacy_owner';
}
