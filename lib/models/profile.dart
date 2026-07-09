// lib/models/profile.dart
class Profile {
  final String id;
  final String fullName;
  final String role;
  final String? email;
  final String? password;
  final String? confirmPassword;
  final String? phoneNumber;
  final String? nationalId;
  final DateTime? hiringDate;
  final bool isConfirmed;
  final String? managerId;
  final String employeeStatus; // active, on_leave, terminated
  final DateTime createdAt;
  /// Per-employee permission overrides set by admin.
  /// Keys match the permission keys in EmployeePermissionKeys.
  /// null means "use role default", true/false means explicit override.
  final Map<String, bool> customPermissions;

  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.password,
    this.confirmPassword,
    this.phoneNumber,
    this.nationalId,
    this.hiringDate,
    this.isConfirmed = false,
    this.managerId,
    this.employeeStatus = 'active',
    required this.createdAt,
    this.customPermissions = const {},
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    // Parse custom_permissions JSON field
    Map<String, bool> parsedPerms = {};
    final rawPerms = map['custom_permissions'];
    if (rawPerms is Map) {
      rawPerms.forEach((k, v) {
        if (v is bool) parsedPerms[k.toString()] = v;
      });
    }

    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String,
      role: map['role'] as String,
      email: map['email'] as String?,
      password: map['password'] as String?,
      confirmPassword: map['confirm_password'] as String?,
      phoneNumber: map['phone_number'] as String?,
      nationalId: map['national_id'] as String?,
      hiringDate: map['hiring_date'] != null
          ? DateTime.parse(map['hiring_date'] as String)
          : null,
      isConfirmed: map['is_confirmed'] as bool? ?? false,
      managerId: map['manager_id'] as String?,
      employeeStatus: map['employee_status'] as String? ?? 'active',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      customPermissions: parsedPerms,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'role': role,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'phone_number': phoneNumber,
        'national_id': nationalId,
        'hiring_date': hiringDate?.toIso8601String(),
        'is_confirmed': isConfirmed,
        'manager_id': managerId,
        'employee_status': employeeStatus,
        'created_at': createdAt.toIso8601String(),
        'custom_permissions': customPermissions,
      };

  Profile copyWith({
    Map<String, bool>? customPermissions,
    String? fullName,
    String? role,
    String? email,
    String? phoneNumber,
    String? nationalId,
    DateTime? hiringDate,
    bool? isConfirmed,
    String? managerId,
    String? employeeStatus,
  }) {
    return Profile(
      id: id,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      email: email ?? this.email,
      password: password,
      confirmPassword: confirmPassword,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nationalId: nationalId ?? this.nationalId,
      hiringDate: hiringDate ?? this.hiringDate,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      managerId: managerId ?? this.managerId,
      employeeStatus: employeeStatus ?? this.employeeStatus,
      createdAt: createdAt,
      customPermissions: customPermissions ?? this.customPermissions,
    );
  }
}
