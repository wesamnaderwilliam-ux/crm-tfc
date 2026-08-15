import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/supabase_config.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

// SharedPreferences keys for pending Google OAuth registration metadata
const String _kPendingFullName = 'pending_google_full_name';
const String _kPendingRole = 'pending_google_role';

const String _kPendingBankName = 'pending_google_bank_name';

class AuthState {
  final User? user;
  final String role; // admin, manager, company_employee, bank_employee
  final String fullName;
  final String? bankName;
  final bool isLoading;
  final bool isAuthenticated;
  final bool isConfirmed;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.role = 'company_employee',
    this.fullName = '',
    this.bankName,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.isConfirmed = false,
    this.errorMessage,
  });

  AuthState copyWith({
    User? user,
    String? role,
    String? fullName,
    String? bankName,
    bool? isLoading,
    bool? isAuthenticated,
    bool? isConfirmed,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      bankName: bankName ?? this.bankName,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier() : super(const AuthState()) {
    _initialize();
  }

  void _initialize() {
    _checkCurrentSession();
    _listenToAuthChanges();
  }

  /// Listen to Supabase auth state changes (handles OAuth redirections, token refresh, etc.)
  void _listenToAuthChanges() {
    if (!SupabaseConfig.isInitialized) return;

    SupabaseConfig.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      final session = data.session;

      _logger.i('Auth event: $event');

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Check for pending Google OAuth profile data
        await _syncPendingGoogleProfile(session.user);
        await _fetchProfile(session.user);
      } else if (event == AuthChangeEvent.signedOut) {
        state = const AuthState();
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        // Silently refresh profile on token refresh
        await _fetchProfile(session.user);
      }
    });
  }

  void _checkCurrentSession() {
    if (!SupabaseConfig.isInitialized) {
      _logger.i("Supabase not initialized: starting in local simulation mode.");
      return;
    }
    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session != null) {
        _fetchProfile(session.user);
      }
    } catch (e) {
      _logger.e("No Supabase session: $e");
    }
  }

  /// Sync pending profile data saved during Google OAuth registration
  Future<void> _syncPendingGoogleProfile(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingName = prefs.getString(_kPendingFullName);
      final pendingRole = prefs.getString(_kPendingRole);
      final pendingBank = prefs.getString(_kPendingBankName);

      if (pendingName != null && pendingRole != null) {
        _logger.i('Syncing pending Google profile: name=$pendingName, role=$pendingRole, bank=$pendingBank');

        // Upsert into profiles table
        await SupabaseConfig.client.from('profiles').upsert({
          'id': user.id,
          'full_name': pendingName,
          'role': pendingRole,
          if (pendingBank != null && pendingBank.isNotEmpty) 'bank_name': pendingBank,
        });

        // Clear pending data
        await prefs.remove(_kPendingFullName);
        await prefs.remove(_kPendingRole);
        await prefs.remove(_kPendingBankName);

        _logger.i('Pending Google profile synced successfully.');
      }
    } catch (e) {
      _logger.e('Error syncing pending Google profile: $e');
    }
  }

  Future<void> _fetchProfile(User user) async {
    if (!SupabaseConfig.isInitialized) return;
    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select('full_name, role, bank_name, is_confirmed')
          .eq('id', user.id)
          .single();

      state = state.copyWith(
        user: user,
        role: response['role'] ?? 'company_employee',
        fullName: response['full_name'] ?? 'مستخدم',
        bankName: response['bank_name'],
        isConfirmed: response['is_confirmed'] ?? false,
        isAuthenticated: true,
        isLoading: false,
      );
    } catch (e) {
      _logger.e('Error fetching profile: $e');
      // Fallback for simulation if profile query fails
      state = state.copyWith(
        user: user,
        role: 'company_employee',
        fullName: user.userMetadata?['full_name'] ?? 'مستخدم جديد',
        bankName: user.userMetadata?['bank_name'],
        isConfirmed: false,
        isAuthenticated: true,
        isLoading: false,
      );
    }
  }

  /// Upsert profile as a fallback in case the database trigger doesn't fire
  /// Includes password and confirm_password fields as requested.
  Future<void> _upsertProfileFallback(
    User user, 
    String fullName, 
    String role, {
    required String password, 
    required String confirmPassword,
    String? bankName,
    String? phoneNumber,
    String? nationalId,
    String? hiringDate,
  }) async {
    if (!SupabaseConfig.isInitialized) return;
    try {
      await SupabaseConfig.client.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'role': role,
        if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
        'email': user.email,
        'password': password,
        'confirm_password': confirmPassword,
        'phone_number': phoneNumber,
        'national_id': nationalId,
        'hiring_date': hiringDate,
        'is_confirmed': (role == 'admin'),
      });
      _logger.i('Profile upserted as fallback for user ${user.id}');
    } catch (e) {
      _logger.e('Profile upsert fallback failed: $e');
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    // Only use simulation login when Supabase is NOT initialized
    if (!SupabaseConfig.isInitialized) {
      // Dynamic simulation login for local preview
      if ((email.contains("admin") || email == "wezonader@gmail.com") && password == "123456") {
        await Future.delayed(const Duration(milliseconds: 1200));
        state = const AuthState(
          role: 'admin',
          fullName: 'وسام نادر وليم',
          isAuthenticated: true,
          isConfirmed: true,
          isLoading: false,
        );
        return true;
      } else if (email.contains("manager") && password == "123456") {
        await Future.delayed(const Duration(milliseconds: 1200));
        state = const AuthState(
          role: 'manager',
          fullName: 'المدير المسؤول',
          isAuthenticated: true,
          isConfirmed: true,
          isLoading: false,
        );
        return true;
      } else if (email.contains("bank") && password == "123456") {
        await Future.delayed(const Duration(milliseconds: 1200));
        state = const AuthState(
          role: 'bank_employee',
          fullName: 'موظف البنك الأهلي',
          bankName: 'البنك الأهلي المصري',
          isAuthenticated: true,
          isConfirmed: true,
          isLoading: false,
        );
        return true;
      } else if (email.contains("employee") && password == "123456") {
        await Future.delayed(const Duration(milliseconds: 1200));
        state = const AuthState(
          role: 'company_employee',
          fullName: 'أحمد مندوب المبيعات',
          isAuthenticated: true,
          isConfirmed: true,
          isLoading: false,
        );
        return true;
      }

      await Future.delayed(const Duration(milliseconds: 800));
      state = state.copyWith(
        isLoading: false,
        errorMessage: "التطبيق يعمل حالياً في وضع التجربة غير المتصل بقاعدة البيانات. الرجاء استخدام الحسابات التجريبية.",
      );
      return false;
    }

    // Supabase Auth attempt
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        await _fetchProfile(response.user!);
        return true;
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "فشل تسجيل الدخول: ${e.message}",
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "فشل تسجيل الدخول. يرجى التحقق من البيانات.",
      );
    }
    return false;
  }

  /// Sign up with email/password including full name and role metadata
  Future<bool> signUp({
    required String email,
    required String password,
    required String confirmPassword,
    required String fullName,
    required String role,
    String? bankName,
    String? phoneNumber,
    String? nationalId,
    String? hiringDate,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (!SupabaseConfig.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 800));
      state = state.copyWith(
        isLoading: false,
        errorMessage: "التطبيق يعمل حالياً في وضع التجربة غير المتصل بقاعدة البيانات. لا يمكن إنشاء حسابات جديدة.",
      );
      return false;
    }

    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'role': role,
          if (bankName != null && bankName.isNotEmpty) 'bank_name': bankName,
          'password': password,
          'confirm_password': confirmPassword,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
          if (nationalId != null && nationalId.isNotEmpty) 'national_id': nationalId,
          if (hiringDate != null && hiringDate.isNotEmpty) 'hiring_date': hiringDate,
        },
      );
      
      if (response.user != null) {
        // Upsert profile as fallback (in case the DB trigger doesn't fire or is delayed)
        await _upsertProfileFallback(
          response.user!,
          fullName,
          role,
          password: password,
          confirmPassword: confirmPassword,
          bankName: bankName,
          phoneNumber: phoneNumber,
          nationalId: nationalId,
          hiringDate: hiringDate,
        );

        // If the session is automatically created (email confirmation is off)
        final session = SupabaseConfig.client.auth.currentSession;
        if (session != null) {
          await _fetchProfile(response.user!);
        } else {
          state = state.copyWith(
            isLoading: false,
            errorMessage: null,
          );
        }
        return true;
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "حدث خطأ غير متوقع: $e",
      );
    }
    return false;
  }

  /// Sign in with Google OAuth. Stores pending profile data locally for post-redirect sync.
  Future<bool> signInWithGoogle({
    required String fullName,
    required String role,
    String? bankName,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "التطبيق يعمل حالياً في وضع التجربة. تسجيل Google غير متاح.",
      );
      return false;
    }

    try {
      // Save pending profile data to shared preferences before OAuth redirect
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPendingFullName, fullName);
      await prefs.setString(_kPendingRole, role);
      if (bankName != null && bankName.isNotEmpty) {
        await prefs.setString(_kPendingBankName, bankName);
      }

      _logger.i('Saved pending profile: name=$fullName, role=$role');

      // Launch Google OAuth flow with clean redirect URL for Web/Mobile
      final String origin = Uri.base.origin;
      final String path = Uri.base.path;
      final String webRedirectTo = (origin.contains('localhost') || origin.contains('127.0.0.1'))
          ? Uri.base.toString()
          : '$origin$path';
      
      _logger.i('Launching Google OAuth with redirectTo: $webRedirectTo');
      
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: webRedirectTo,
      );

      // The auth state change listener will handle the rest after redirect
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "خطأ في تسجيل Google: ${e.message}",
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "فشل تسجيل الدخول بواسطة Google: $e",
      );
    }
    return false;
  }

  /// Sign in with Google for existing users (Login mode) — no name/role needed
  Future<bool> signInWithGoogleOnly() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (!SupabaseConfig.isInitialized) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "التطبيق يعمل حالياً في وضع التجربة. تسجيل Google غير متاح.",
      );
      return false;
    }

    try {
      final String origin = Uri.base.origin;
      final String path = Uri.base.path;
      final String webRedirectTo = (origin.contains('localhost') || origin.contains('127.0.0.1'))
          ? Uri.base.toString()
          : '$origin$path';

      _logger.i('Google Sign-In (login mode) with redirectTo: $webRedirectTo');

      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: webRedirectTo,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "خطأ في تسجيل الدخول بواسطة Google: ${e.message}",
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "فشل تسجيل الدخول بواسطة Google: $e",
      );
    }
    return false;
  }

  /// Update user password (works for both email/password users and Google OAuth users)
  Future<bool> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (!SupabaseConfig.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 600));
      state = state.copyWith(
        isLoading: false,
        errorMessage: "التطبيق يعمل في الوضع التجريبي Local Mode. تعذّر حفظ كلمة المرور.",
      );
      return false;
    }

    try {
      final response = await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        // Also update profiles table fallback password field
        try {
          await SupabaseConfig.client.from('profiles').update({
            'password': newPassword,
            'confirm_password': newPassword,
          }).eq('id', response.user!.id);
        } catch (_) {}

        state = state.copyWith(
          user: response.user,
          isLoading: false,
          errorMessage: null,
        );
        return true;
      }
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "فشل تحديث كلمة المرور: ${e.message}",
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: "حدث خطأ أثناء تغيير كلمة المرور: $e",
      );
    }
    return false;
  }

  Future<void> signOut() async {
    if (SupabaseConfig.isInitialized) {
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}
    }
    state = const AuthState();
  }

  /// Re-fetch the current user's profile to check for updated confirmation status
  Future<void> refreshProfile() async {
    if (!SupabaseConfig.isInitialized) return;
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      await _fetchProfile(session.user);
    }
  }

  // Helper method for the user to swap active roles instantly in the settings UI to test different interfaces
  void simulationChangeRole(String newRole) {
    String name = '';
    if (newRole == 'admin') name = 'المدير العام (الأدمن)';
    if (newRole == 'manager') name = 'المدير المسؤول';
    if (newRole == 'company_employee') name = 'موظف الشركة (المندوب)';
    if (newRole == 'bank_employee') name = 'موظف البنك';
    if (newRole == 'host') name = 'المضيف (Host)';
    
    state = state.copyWith(
      role: newRole,
      fullName: '$name (تجريبي)',
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
