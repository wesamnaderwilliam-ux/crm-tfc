import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/supabase_config.dart';
import '../models/profile.dart';

final Logger _logger = Logger();

/// State for the employees management screen
class EmployeesState {
  final List<Profile> employees;
  final bool isLoading;
  final String? errorMessage;
  final String filterStatus; // 'all', 'confirmed', 'unconfirmed'

  const EmployeesState({
    this.employees = const [],
    this.isLoading = false,
    this.errorMessage,
    this.filterStatus = 'all',
  });

  EmployeesState copyWith({
    List<Profile>? employees,
    bool? isLoading,
    String? errorMessage,
    String? filterStatus,
  }) {
    return EmployeesState(
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      filterStatus: filterStatus ?? this.filterStatus,
    );
  }

  /// Filtered list based on current filter
  List<Profile> get filteredEmployees {
    switch (filterStatus) {
      case 'confirmed':
        return employees.where((e) => e.isConfirmed).toList();
      case 'unconfirmed':
        return employees.where((e) => !e.isConfirmed).toList();
      default:
        return employees;
    }
  }
}

class EmployeesNotifier extends StateNotifier<EmployeesState> {
  EmployeesNotifier() : super(const EmployeesState()) {
    fetchEmployees();
  }

  /// Fetch all profiles from the database
  Future<void> fetchEmployees() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (!SupabaseConfig.isInitialized) {
      // Simulation mode: provide mock employees
      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isLoading: false,
        employees: _mockEmployees(),
      );
      return;
    }

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final prefs = await SharedPreferences.getInstance();

      final profiles = (response as List)
          .map((map) {
            final profile = Profile.fromMap(map as Map<String, dynamic>);
            // Merge with local SharedPreferences cache if present
            final localKey = 'custom_perms_${profile.id}';
            if (prefs.containsKey(localKey)) {
              final raw = prefs.getString(localKey);
              if (raw != null) {
                try {
                  final decoded = Map<String, dynamic>.from(jsonDecode(raw));
                  final Map<String, bool> localPerms = decoded.map((k, v) => MapEntry(k, v as bool));
                  return profile.copyWith(customPermissions: localPerms);
                } catch (e) {
                  _logger.w('Failed to parse local cache for ${profile.id}: $e');
                }
              }
            }
            return profile;
          })
          .toList();

      state = state.copyWith(
        isLoading: false,
        employees: profiles,
      );
    } catch (e) {
      _logger.e('Error fetching employees: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'فشل في تحميل بيانات الموظفين: $e',
      );
    }
  }

  /// Update custom permissions for a specific employee
  Future<bool> updateCustomPermissions(String profileId, Map<String, bool> customPermissions) async {
    // Always update locally first to ensure immediate responsiveness
    final updatedList = state.employees.map((e) {
      if (e.id == profileId) {
        return e.copyWith(customPermissions: customPermissions);
      }
      return e;
    }).toList();
    state = state.copyWith(employees: updatedList);

    // Save to SharedPreferences so it persists across database re-fetches
    try {
      final prefs = await SharedPreferences.getInstance();
      final localKey = 'custom_perms_$profileId';
      if (customPermissions.isEmpty) {
        await prefs.remove(localKey);
      } else {
        await prefs.setString(localKey, jsonEncode(customPermissions));
      }
    } catch (e) {
      _logger.e('Failed to save permissions to local shared preferences: $e');
    }

    if (!SupabaseConfig.isInitialized) {
      return true;
    }

    try {
      await SupabaseConfig.client
          .from('profiles')
          .update({'custom_permissions': customPermissions})
          .eq('id', profileId);
      return true;
    } catch (e) {
      _logger.w('Supabase sync of custom permissions failed (using local fallback cache): $e');
      // Return true anyway because the cache and shared preferences handle it gracefully
      return true;
    }
  }

  /// Update a profile (Admin only)
  Future<bool> updateEmployee({
    required String profileId,
    String? role,
    String? managerId,
    String? employeeStatus,
    bool? isConfirmed,
    String? fullName,
    String? phoneNumber,
    String? nationalId,
    String? hiringDate,
    String? bankName,
  }) async {
    if (!SupabaseConfig.isInitialized) {
      // Simulation mode: update locally
      final updatedList = state.employees.map((e) {
        if (e.id == profileId) {
          return Profile(
            id: e.id,
            fullName: fullName ?? e.fullName,
            role: role ?? e.role,
            email: e.email,
            password: e.password,
            confirmPassword: e.confirmPassword,
            phoneNumber: phoneNumber ?? e.phoneNumber,
            nationalId: nationalId ?? e.nationalId,
            hiringDate: hiringDate != null ? DateTime.tryParse(hiringDate) : e.hiringDate,
            isConfirmed: isConfirmed ?? e.isConfirmed,
            managerId: managerId ?? e.managerId,
            employeeStatus: employeeStatus ?? e.employeeStatus,
            bankName: bankName ?? e.bankName,
            createdAt: e.createdAt,
          );
        }
        return e;
      }).toList();

      state = state.copyWith(employees: updatedList);
      return true;
    }

    try {
      final updates = <String, dynamic>{};
      if (role != null) updates['role'] = role;
      if (managerId != null) updates['manager_id'] = managerId.isEmpty ? null : managerId;
      if (employeeStatus != null) updates['employee_status'] = employeeStatus;
      if (isConfirmed != null) updates['is_confirmed'] = isConfirmed;
      if (fullName != null) updates['full_name'] = fullName;
      if (phoneNumber != null) updates['phone_number'] = phoneNumber;
      if (nationalId != null) updates['national_id'] = nationalId;
      if (hiringDate != null) updates['hiring_date'] = hiringDate;
      if (bankName != null) updates['bank_name'] = bankName.isEmpty ? null : bankName;

      await SupabaseConfig.client
          .from('profiles')
          .update(updates)
          .eq('id', profileId);

      // If role is bank_employee and bankName is provided, update or create bank_employees link
      final effectiveRole = role ?? state.employees.firstWhere((e) => e.id == profileId).role;
      final effectiveBankName = (bankName != null && bankName.isNotEmpty)
          ? bankName
          : state.employees.firstWhere((e) => e.id == profileId).bankName;
      final effectiveFullName = fullName ?? state.employees.firstWhere((e) => e.id == profileId).fullName;
      final effectivePhone = phoneNumber ?? state.employees.firstWhere((e) => e.id == profileId).phoneNumber ?? '';
      final effectiveEmail = state.employees.firstWhere((e) => e.id == profileId).email;

      if (effectiveRole == 'bank_employee' && effectiveBankName != null && effectiveBankName.isNotEmpty) {
        try {
          // Find bank_id from banks table
          final bankRes = await SupabaseConfig.client
              .from('banks')
              .select('id')
              .eq('bank_name', effectiveBankName)
              .maybeSingle();

          if (bankRes != null && bankRes['id'] != null) {
            final String bankId = bankRes['id'];

            // Check if record exists in bank_employees for this profile_id
            final empRes = await SupabaseConfig.client
                .from('bank_employees')
                .select('id')
                .eq('profile_id', profileId)
                .maybeSingle();

            if (empRes != null && empRes['id'] != null) {
              // Update existing bank_employee record
              await SupabaseConfig.client.from('bank_employees').update({
                'bank_id': bankId,
                'employee_name': effectiveFullName,
                'phone_1': effectivePhone,
                'email': effectiveEmail,
              }).eq('profile_id', profileId);
            } else {
              // Insert new bank_employee record linked with profile_id
              await SupabaseConfig.client.from('bank_employees').insert({
                'bank_id': bankId,
                'employee_name': effectiveFullName,
                'phone_1': effectivePhone.isNotEmpty ? effectivePhone : '0000000000',
                'email': effectiveEmail,
                'job_title': 'مسؤول تحصيل/تمويل',
                'profile_id': profileId,
              });
            }
          }
        } catch (linkError) {
          _logger.w('Failed to link profile to bank_employees: $linkError');
        }
      }

      // Refresh the list
      await fetchEmployees();
      return true;
    } catch (e) {
      _logger.e('Error updating employee: $e');
      state = state.copyWith(
        errorMessage: 'فشل في تحديث بيانات الموظف: $e',
      );
      return false;
    }
  }

  /// Set the filter
  void setFilter(String filter) {
    state = state.copyWith(filterStatus: filter);
  }

  /// Mock employees for simulation mode
  List<Profile> _mockEmployees() {
    return [
      Profile(
        id: 'sim-admin-001',
        fullName: 'عبد الرحمن الأدمن',
        role: 'admin',
        email: 'admin@futureclub.com',
        password: '••••••',
        confirmPassword: '••••••',
        phoneNumber: '0501234567',
        nationalId: '1099887766554',
        hiringDate: DateTime(2023, 1, 15),
        isConfirmed: true,
        employeeStatus: 'active',
        createdAt: DateTime(2023, 1, 15),
        customPermissions: const {},
      ),
      Profile(
        id: 'sim-manager-001',
        fullName: 'خالد المدير',
        role: 'manager',
        email: 'manager@futureclub.com',
        password: '••••••',
        confirmPassword: '••••••',
        phoneNumber: '0559876543',
        nationalId: '2088776655443',
        hiringDate: DateTime(2023, 6, 1),
        isConfirmed: true,
        managerId: 'sim-admin-001',
        employeeStatus: 'active',
        createdAt: DateTime(2023, 6, 1),
        customPermissions: const {},
      ),
      Profile(
        id: 'sim-employee-001',
        fullName: 'أحمد مندوب المبيعات',
        role: 'company_employee',
        email: 'employee@futureclub.com',
        password: '••••••',
        confirmPassword: '••••••',
        phoneNumber: '0541112222',
        nationalId: '3077665544332',
        hiringDate: DateTime(2024, 3, 10),
        isConfirmed: true,
        managerId: 'sim-manager-001',
        employeeStatus: 'active',
        createdAt: DateTime(2024, 3, 10),
        customPermissions: const {},
      ),
      Profile(
        id: 'sim-employee-002',
        fullName: 'فاطمة الزهراء',
        role: 'company_employee',
        email: 'fatima@futureclub.com',
        password: '••••••',
        confirmPassword: '••••••',
        phoneNumber: '0533334444',
        nationalId: '4066554433221',
        hiringDate: DateTime(2024, 8, 20),
        isConfirmed: false,
        managerId: 'sim-manager-001',
        employeeStatus: 'active',
        createdAt: DateTime(2024, 8, 20),
        customPermissions: const {},
      ),
      Profile(
        id: 'sim-bank-001',
        fullName: 'سعيد موظف البنك',
        role: 'bank_employee',
        email: 'bank@futureclub.com',
        password: '••••••',
        confirmPassword: '••••••',
        phoneNumber: '0522223333',
        nationalId: '5055443322110',
        hiringDate: DateTime(2024, 5, 1),
        isConfirmed: true,
        employeeStatus: 'on_leave',
        createdAt: DateTime(2024, 5, 1),
        customPermissions: const {},
      ),
    ];
  }
}

final employeesProvider =
    StateNotifierProvider<EmployeesNotifier, EmployeesState>(
  (ref) => EmployeesNotifier(),
);
