import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/turso_client.dart';

class BanksRepository {
  final _supabase = Supabase.instance.client;

  // In-memory cache to minimize Supabase/Turso calls
  List<Map<String, dynamic>>? _cachedBanks;
  DateTime? _banksCacheTime;
  static const _cacheDuration = Duration(minutes: 30);

  void invalidateCache() {
    _cachedBanks = null;
    _banksCacheTime = null;
  }

  // 1. Fetch all banks (with nested programs and employees) from Turso (fast edge cache), with Supabase fallback
  Future<List<Map<String, dynamic>>> getAllBanks({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedBanks != null &&
        _banksCacheTime != null &&
        DateTime.now().difference(_banksCacheTime!) < _cacheDuration) {
      return _cachedBanks!;
    }

    try {
      // 1. Try fetching from Turso first (Edge SQLite - 0 Supabase Egress)
      final tursoBanks = await TursoClient.query('SELECT id, bank_name FROM banks ORDER BY bank_name ASC');
      if (tursoBanks.isNotEmpty) {
        final tursoPrograms = await TursoClient.query('''
          SELECT bpd.id, bpd.bank_id, bpd.program_id, bpd.description, bpd.interest_rate, bpd.max_loan_amount, cp.program_name
          FROM bank_programs_details bpd
          LEFT JOIN core_programs cp ON bpd.program_id = cp.id
        ''');

        final tursoEmployees = await TursoClient.query('''
          SELECT id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes
          FROM bank_employees
          ORDER BY employee_name ASC
        ''');

        final List<Map<String, dynamic>> structured = [];
        for (final b in tursoBanks) {
          final bankId = b['id']?.toString() ?? '';
          final matchingPrograms = tursoPrograms
              .where((p) => p['bank_id']?.toString() == bankId)
              .map((p) => {
                    'id': p['id'],
                    'program_id': p['program_id'],
                    'description': p['description'],
                    'interest_rate': p['interest_rate'],
                    'max_loan_amount': p['max_loan_amount'],
                    'core_programs': {'program_name': p['program_name'] ?? ''},
                  })
              .toList();

          final matchingEmployees = tursoEmployees
              .where((e) => e['bank_id']?.toString() == bankId)
              .toList();

          structured.add({
            'id': b['id'],
            'bank_name': b['bank_name'],
            'bank_programs_details': matchingPrograms,
            'bank_employees': matchingEmployees,
          });
        }

        _cachedBanks = structured;
        _banksCacheTime = DateTime.now();
        return _cachedBanks!;
      }
    } catch (_) {
      // Fallback to Supabase
    }

    // Fallback: Supabase direct query
    final data = await _supabase
        .from('banks')
        .select('''
          id, 
          bank_name,
          bank_programs_details (
            id, description, interest_rate, max_loan_amount, program_id,
            core_programs ( program_name )
          ),
          bank_employees (
            id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes
          )
        ''')
        .order('bank_name');

    _cachedBanks = List<Map<String, dynamic>>.from(data);
    _banksCacheTime = DateTime.now();
    return _cachedBanks!;
  }

  // 2. Fetch programs for a specific bank (with core program name)
  Future<List<Map<String, dynamic>>> getProgramsByBank(String bankId) async {
    return await _supabase.from('bank_programs_details').select('''
          id, description, interest_rate, max_loan_amount, program_id,
          core_programs ( program_name )
        ''').eq('bank_id', bankId);
  }

  // 3. Fetch employees for a specific bank
  Future<List<Map<String, dynamic>>> getEmployeesByBank(String bankId) async {
    return await _supabase
        .from('bank_employees')
        .select('id, bank_id, employee_name, phone_1, phone_2, job_title, email, notes')
        .eq('bank_id', bankId)
        .order('employee_name');
  }

  // -------------------------------------------------------------------------
  // BANK CRUD
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> createBank(String bankName) async {
    final res = await _supabase
        .from('banks')
        .insert({'bank_name': bankName})
        .select('id, bank_name')
        .single();
    invalidateCache();
    return Map<String, dynamic>.from(res);
  }

  Future<void> updateBank(String id, String bankName) async {
    await _supabase.from('banks').update({'bank_name': bankName}).eq('id', id);
    invalidateCache();
  }

  Future<void> deleteBank(String id) async {
    // Delete linked child records first to ensure clean cascade across schema constraints
    await _supabase.from('bank_employees').delete().eq('bank_id', id);
    await _supabase.from('bank_programs_details').delete().eq('bank_id', id);
    await _supabase.from('banks').delete().eq('id', id);
    invalidateCache();
  }

  // -------------------------------------------------------------------------
  // CORE PROGRAMS CRUD
  // -------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllCorePrograms() async {
    try {
      final tursoList = await TursoClient.query('SELECT id, program_name FROM core_programs ORDER BY program_name ASC');
      if (tursoList.isNotEmpty) {
        return tursoList;
      }
    } catch (_) {}

    return await _supabase
        .from('core_programs')
        .select('id, program_name')
        .order('program_name');
  }

  Future<Map<String, dynamic>> createCoreProgram(String programName) async {
    final result = await _supabase
        .from('core_programs')
        .insert({'program_name': programName})
        .select()
        .single();
    return Map<String, dynamic>.from(result);
  }

  // -------------------------------------------------------------------------
  // BANK PROGRAM DETAILS CRUD
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> addProgramToBank({
    required String bankId,
    required String coreProgramId,
    required String description,
    required double interestRate,
    required double maxLoanAmount,
  }) async {
    final res = await _supabase.from('bank_programs_details').insert({
      'bank_id': bankId,
      'program_id': coreProgramId,
      'description': description,
      'interest_rate': interestRate,
      'max_loan_amount': maxLoanAmount,
    }).select().single();
    return Map<String, dynamic>.from(res);
  }

  Future<void> updateBankProgram({
    required String id,
    required String description,
    required double interestRate,
    required double maxLoanAmount,
  }) async {
    await _supabase.from('bank_programs_details').update({
      'description': description,
      'interest_rate': interestRate,
      'max_loan_amount': maxLoanAmount,
    }).eq('id', id);
  }

  Future<void> deleteBankProgram(String id) async {
    await _supabase.from('bank_programs_details').delete().eq('id', id);
  }

  // -------------------------------------------------------------------------
  // BANK EMPLOYEES CRUD
  // -------------------------------------------------------------------------
  Future<Map<String, dynamic>> addEmployee({
    required String bankId,
    required String name,
    required String phone1,
    String? phone2,
    String? jobTitle,
    String? email,
    String? notes,
    String? profileId,
  }) async {
    final res = await _supabase.from('bank_employees').insert({
      'bank_id': bankId,
      'employee_name': name,
      'phone_1': phone1,
      'phone_2': (phone2 != null && phone2.trim().isNotEmpty) ? phone2 : null,
      'job_title': (jobTitle != null && jobTitle.trim().isNotEmpty) ? jobTitle : null,
      'email': (email != null && email.trim().isNotEmpty) ? email : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes : null,
    }).select().single();
    return Map<String, dynamic>.from(res);
  }

  Future<void> updateEmployee({
    required String id,
    required String name,
    required String phone1,
    String? bankId,
    String? phone2,
    String? jobTitle,
    String? email,
    String? notes,
    String? profileId,
  }) async {
    await _supabase.from('bank_employees').update({
      if (bankId != null && bankId.trim().isNotEmpty) 'bank_id': bankId,
      'employee_name': name,
      'phone_1': phone1,
      'phone_2': (phone2 != null && phone2.trim().isNotEmpty) ? phone2 : null,
      'job_title': (jobTitle != null && jobTitle.trim().isNotEmpty) ? jobTitle : null,
      'email': (email != null && email.trim().isNotEmpty) ? email : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes : null,
    }).eq('id', id);
  }

  Future<void> deleteEmployee(String id) async {
    await _supabase.from('bank_employees').delete().eq('id', id);
  }

  // -------------------------------------------------------------------------
  // DISTRIBUTION: Fetch banks that offer a specific core program
  // -------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getBanksByProgram(
      String coreProgramId) async {
    // Query bank_programs_details to find banks linked to a core_program,
    // then join the bank name.
    return await _supabase.from('bank_programs_details').select('''
          id,
          bank_id,
          description,
          interest_rate,
          max_loan_amount,
          banks ( id, bank_name ),
          core_programs ( id, program_name )
        ''').eq('program_id', coreProgramId);
  }

  // -------------------------------------------------------------------------
  // SEARCH: Unified search across banks, programs, and employees
  // -------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> searchAll(String query, {bool isAdmin = false}) async {
    final results = <Map<String, dynamic>>[];
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return results;

    // Search banks
    final banks = await _supabase
        .from('banks')
        .select('id, bank_name')
        .ilike('bank_name', '%$q%')
        .limit(10);
    for (var b in banks) {
      results.add({'type': 'bank', ...b});
    }

    // Search core programs
    final programs = await _supabase
        .from('core_programs')
        .select('id, program_name')
        .ilike('program_name', '%$q%')
        .limit(10);
    for (var p in programs) {
      results.add({'type': 'program', ...p});
    }

    // Search employees by name or phone - Only for Admins/Managers
    if (isAdmin) {
      final employees = await _supabase
          .from('bank_employees')
          .select('id, employee_name, phone_1, phone_2, bank_id, banks ( bank_name )')
          .or('employee_name.ilike.%$q%,phone_1.ilike.%$q%,phone_2.ilike.%$q%')
          .limit(10);
      for (var e in employees) {
        results.add({'type': 'employee', ...e});
      }
    }

    return results;
  }
}
