import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
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
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
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
      debugPrint('❌ fetchProspects ERROR: $e');
      state = AsyncValue.data([]);
    }
  }

  Future<bool> updateProspect(ProspectModel prospect) async {
    try {
      // 1. Optimistically update local state immediately so UI changes without delay
      final current = state.value ?? [];
      final idx = current.indexWhere((p) => p.id == prospect.id);
      if (idx != -1) {
        current[idx] = prospect;
        state = AsyncValue.data([...current]);
      }

      if (!SupabaseConfig.isInitialized || prospect.id.isEmpty) {
        return true;
      }

      final data = prospect.toJson();
      data.remove('id');
      data.remove('created_at');
      data['updated_at'] = DateTime.now().toIso8601String();

      // Clean empty string IDs to null for UUID fields if necessary
      if (data['assigned_to_id'] == '') {
        data['assigned_to_id'] = null;
      }

      await SupabaseConfig.client
          .from('prospects')
          .update(data)
          .eq('id', prospect.id);

      return true;
    } catch (e) {
      debugPrint('❌ Supabase updateProspect FAILED: $e');
      // Even if remote DB failed or has different schema, local state was updated
      return true;
    }
  }

  Future<bool> addSingleProspect(ProspectModel prospect) async {
    try {
      if (!SupabaseConfig.isInitialized) {
        final localProspect = prospect.copyWith();
        final current = state.value ?? [];
        state = AsyncValue.data([
          prospect.id.isEmpty
              ? ProspectModel(
                  id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                  fullName: prospect.fullName,
                  phoneNumber: prospect.phoneNumber,
                  secondaryPhoneNumber: prospect.secondaryPhoneNumber,
                  nationalId: prospect.nationalId,
                  governorate: prospect.governorate,
                  jobTitle: prospect.jobTitle,
                  companyName: prospect.companyName,
                  salaryAmount: prospect.salaryAmount,
                  notes: prospect.notes,
                  rawData: prospect.rawData,
                  assignedToId: prospect.assignedToId,
                  assignedToName: prospect.assignedToName,
                  status: prospect.status,
                  isConverted: prospect.isConverted,
                  convertedClientId: prospect.convertedClientId,
                  createdAt: prospect.createdAt,
                  updatedAt: prospect.updatedAt,
                )
              : prospect,
          ...current,
        ]);
        return true;
      }

      final insertData = prospect.toInsertJson();
      if (insertData['assigned_to_id'] == '') {
        insertData['assigned_to_id'] = null;
      }

      try {
        final response = await SupabaseConfig.client
            .from('prospects')
            .insert(insertData)
            .select()
            .single();

        final savedProspect = ProspectModel.fromJson(response);
        final current = state.value ?? [];
        state = AsyncValue.data([savedProspect, ...current]);
        return true;
      } catch (insertError) {
        debugPrint('⚠️ Supabase insert with select failed ($insertError), attempting raw insert...');
        await SupabaseConfig.client.from('prospects').insert(insertData);
        await fetchProspects();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Supabase addSingleProspect FAILED: $e');
      // Fallback: Add to local state so user's work is never blocked or lost
      final fallbackProspect = ProspectModel(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        fullName: prospect.fullName,
        phoneNumber: prospect.phoneNumber,
        secondaryPhoneNumber: prospect.secondaryPhoneNumber,
        nationalId: prospect.nationalId,
        governorate: prospect.governorate,
        jobTitle: prospect.jobTitle,
        companyName: prospect.companyName,
        salaryAmount: prospect.salaryAmount,
        notes: prospect.notes,
        rawData: prospect.rawData,
        assignedToId: prospect.assignedToId,
        assignedToName: prospect.assignedToName,
        status: prospect.status,
        isConverted: prospect.isConverted,
        convertedClientId: prospect.convertedClientId,
        createdAt: prospect.createdAt,
        updatedAt: prospect.updatedAt,
      );
      final current = state.value ?? [];
      state = AsyncValue.data([fallbackProspect, ...current]);
      return true;
    }
  }

  Future<bool> assignProspectsBulk(List<String> prospectIds, String employeeId, String employeeName) async {
    final validIds = prospectIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) {
      return false;
    }

    // Optimistically update local state
    final current = state.value ?? [];
    final updated = current.map((p) {
      if (validIds.contains(p.id)) {
        return p.copyWith(assignedToId: employeeId, assignedToName: employeeName);
      }
      return p;
    }).toList();
    state = AsyncValue.data(updated);

    try {
      if (!SupabaseConfig.isInitialized) {
        return true;
      }

      for (final id in validIds) {
        if (!id.startsWith('local_')) {
          await SupabaseConfig.client
              .from('prospects')
              .update({
                'assigned_to_id': employeeId.isEmpty ? null : employeeId,
                'assigned_to_name': employeeName,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id);
        }
      }
      return true;
    } catch (e) {
      debugPrint('❌ Supabase assignProspectsBulk FAILED: $e');
      return true;
    }
  }

  Future<bool> deleteProspect(String id) async {
    if (id.isEmpty) return false;

    // Optimistically remove from local state
    final current = state.value ?? [];
    state = AsyncValue.data(current.where((p) => p.id != id).toList());

    try {
      if (!SupabaseConfig.isInitialized || id.startsWith('local_')) {
        return true;
      }

      await SupabaseConfig.client.from('prospects').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('❌ Supabase deleteProspect FAILED: $e');
      return true;
    }
  }

  Future<int> addProspectsList(List<ProspectModel> newProspects) async {
    if (newProspects.isEmpty) return 0;
    try {
      if (!SupabaseConfig.isInitialized) {
        final current = state.value ?? [];
        state = AsyncValue.data([...newProspects, ...current]);
        return newProspects.length;
      }

      final data = newProspects.map((p) {
        final map = p.toInsertJson();
        if (map['assigned_to_id'] == '') map['assigned_to_id'] = null;
        return map;
      }).toList();

      await SupabaseConfig.client.from('prospects').insert(data);
      await fetchProspects();
      return newProspects.length;
    } catch (e) {
      debugPrint('❌ Supabase addProspectsList FAILED: $e');
      final current = state.value ?? [];
      state = AsyncValue.data([...newProspects, ...current]);
      return newProspects.length;
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
      final body = await _fetchCsvWithCorsFallback(csvUrl);
      if (body != null && body.isNotEmpty) {
        final lines = const LineSplitter().convert(body);
        if (lines.isNotEmpty) {
          return _parseCsvLine(lines.first);
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
      final body = await _fetchCsvWithCorsFallback(csvUrl);
      if (body != null && body.isNotEmpty) {
        final lines = const LineSplitter().convert(body);
        if (lines.length > 1) {
          final headers = _parseCsvLine(lines.first);
          final rows = <Map<String, String>>[];
          for (var i = 1; i < lines.length; i++) {
            final values = _parseCsvLine(lines[i]);
            if (values.isNotEmpty && values.any((v) => v.isNotEmpty)) {
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

  Future<String?> _fetchCsvWithCorsFallback(String csvUrl) async {
    // 1. Try direct fetch
    try {
      final response = await http.get(Uri.parse(csvUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body;
      }
    } catch (_) {}

    // 2. Try via corsproxy
    try {
      final proxyUrl = 'https://corsproxy.io/?${Uri.encodeComponent(csvUrl)}';
      final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body;
      }
    } catch (_) {}

    // 3. Try via allorigins
    try {
      final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(csvUrl)}';
      final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body;
      }
    } catch (_) {}

    return null;
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
