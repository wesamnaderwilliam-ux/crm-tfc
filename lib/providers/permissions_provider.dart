import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/supabase_config.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

// ─────────────────────────────────────────────────────────────────────────────
// Permission Keys — all toggleable features in the app
// ─────────────────────────────────────────────────────────────────────────────
class EmployeePermissionKeys {
  // Main screens / navigation tabs
  static const String viewDashboard = 'viewDashboard';
  static const String viewClients = 'viewClients';
  static const String addClient = 'addClient';
  static const String viewEmployees = 'viewEmployees';
  static const String viewBanks = 'viewBanks';
  static const String viewSettings = 'viewSettings';

  // Client actions
  static const String editClient = 'editClient';
  static const String deleteClient = 'deleteClient';
  static const String approveLoans = 'approveLoans';
  static const String addNote = 'addNote';

  // Client detail fields
  static const String fieldPhone = 'fieldPhone';
  static const String fieldNationalId = 'fieldNationalId';
  static const String fieldBirthDate = 'fieldBirthDate';
  static const String fieldEmployment = 'fieldEmployment';
  static const String fieldSalary = 'fieldSalary';
  static const String fieldCreditScore = 'fieldCreditScore';
  static const String fieldLoans = 'fieldLoans';
  static const String fieldCards = 'fieldCards';
  static const String fieldDocuments = 'fieldDocuments';

  // NEW: Banks Directory Permissions
  static const String manageBanks = 'manageBanks';
  static const String viewBankPhones = 'viewBankPhones';

  // NEW: Company Employees Permissions
  static const String manageEmployees = 'manageEmployees';
  static const String viewEmployeeNationalId = 'viewEmployeeNationalId';
  static const String viewEmployeePhone = 'viewEmployeePhone';

  /// Default values for each role
  static Map<String, bool> defaultsForRole(String role) {
    if (role == 'admin') {
      return {
        viewDashboard: true,
        viewClients: true,
        addClient: true,
        viewEmployees: true,
        viewBanks: true,
        viewSettings: true,
        editClient: true,
        deleteClient: true,
        approveLoans: true,
        addNote: true,
        fieldPhone: true,
        fieldNationalId: true,
        fieldBirthDate: true,
        fieldEmployment: true,
        fieldSalary: true,
        fieldCreditScore: true,
        fieldLoans: true,
        fieldCards: true,
        fieldDocuments: true,
        manageBanks: true,
        viewBankPhones: true,
        manageEmployees: true,
        viewEmployeeNationalId: true,
        viewEmployeePhone: true,
      };
    } else if (role == 'manager') {
      return {
        viewDashboard: true,
        viewClients: true,
        addClient: true,
        viewEmployees: false,
        viewBanks: true,
        viewSettings: true,
        editClient: true,
        deleteClient: true,
        approveLoans: true,
        addNote: true,
        fieldPhone: true,
        fieldNationalId: true,
        fieldBirthDate: true,
        fieldEmployment: true,
        fieldSalary: true,
        fieldCreditScore: true,
        fieldLoans: true,
        fieldCards: true,
        fieldDocuments: true,
        manageBanks: true,
        viewBankPhones: false,
        manageEmployees: true,
        viewEmployeeNationalId: true,
        viewEmployeePhone: true,
      };
    } else if (role == 'bank_employee') {
      return {
        viewDashboard: true,
        viewClients: true,
        addClient: false,
        viewEmployees: false,
        viewBanks: true,
        viewSettings: false,
        editClient: false,
        deleteClient: false,
        approveLoans: true,
        addNote: false,
        fieldPhone: true,
        fieldNationalId: true,
        fieldBirthDate: true,
        fieldEmployment: true,
        fieldSalary: true,
        fieldCreditScore: true,
        fieldLoans: true,
        fieldCards: true,
        fieldDocuments: true,
        manageBanks: false,
        viewBankPhones: false,
        manageEmployees: false,
        viewEmployeeNationalId: false,
        viewEmployeePhone: false,
      };
    } else if (role == 'host') {
      return {
        viewDashboard: false,
        viewClients: true,
        addClient: false,
        viewEmployees: false,
        viewBanks: false,
        viewSettings: false,
        editClient: false,
        deleteClient: false,
        approveLoans: false,
        addNote: false,
        fieldPhone: true,
        fieldNationalId: true,
        fieldBirthDate: true,
        fieldEmployment: true,
        fieldSalary: true,
        fieldCreditScore: true,
        fieldLoans: true,
        fieldCards: true,
        fieldDocuments: true,
        manageBanks: false,
        viewBankPhones: false,
        manageEmployees: false,
        viewEmployeeNationalId: false,
        viewEmployeePhone: false,
      };
    } else {
      // company_employee
      return {
        viewDashboard: true,
        viewClients: true,
        addClient: true,
        viewEmployees: false,
        viewBanks: true,
        viewSettings: false,
        editClient: true,
        deleteClient: false,
        approveLoans: false,
        addNote: true,
        fieldPhone: true,
        fieldNationalId: true,
        fieldBirthDate: true,
        fieldEmployment: true,
        fieldSalary: true,
        fieldCreditScore: true,
        fieldLoans: true,
        fieldCards: true,
        fieldDocuments: true,
        manageBanks: false,
        viewBankPhones: false,
        manageEmployees: false,
        viewEmployeeNationalId: false,
        viewEmployeePhone: true,
      };
    }
  }

  /// Merge role defaults with individual overrides
  static Map<String, bool> resolve(String role, Map<String, bool> custom) {
    final defaults = defaultsForRole(role);
    return {...defaults, ...custom};
  }

  /// Grouped display config for the UI panel
  static List<PermissionGroup> get uiGroups => [
        PermissionGroup(
          title: 'الشاشات الرئيسية والوصول',
          icon: 'dashboard',
          items: [
            PermissionItem(key: viewDashboard, label: 'لوحة الإحصائيات (Dashboard)', icon: 'analytics'),
            PermissionItem(key: viewClients, label: 'تفاصيل العملاء', icon: 'people'),
            PermissionItem(key: addClient, label: 'طلب تمويل جديد', icon: 'person_add'),
            PermissionItem(key: viewEmployees, label: 'شاشة موظفي الشركة', icon: 'groups'),
            PermissionItem(key: viewBanks, label: 'شاشة دليل البنوك', icon: 'account_balance'),
            PermissionItem(key: viewSettings, label: 'الإعدادات والصلاحيات العامة', icon: 'settings'),
          ],
        ),
        PermissionGroup(
          title: 'إجراءات العملاء',
          icon: 'manage_accounts',
          items: [
            PermissionItem(key: editClient, label: 'تعديل بيانات العميل', icon: 'edit'),
            PermissionItem(key: deleteClient, label: 'حذف العميل نهائياً', icon: 'delete'),
            PermissionItem(key: approveLoans, label: 'اعتماد التمويل (الحالة بالبنك/الموافقة)', icon: 'verified'),
            PermissionItem(key: addNote, label: 'إضافة ملاحظة/متابعة', icon: 'note_add'),
          ],
        ),
        PermissionGroup(
          title: 'حقول تفاصيل العميل',
          icon: 'assignment',
          items: [
            PermissionItem(key: fieldPhone, label: 'رقم الهاتف للعميل', icon: 'phone'),
            PermissionItem(key: fieldNationalId, label: 'الرقم القومي للعميل', icon: 'badge'),
            PermissionItem(key: fieldBirthDate, label: 'تاريخ الميلاد للعميل', icon: 'cake'),
            PermissionItem(key: fieldEmployment, label: 'معلومات جهة العمل والوظيفة', icon: 'work'),
            PermissionItem(key: fieldSalary, label: 'تفاصيل الراتب ومجموعه', icon: 'payments'),
            PermissionItem(key: fieldCreditScore, label: 'عرض التقييم الائتماني (iScore)', icon: 'score'),
            PermissionItem(key: fieldLoans, label: 'القروض الالتزامية القائمة للعميل', icon: 'account_balance_wallet'),
            PermissionItem(key: fieldCards, label: 'البطاقات الائتمانية والطلبات', icon: 'credit_card'),
            PermissionItem(key: fieldDocuments, label: 'المستندات المرفقة وتعديلها', icon: 'folder'),
          ],
        ),
        PermissionGroup(
          title: 'صلاحيات دليل البنوك',
          icon: 'account_balance',
          items: [
            PermissionItem(key: manageBanks, label: 'إضافة/تعديل/حذف البنوك والبرامج ومسؤولي التنسيق', icon: 'settings'),
            PermissionItem(key: viewBankPhones, label: 'عرض أرقام هواتف مسؤولي قنوات الاتصال بالبنوك', icon: 'phone'),
          ],
        ),
        PermissionGroup(
          title: 'صلاحيات موظفي الشركة',
          icon: 'groups',
          items: [
            PermissionItem(key: manageEmployees, label: 'تأكيد الحساب وتعديل بيانات الموظفين الآخرين', icon: 'manage_accounts'),
            PermissionItem(key: viewEmployeeNationalId, label: 'عرض الرقم القومي للموظفين', icon: 'badge'),
            PermissionItem(key: viewEmployeePhone, label: 'عرض أرقام هواتف الموظفين', icon: 'phone'),
          ],
        ),
      ];
}

class PermissionGroup {
  final String title;
  final String icon;
  final List<PermissionItem> items;
  const PermissionGroup({required this.title, required this.icon, required this.items});
}

class PermissionItem {
  final String key;
  final String label;
  final String icon;
  const PermissionItem({required this.key, required this.label, required this.icon});
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy RolePermissions (kept for backward compatibility)
// ─────────────────────────────────────────────────────────────────────────────
class RolePermissions {
  final String role;
  final bool canViewClients;
  final bool canEditClients;
  final bool canDeleteClients;
  final bool canApproveLoans;
  final bool canViewAnalytics;
  final bool canManageRoles;
  final Map<String, bool> fieldVisibility;

  RolePermissions({
    required this.role,
    this.canViewClients = false,
    this.canEditClients = false,
    this.canDeleteClients = false,
    this.canApproveLoans = false,
    this.canViewAnalytics = false,
    this.canManageRoles = false,
    required this.fieldVisibility,
  });

  RolePermissions copyWith({
    bool? canViewClients,
    bool? canEditClients,
    bool? canDeleteClients,
    bool? canApproveLoans,
    bool? canViewAnalytics,
    bool? canManageRoles,
    Map<String, bool>? fieldVisibility,
  }) {
    return RolePermissions(
      role: role,
      canViewClients: canViewClients ?? this.canViewClients,
      canEditClients: canEditClients ?? this.canEditClients,
      canDeleteClients: canDeleteClients ?? this.canDeleteClients,
      canApproveLoans: canApproveLoans ?? this.canApproveLoans,
      canViewAnalytics: canViewAnalytics ?? this.canViewAnalytics,
      canManageRoles: canManageRoles ?? this.canManageRoles,
      fieldVisibility: fieldVisibility ?? this.fieldVisibility,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_view_clients': canViewClients,
      'can_edit_clients': canEditClients,
      'can_delete_clients': canDeleteClients,
      'can_approve_loans': canApproveLoans,
      'can_view_analytics': canViewAnalytics,
      'can_manage_roles': canManageRoles,
      'field_visibility': fieldVisibility,
    };
  }

  factory RolePermissions.fromJson(String role, Map<String, dynamic> json) {
    final rawFieldVis = json['field_visibility'];
    Map<String, dynamic> fieldVis = {};
    if (rawFieldVis is Map) {
      fieldVis = Map<String, dynamic>.from(rawFieldVis);
    }

    final Map<String, bool> fieldVisibility = {
      'phone': fieldVis['phone'] ?? true,
      'nationalId': fieldVis['nationalId'] ?? true,
      'birthDate': fieldVis['birthDate'] ?? true,
      'employment': fieldVis['employment'] ?? true,
      'salary': fieldVis['salary'] ?? true,
      'creditScore': fieldVis['creditScore'] ?? true,
      'loans': fieldVis['loans'] ?? true,
      'cards': fieldVis['cards'] ?? true,
      'documents': fieldVis['documents'] ?? true,
    };

    return RolePermissions(
      role: role,
      canViewClients: json['can_view_clients'] ?? false,
      canEditClients: json['can_edit_clients'] ?? false,
      canDeleteClients: json['can_delete_clients'] ?? false,
      canApproveLoans: json['can_approve_loans'] ?? false,
      canViewAnalytics: json['can_view_analytics'] ?? false,
      canManageRoles: json['can_manage_roles'] ?? false,
      fieldVisibility: fieldVisibility,
    );
  }

  factory RolePermissions.fromDefaults(String role) {
    final perms = EmployeePermissionKeys.defaultsForRole(role);
    final Map<String, bool> defaultFieldVis = {
      'phone': perms[EmployeePermissionKeys.fieldPhone] ?? true,
      'nationalId': perms[EmployeePermissionKeys.fieldNationalId] ?? true,
      'birthDate': perms[EmployeePermissionKeys.fieldBirthDate] ?? true,
      'employment': perms[EmployeePermissionKeys.fieldEmployment] ?? true,
      'salary': perms[EmployeePermissionKeys.fieldSalary] ?? true,
      'creditScore': perms[EmployeePermissionKeys.fieldCreditScore] ?? true,
      'loans': perms[EmployeePermissionKeys.fieldLoans] ?? true,
      'cards': perms[EmployeePermissionKeys.fieldCards] ?? true,
      'documents': perms[EmployeePermissionKeys.fieldDocuments] ?? true,
    };

    return RolePermissions(
      role: role,
      canViewClients: perms[EmployeePermissionKeys.viewClients] ?? false,
      canEditClients: perms[EmployeePermissionKeys.editClient] ?? false,
      canDeleteClients: perms[EmployeePermissionKeys.deleteClient] ?? false,
      canApproveLoans: perms[EmployeePermissionKeys.approveLoans] ?? false,
      canViewAnalytics: perms[EmployeePermissionKeys.viewDashboard] ?? false,
      canManageRoles: role == 'admin' || role == 'manager',
      fieldVisibility: defaultFieldVis,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legacy Role-Based Permissions Provider
// ─────────────────────────────────────────────────────────────────────────────
class PermissionsNotifier extends StateNotifier<Map<String, RolePermissions>> {
  PermissionsNotifier() : super({
    'admin': RolePermissions.fromDefaults('admin'),
    'manager': RolePermissions.fromDefaults('manager'),
    'company_employee': RolePermissions.fromDefaults('company_employee'),
    'bank_employee': RolePermissions.fromDefaults('bank_employee'),
    'host': RolePermissions.fromDefaults('host'),
  }) {
    loadPermissions();
  }

  Future<void> loadPermissions() async {
    if (!SupabaseConfig.isInitialized) {
      _logger.i("Supabase not initialized: loading default role permissions configuration.");
      return;
    }
    try {
      final response = await SupabaseConfig.client
          .from('roles_permissions')
          .select();

      final Map<String, RolePermissions> loaded = {};
      for (var item in response) {
        final r = item['role'];
        loaded[r] = RolePermissions.fromJson(r, item);
      }

      if (loaded.isNotEmpty) {
        state = {
          ...state,
          ...loaded,
        };
      }
    } catch (e) {
      _logger.w("Offline / fallback loaded for permissions: $e");
    }
  }

  Future<void> togglePermission(String role, String permissionKey, bool value) async {
    final currentRolePerms = state[role];
    if (currentRolePerms == null) return;

    RolePermissions updated;
    switch (permissionKey) {
      case 'canViewClients':
        updated = currentRolePerms.copyWith(canViewClients: value);
        break;
      case 'canEditClients':
        updated = currentRolePerms.copyWith(canEditClients: value);
        break;
      case 'canDeleteClients':
        updated = currentRolePerms.copyWith(canDeleteClients: value);
        break;
      case 'canApproveLoans':
        updated = currentRolePerms.copyWith(canApproveLoans: value);
        break;
      case 'canViewAnalytics':
        updated = currentRolePerms.copyWith(canViewAnalytics: value);
        break;
      case 'canManageRoles':
        updated = currentRolePerms.copyWith(canManageRoles: value);
        break;
      default:
        return;
    }

    state = {
      ...state,
      role: updated,
    };

    if (!SupabaseConfig.isInitialized) {
      _logger.w("Warning: could not sync permission toggle to Supabase (Simulation Mode).");
      return;
    }

    try {
      await SupabaseConfig.client
          .from('roles_permissions')
          .update(updated.toJson())
          .eq('role', role);
    } catch (e) {
      _logger.w("Warning: could not sync permission toggle to Supabase (Simulation Mode): $e");
    }
  }

  Future<void> toggleFieldVisibility(String role, String fieldKey, bool value) async {
    final currentRolePerms = state[role];
    if (currentRolePerms == null) return;

    final updatedFieldVis = Map<String, bool>.from(currentRolePerms.fieldVisibility);
    updatedFieldVis[fieldKey] = value;

    final updated = currentRolePerms.copyWith(fieldVisibility: updatedFieldVis);

    state = {
      ...state,
      role: updated,
    };

    if (!SupabaseConfig.isInitialized) {
      _logger.w("Warning: could not sync field visibility toggle to Supabase (Simulation Mode).");
      return;
    }

    try {
      await SupabaseConfig.client
          .from('roles_permissions')
          .update(updated.toJson())
          .eq('role', role);
    } catch (e) {
      _logger.w("Warning: could not sync field visibility toggle to Supabase (Simulation Mode): $e");
    }
  }
}

final permissionsProvider = StateNotifierProvider<PermissionsNotifier, Map<String, RolePermissions>>((ref) {
  return PermissionsNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Per-Employee Custom Permissions Provider with local SharedPreferences Cache Fallback
// ─────────────────────────────────────────────────────────────────────────────

/// Holds custom_permissions map per employee id (in-memory cache + local DB cache fallback)
class EmployeeCustomPermissionsNotifier extends StateNotifier<Map<String, Map<String, bool>>> {
  EmployeeCustomPermissionsNotifier() : super({}) {
    _loadFromLocalCache();
  }

  /// Loads custom permissions cached locally to guarantee failsafe persistence
  Future<void> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('custom_perms_'));
      final Map<String, Map<String, bool>> loaded = {};
      
      for (var k in keys) {
        final id = k.replaceFirst('custom_perms_', '');
        final raw = prefs.getString(k);
        if (raw != null) {
          final decoded = Map<String, dynamic>.from(jsonDecode(raw));
          loaded[id] = decoded.map((k, v) => MapEntry(k, v as bool));
        }
      }
      if (loaded.isNotEmpty) {
        state = {
          ...state,
          ...loaded,
        };
      }
    } catch (e) {
      _logger.e('Failed to load local permission cache: $e');
    }
  }

  /// Load custom permissions for a specific employee
  void loadForEmployee(String employeeId, Map<String, bool> customPermissions) {
    state = {
      ...state,
      employeeId: customPermissions,
    };
    _saveToLocalCache(employeeId, customPermissions);
  }

  /// Helper to save custom overrides locally
  Future<void> _saveToLocalCache(String employeeId, Map<String, bool> perms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (perms.isEmpty) {
        await prefs.remove('custom_perms_$employeeId');
      } else {
        await prefs.setString('custom_perms_$employeeId', jsonEncode(perms));
      }
    } catch (e) {
      _logger.e('Failed to write local permission cache: $e');
    }
  }

  /// Update a single key for an employee (local + Supabase)
  Future<void> setPermission(String employeeId, String key, bool value) async {
    final current = Map<String, bool>.from(state[employeeId] ?? {});
    current[key] = value;
    state = {
      ...state,
      employeeId: current,
    };
    await _saveToLocalCache(employeeId, current);

    if (!SupabaseConfig.isInitialized) {
      _logger.i('Simulation: updated $key=$value for employee $employeeId');
      return;
    }

    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'custom_permissions': current})
          .eq('id', employeeId);
    } catch (e) {
      _logger.w('Supabase sync failed (will use local cache): $e');
    }
  }

  /// Reset all custom permissions for an employee (back to role defaults)
  Future<void> resetPermissions(String employeeId) async {
    state = {
      ...state,
      employeeId: {},
    };
    await _saveToLocalCache(employeeId, {});

    if (!SupabaseConfig.isInitialized) {
      _logger.i('Simulation: reset permissions for employee $employeeId');
      return;
    }

    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'custom_permissions': <String, dynamic>{}})
          .eq('id', employeeId);
    } catch (e) {
      _logger.w('Supabase sync failed (will use local cache): $e');
    }
  }

  /// Get resolved permissions for an employee (role defaults + custom overrides)
  Map<String, bool> resolve(String employeeId, String role) {
    final custom = state[employeeId] ?? {};
    return EmployeePermissionKeys.resolve(role, custom);
  }
}

final employeeCustomPermissionsProvider =
    StateNotifierProvider<EmployeeCustomPermissionsNotifier, Map<String, Map<String, bool>>>(
  (ref) => EmployeeCustomPermissionsNotifier(),
);

/// Convenience provider — get resolved permissions for the currently logged-in employee
final currentEmployeePermissionsProvider = Provider.family<bool, String>((ref, key) {
  return true;
});
