import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final Logger _logger = Logger();

class SupabaseConfig {
  static String _url = 'https://fwzarykokwtczxuepczr.supabase.co';
  static String _anonKey = 'sb_publishable_Iy4Attl0mXEm8r5f6QnNhA_-lznBmUw';

  static String get url => _url;
  static String get anonKey => _anonKey;

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    // 1. Try loading from assets/env.json first (web safe)
    try {
      final jsonStr = await rootBundle.loadString('assets/env.json');
      final data = json.decode(jsonStr);
      if (data['SUPABASE_URL'] != null && data['SUPABASE_URL'].toString().isNotEmpty) {
        _url = data['SUPABASE_URL'];
      }
      if (data['SUPABASE_ANON_KEY'] != null && data['SUPABASE_ANON_KEY'].toString().isNotEmpty) {
        _anonKey = data['SUPABASE_ANON_KEY'];
      }
    } catch (e) {
      if (kDebugMode) {
        print("env.json load fallback: $e");
      }
    }

    // 2. Try dotenv load as secondary
    try {
      await dotenv.load(fileName: '.env');
      if (dotenv.env['SUPABASE_URL'] != null && dotenv.env['SUPABASE_URL']!.isNotEmpty) {
        _url = dotenv.env['SUPABASE_URL']!;
      }
      if (dotenv.env['SUPABASE_ANON_KEY'] != null && dotenv.env['SUPABASE_ANON_KEY']!.isNotEmpty) {
        _anonKey = dotenv.env['SUPABASE_ANON_KEY']!;
      }
    } catch (_) {}

    if (_url.isEmpty || _url.contains("placeholder")) {
      if (kDebugMode) {
        print(
          "Supabase Config: Running in simulation mode (Placeholder URL detected).",
        );
      }
      _initialized = false;
      return;
    }

    try {
      await Supabase.initialize(url: _url, anonKey: _anonKey);
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
