// lib/models/role_permission.dart
class RolePermission {
  final String role;
  final bool canViewClients;
  final bool canEditClients;
  final bool canDeleteClients;
  final bool canApproveLoans;
  final bool canViewAnalytics;
  final bool canManageRoles;
  final Map<String, dynamic> fieldVisibility;

  const RolePermission({
    required this.role,
    this.canViewClients = false,
    this.canEditClients = false,
    this.canDeleteClients = false,
    this.canApproveLoans = false,
    this.canViewAnalytics = false,
    this.canManageRoles = false,
    this.fieldVisibility = const {},
  });

  factory RolePermission.fromMap(Map<String, dynamic> map) => RolePermission(
        role: map['role'] as String,
        canViewClients: map['can_view_clients'] as bool? ?? false,
        canEditClients: map['can_edit_clients'] as bool? ?? false,
        canDeleteClients: map['can_delete_clients'] as bool? ?? false,
        canApproveLoans: map['can_approve_loans'] as bool? ?? false,
        canViewAnalytics: map['can_view_analytics'] as bool? ?? false,
        canManageRoles: map['can_manage_roles'] as bool? ?? false,
        fieldVisibility: (map['field_visibility'] as Map?)?.cast<String, dynamic>() ?? {},
      );

  Map<String, dynamic> toMap() => {
        'role': role,
        'can_view_clients': canViewClients,
        'can_edit_clients': canEditClients,
        'can_delete_clients': canDeleteClients,
        'can_approve_loans': canApproveLoans,
        'can_view_analytics': canViewAnalytics,
        'can_manage_roles': canManageRoles,
        'field_visibility': fieldVisibility,
      };
}
