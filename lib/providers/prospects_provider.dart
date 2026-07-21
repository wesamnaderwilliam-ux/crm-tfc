import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../core/supabase_config.dart';
import '../models/prospect_model.dart';
import '../models/google_sheet_config_model.dart';

final prospectsProvider = StateNotifierProvider<ProspectsNotifier, AsyncValue<List<ProspectModel>>>((ref) {
  return ProspectsNotifier();
});

final googleSheetConfigProvider = StateNotifierProvider<GoogleSheetConfigNotifier, AsyncValue<GoogleSheetConfigModel?>>((ref) {
  return GoogleSheetConfigNotifier();
});

class ProspectsNotifier extends StateNotifier<AsyncValue<List<ProspectModel>>> {
  ProspectsNotifier() : super(const AsyncValue.loading()) {
    fetchProspects();
  }

  Future<void> fetchProspects() async {
    state = const AsyncValue.loading();
    try {
      if (!SupabaseConfig.isInitialized) {
        state = const AsyncValue.data([]);
        return;
      }

      final response = await SupabaseConfig.client
          .from('prospects')
          .select()
          .order('created_at', ascending: false);

      final prospects = (response as List).map((e) => ProspectModel.fromJson(e)).toList();
      state = AsyncValue.data(prospects);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateProspect(ProspectModel prospect) async {
    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('prospects')
            .update(prospect.toJson())
            .eq('id', prospect.id);
      }

      final current = state.value ?? [];
      final idx = current.indexWhere((p) => p.id == prospect.id);
      if (idx != -1) {
        current[idx] = prospect;
        state = AsyncValue.data([...current]);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> assignProspectsBulk(List<String> prospectIds, String employeeId, String employeeName) async {
    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('prospects')
            .update({
              'assigned_to_id': employeeId,
              'assigned_to_name': employeeName,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .filter('id', 'in', prospectIds);
      }

      final current = state.value ?? [];
      final updated = current.map((p) {
        if (prospectIds.contains(p.id)) {
          return p.copyWith(assignedToId: employeeId, assignedToName: employeeName);
        }
        return p;
      }).toList();

      state = AsyncValue.data(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteProspect(String id) async {
    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client.from('prospects').delete().eq('id', id);
      }
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((p) => p.id != id).toList());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> addProspectsList(List<ProspectModel> newProspects) async {
    if (newProspects.isEmpty) return;
    try {
      if (SupabaseConfig.isInitialized) {
        final data = newProspects.map((p) => p.toJson()..remove('id')).toList();
        await SupabaseConfig.client.from('prospects').insert(data);
        await fetchProspects();
      } else {
        final current = state.value ?? [];
        state = AsyncValue.data([...newProspects, ...current]);
      }
    } catch (e) {
      // Log or handle
    }
  }
}

class GoogleSheetConfigNotifier extends StateNotifier<AsyncValue<GoogleSheetConfigModel?>> {
  GoogleSheetConfigNotifier() : super(const AsyncValue.loading()) {
    fetchConfig();
  }

  Future<void> fetchConfig() async {
    try {
      if (SupabaseConfig.isInitialized) {
        final response = await SupabaseConfig.client
            .from('google_sheets_config')
            .select()
            .limit(1)
            .maybeSingle();

        if (response != null) {
          state = AsyncValue.data(GoogleSheetConfigModel.fromJson(response));
          return;
        }
      }
      
      // Fallback to local storage (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('saved_google_sheets_config');
      if (savedJson != null) {
        final map = jsonDecode(savedJson);
        state = AsyncValue.data(GoogleSheetConfigModel.fromJson(map));
      } else {
        state = const AsyncValue.data(null);
      }
    } catch (e) {
      // Try local storage on network error
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedJson = prefs.getString('saved_google_sheets_config');
        if (savedJson != null) {
          final map = jsonDecode(savedJson);
          state = AsyncValue.data(GoogleSheetConfigModel.fromJson(map));
        } else {
          state = const AsyncValue.data(null);
        }
      } catch (_) {
        state = const AsyncValue.data(null);
      }
    }
  }

  Future<bool> saveConfig(GoogleSheetConfigModel config) async {
    try {
      final existing = state.value;
      final configToSave = (existing != null && existing.id.isNotEmpty)
          ? GoogleSheetConfigModel(
              id: existing.id,
              sheetUrl: config.sheetUrl,
              fieldMappings: config.fieldMappings,
              autoSync: config.autoSync,
              lastSyncedAt: config.lastSyncedAt,
            )
          : config;

      // 1. Save locally (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_google_sheets_config', jsonEncode(configToSave.toJson()));

      // 2. Try DB if available
      if (SupabaseConfig.isInitialized) {
        if (existing != null && existing.id.isNotEmpty) {
          await SupabaseConfig.client
              .from('google_sheets_config')
              .update(configToSave.toJson())
              .eq('id', existing.id);
        } else {
          final res = await SupabaseConfig.client
              .from('google_sheets_config')
              .insert(configToSave.toJson())
              .select()
              .maybeSingle();
          if (res != null) {
            state = AsyncValue.data(GoogleSheetConfigModel.fromJson(res));
            return true;
          }
        }
      }
      state = AsyncValue.data(configToSave);
      return true;
    } catch (e) {
      // Local save already succeeded as fallback
      state = AsyncValue.data(config);
      return true;
    }
  }

  // Parse CSV from public Google Sheet URL
  Future<List<String>> fetchSheetHeaders(String url) async {
    try {
      final csvUrl = _convertGoogleSheetToCsvUrl(url);
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(response.body);
        if (lines.isNotEmpty) {
          final firstLine = lines.first;
          return _parseCsvLine(firstLine);
        }
      }
    } catch (e) {
      // Error fetching headers
    }
    return [];
  }

  Future<List<Map<String, String>>> syncRowsFromSheet(String url) async {
    try {
      final csvUrl = _convertGoogleSheetToCsvUrl(url);
      final response = await http.get(Uri.parse(csvUrl));
      if (response.statusCode == 200) {
        final lines = const LineSplitter().convert(response.body);
        if (lines.length > 1) {
          final headers = _parseCsvLine(lines.first);
          final rows = <Map<String, String>>[];
          for (var i = 1; i < lines.length; i++) {
            final values = _parseCsvLine(lines[i]);
            if (values.isNotEmpty) {
              final rowMap = <String, String>{};
              for (var j = 0; j < headers.length; j++) {
                rowMap[headers[j]] = j < values.length ? values[j] : '';
              }
              rows.add(rowMap);
            }
          }
          return rows;
        }
      }
    } catch (e) {
      // Sync error
    }
    return [];
  }

  String _convertGoogleSheetToCsvUrl(String inputUrl) {
    if (inputUrl.contains('/pubhtml') || inputUrl.contains('/pub?')) {
      return inputUrl.replaceAll('/pubhtml', '/pub?output=csv');
    }
    final match = RegExp(r'/d/([a-zA-Z0-9-_]+)').firstMatch(inputUrl);
    if (match != null) {
      final sheetId = match.group(1);
      return 'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv';
    }
    return inputUrl;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        values.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    values.add(current.toString().trim());
    return values;
  }
}
