// ignore_for_file: avoid_print
// This is a temporary scratch verification script, NOT production code.
// Run via: flutter run -t test_supabase.dart -d chrome

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);

// ------------------------------------------------------------
// Helper: Ensure roles_permissions table is populated.
Future<void> _seedPermissions(SupabaseClient client) async {
  try {
    final existing =
        await client.from('roles_permissions').select('role').limit(1);
    if (existing.isEmpty) {
      await client.from('roles_permissions').insert([
        {
          'role': 'admin',
          'can_view_clients': true,
          'can_edit_clients': true,
          'can_delete_clients': true,
          'can_approve_loans': true,
          'can_view_analytics': true,
          'can_manage_roles': true,
        },
        {
          'role': 'manager',
          'can_view_clients': true,
          'can_edit_clients': true,
          'can_delete_clients': true,
          'can_approve_loans': true,
          'can_view_analytics': true,
          'can_manage_roles': true,
        },
        {
          'role': 'company_employee',
          'can_view_clients': true,
          'can_edit_clients': true,
          'can_delete_clients': false,
          'can_approve_loans': false,
          'can_view_analytics': false,
          'can_manage_roles': false,
        },
        {
          'role': 'bank_employee',
          'can_view_clients': true,
          'can_edit_clients': false,
          'can_delete_clients': false,
          'can_approve_loans': true,
          'can_view_analytics': true,
          'can_manage_roles': false,
        },
      ]);
      _log.i('✅ Seeded roles_permissions table');
    } else {
      _log.i('✅ roles_permissions already contains data');
    }
  } catch (e) {
    _log.e('❌ Error seeding permissions: $e');
  }
}

// ------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = "https://fwzarykokwtczxuepczr.supabase.co";
  const anonKey = "sb_publishable_Iy4Attl0mXEm8r5f6QnNhA_-lznBmUw";

  const adminEmail = 'wezonader@gmail.com';
  const adminPassword = 'tfcwn14';
  // ────────────────────────────────────────────────────────────────────────────

  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  _log.i('✅ Supabase initialized successfully');

  // 1️⃣ تسجيل دخول بحساب المدير
  try {
    final res = await client.auth.signInWithPassword(
      email: adminEmail,
      password: adminPassword,
    );
    _log.i('🔐 Logged in as: ${res.user?.email} (ID: ${res.user?.id})');
  } catch (e) {
    _log.w(
        '⚠️  Login failed – will test as anonymous (RLS may block reads): $e');
  }
  await _seedPermissions(client);

  // 2️⃣ التحقق من جدول clients والأعمدة الجديدة
  _log.i('\n📋 Testing: clients table');
  try {
    final rows = await client
        .from('clients')
        .select(
          'id, full_name, phone_number, secondary_phone_number, national_id, salary_bank_details, cash_salary_amount',
        )
        .limit(2);
    _log.i('✅ clients OK – ${rows.length} row(s) returned');
    for (final r in rows) {
      _log.d(
          '  └─ ${r['full_name']} | secondary: ${r['secondary_phone_number']} | cash_salary: ${r['cash_salary_amount']}');
    }
  } catch (e) {
    _log.e('❌ clients ERROR: $e');
  }

  // 3️⃣ التحقق من جدول credit_cards_requests والعمود notes
  _log.i('\n💳 Testing: credit_cards_requests table');
  try {
    final rows = await client
        .from('credit_cards_requests')
        .select('id, bank_name, value, type, notes')
        .limit(2);
    _log.i('✅ credit_cards_requests OK – ${rows.length} row(s)');
    for (final r in rows) {
      _log.d(
          '  └─ ${r['bank_name']} | type: ${r['type']} | notes: ${r['notes']}');
    }
  } catch (e) {
    _log.e('❌ credit_cards_requests ERROR: $e');
  }

  // 4️⃣ التحقق من جدول interaction_history والعمود created_by_name
  _log.i('\n📜 Testing: interaction_history table');
  try {
    final rows = await client
        .from('interaction_history')
        .select('id, action_type, notes, created_by_name')
        .limit(2);
    _log.i('✅ interaction_history OK – ${rows.length} row(s)');
    for (final r in rows) {
      _log.d('  └─ action: ${r['action_type']} | by: ${r['created_by_name']}');
    }
  } catch (e) {
    _log.e('❌ interaction_history ERROR: $e');
  }

  // 5️⃣ اختبار إدراج سجل تفاعل بـ created_by_name
  _log.i('\n📝 Testing: insert into interaction_history');
  try {
    final currentClientId = await _getAnyClientId(client);
    if (currentClientId != null) {
      await client.from('interaction_history').insert({
        'client_id': currentClientId,
        'action_type': 'فحص المخطط - اختبار',
        'notes': 'تأكيد وجود عمود created_by_name.',
        'created_by': client.auth.currentUser?.id,
        'created_by_name': 'مدير النظام',
      });
      _log.i('✅ interaction_history INSERT with created_by_name successful!');
    } else {
      _log.w(
          '⚠️  No client found to attach test interaction – skipping insert test.');
    }
  } catch (e) {
    _log.e('❌ interaction_history INSERT ERROR: $e');
  }

  _log.i('\n🎉 All schema verification tests completed.');
}

/// Helper: returns the id of the first available client.
Future<String?> _getAnyClientId(SupabaseClient client) async {
  try {
    final rows = await client.from('clients').select('id').limit(1);
    if (rows.isNotEmpty) return rows[0]['id'] as String;
  } catch (_) {}
  return null;
}
