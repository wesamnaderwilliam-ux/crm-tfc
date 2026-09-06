import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import '../supabase_config.dart';

final Logger _logger = Logger();

class TursoClient {
  static Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? args]) async {
    final baseUrl = SupabaseConfig.tursoUrl;
    final token = SupabaseConfig.tursoToken;

    if (baseUrl.isEmpty || token.isEmpty) {
      return [];
    }

    try {
      final pipelineUrl = Uri.parse('$baseUrl/v2/pipeline');
      
      final Map<String, dynamic> stmt = {'sql': sql};
      if (args != null && args.isNotEmpty) {
        stmt['args'] = args.map((a) {
          if (a == null) return {'type': 'null'};
          if (a is int) return {'type': 'integer', 'value': a.toString()};
          if (a is double || a is num) return {'type': 'float', 'value': a.toDouble()};
          return {'type': 'text', 'value': a.toString()};
        }).toList();
      }

      final body = json.encode({
        'requests': [
          {
            'type': 'execute',
            'stmt': stmt,
          }
        ]
      });

      final response = await http.post(
        pipelineUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        _logger.w('Turso query returned status ${response.statusCode}: ${response.body}');
        return [];
      }

      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return [];

      final firstRes = results[0] as Map<String, dynamic>;
      if (firstRes['type'] == 'error') {
        _logger.e('Turso query error: ${firstRes["error"]}');
        return [];
      }

      final respData = firstRes['response'] as Map<String, dynamic>?;
      final result = respData?['result'] as Map<String, dynamic>?;
      if (result == null) return [];

      final cols = (result['cols'] as List<dynamic>?)?.map((c) => c['name']?.toString() ?? '').toList() ?? [];
      final rows = result['rows'] as List<dynamic>? ?? [];

      final List<Map<String, dynamic>> records = [];
      for (final r in rows) {
        final rowList = r as List<dynamic>;
        final Map<String, dynamic> map = {};
        for (int i = 0; i < cols.length && i < rowList.length; i++) {
          final cell = rowList[i] as Map<String, dynamic>?;
          if (cell == null || cell['type'] == 'null') {
            map[cols[i]] = null;
          } else if (cell['type'] == 'integer') {
            map[cols[i]] = int.tryParse(cell['value']?.toString() ?? '') ?? 0;
          } else if (cell['type'] == 'float') {
            map[cols[i]] = double.tryParse(cell['value']?.toString() ?? '') ?? 0.0;
          } else {
            map[cols[i]] = cell['value'];
          }
        }
        records.add(map);
      }

      return records;
    } catch (e) {
      _logger.e('Error executing Turso query: $e');
      return [];
    }
  }

  static Future<bool> execute(String sql, [List<dynamic>? args]) async {
    final baseUrl = SupabaseConfig.tursoUrl;
    final token = SupabaseConfig.tursoToken;

    if (baseUrl.isEmpty || token.isEmpty) {
      return false;
    }

    try {
      final pipelineUrl = Uri.parse('$baseUrl/v2/pipeline');
      final Map<String, dynamic> stmt = {'sql': sql};
      if (args != null && args.isNotEmpty) {
        stmt['args'] = args.map((a) {
          if (a == null) return {'type': 'null'};
          if (a is int) return {'type': 'integer', 'value': a.toString()};
          if (a is double || a is num) return {'type': 'float', 'value': a.toDouble()};
          return {'type': 'text', 'value': a.toString()};
        }).toList();
      }

      final body = json.encode({
        'requests': [
          {
            'type': 'execute',
            'stmt': stmt,
          },
          {'type': 'close'}
        ]
      });

      final response = await http.post(
        pipelineUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode != 200) {
        _logger.w('Turso execute status ${response.statusCode}: ${response.body}');
        return false;
      }
      return true;
    } catch (e) {
      _logger.e('Error executing Turso statement: $e');
      return false;
    }
  }
}
