import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tfc_financial_crm/providers/supabase_provider.dart';
import 'package:logger/logger.dart';

final _log = Logger();

void main() {
  test('Print clients columns with auth', () async {
    await dotenv.load(fileName: '.env');
    final container = ProviderContainer();
    final client = container.read(supabaseProvider);

    try {
      await client.auth.signInWithPassword(
        email: 'wezonader@gmail.com',
        password: 'tfcwn14',
      );
      _log.i("Logged in successfully!");

      final res = await client.from('clients').select().limit(1);
      _log.i("Clients table rows count: ${res.length}");
      if (res.isNotEmpty) {
        _log.i("Clients columns: ${res[0].keys.toList()}");
        _log.i("Sample row: ${res[0]}");
      } else {
        _log.i("Clients table is empty.");
      }
    } catch (e) {
      _log.e("Error: $e");
    }
  });
}
