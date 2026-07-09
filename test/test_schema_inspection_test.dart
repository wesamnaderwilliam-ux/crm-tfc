// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tfc_financial_crm/providers/supabase_provider.dart';

void main() {
  test('Select all from tables', () async {
    await dotenv.load(fileName: '.env');
    final container = ProviderContainer();
    final client = container.read(supabaseProvider);
    await client.auth.signInWithPassword(email: 'wezonader@gmail.com', password: 'tfcwn14');

    // credit_cards_requests - select *
    print("=== CREDIT_CARDS_REQUESTS ===");
    try {
      final res = await client.from('credit_cards_requests').select().limit(0);
      print("CARDS: count=${res.length}");
      // Try a dummy select to discover column names
      try {
        await client.from('credit_cards_requests').select('fake_col_xyz').limit(1);
      } catch (e2) {
        print("CARDS hint: $e2");
      }
    } catch (e) {
      print("CARDS ERROR: $e");
    }

    // interaction_history - select *
    print("=== INTERACTION_HISTORY ===");
    try {
      final res = await client.from('interaction_history').select().limit(0);
      print("HISTORY: count=${res.length}");
      try {
        await client.from('interaction_history').select('fake_col_xyz').limit(1);
      } catch (e2) {
        print("HISTORY hint: $e2");
      }
    } catch (e) {
      print("HISTORY ERROR: $e");
    }

    // roles_permissions
    print("=== ROLES_PERMISSIONS ===");
    try {
      await client.from('roles_permissions').select('fake_col_xyz').limit(1);
    } catch (e) {
      print("ROLES hint: $e");
    }
  });
}
