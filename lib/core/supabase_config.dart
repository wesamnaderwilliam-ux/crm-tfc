import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final Logger _logger = Logger();

class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY');

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      if (kDebugMode) {
        print("Dotenv load error on web: $e");
      }
    }
    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseUrl.contains("placeholder")) {
      if (kDebugMode) {
        print(
          "Supabase Config: Running in simulation mode (Placeholder URL detected).",
        );
      }
      _initialized = false;
      return;
    }
    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
      _initialized = true;
      _logger.i('Supabase initialized successfully.');
    } catch (e) {
      _initialized = false;
      _logger.e('Supabase Init Error (running in simulation mode): $e');
    }
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        "Supabase is not initialized. Please configure credentials first.",
      );
    }
    return Supabase.instance.client;
  }
}
