import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tfc_financial_crm/providers/supabase_provider.dart'; // actual package name

import 'package:logger/logger.dart';

final _log = Logger();

void main() {
  test('Verify Supabase connection and schema updates', () async {
    // Use Riverpod provider that already configures Supabase with MCP endpoint
    // Load environment variables from .env
    await dotenv.load(fileName: '.env');
    final container = ProviderContainer();
    final client = container.read(supabaseProvider);
    _log.i("Supabase client initialized via provider");

    try {
      await client.auth.signInWithPassword(
        email: 'wezonader@gmail.com',
        password: 'tfcwn14',
      );
      _log.i("Logged in successfully as admin");
    } catch (e) {
      _log.w("Warning: Could not log in: $e");
    }

    try {
    _log.i("\n--- Testing Select on clients table ---");
      final clients = await client.from('clients').select('''
        id,
        full_name,
        phone_number,
        secondary_phone_number,
        national_id,
        salary_bank_details,
        cash_salary_amount
      ''').limit(1);
      _log.i("Success! Retrieved ${clients.length} client(s).");
      if (clients.isNotEmpty) {
      _log.i("Sample client: ${clients[0]}");
      }
    } catch (e) {
      _log.e("Error querying clients table: $e");
      fail("Failed querying clients: $e");
    }

    try {
    _log.i("\n--- Testing Select on credit_cards_requests table ---");
      final cards = await client.from('credit_cards_requests').select('''
        id,
        bank_name,
        value,
        notes
      ''').limit(1);
      _log.i("Success! Retrieved ${cards.length} credit card request(s).");
      if (cards.isNotEmpty) {
      _log.i("Sample card: ${cards[0]}");
      }
    } catch (e) {
      _log.e("Error querying credit_cards_requests table: $e");
      fail("Failed querying credit_cards_requests: $e");
    }

    try {
    _log.i("\n--- Testing Select on interaction_history table ---");
      final history = await client.from('interaction_history').select('''
        id,
        action_type,
        notes,
        created_by_name
      ''').limit(1);
      _log.i("Success! Retrieved ${history.length} interaction log(s).");
      if (history.isNotEmpty) {
      _log.i("Sample interaction: ${history[0]}");
      }
    } catch (e) {
      _log.e("Error querying interaction_history table: $e");
      fail("Failed querying interaction_history: $e");
    }

    _log.i("\n--- All tests completed successfully ---");
  });
}
