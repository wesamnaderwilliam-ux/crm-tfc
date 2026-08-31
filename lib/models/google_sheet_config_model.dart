class GoogleSheetConfigModel {
  final String id;
  final String sheetUrl;
  final Map<String, String> fieldMappings; // { "اسم العميل": "full_name", ... }
  final bool autoSync;
  final DateTime? lastSyncedAt;

  // حقول العملاء المحتملين
  final String prospectSheetUrl;
  final Map<String, String> prospectFieldMappings;

  GoogleSheetConfigModel({
    this.id = '',
    required this.sheetUrl,
    required this.fieldMappings,
    this.autoSync = true,
    this.lastSyncedAt,
    this.prospectSheetUrl = '',
    this.prospectFieldMappings = const {},
  });

  factory GoogleSheetConfigModel.fromJson(Map<String, dynamic> json) {
    return GoogleSheetConfigModel(
      id: json['id'] ?? '',
      sheetUrl: json['sheet_url'] ?? '',
      fieldMappings: Map<String, String>.from(json['field_mappings'] ?? {}),
      autoSync: json['auto_sync'] ?? true,
      lastSyncedAt: json['last_synced_at'] != null
          ? DateTime.tryParse(json['last_synced_at'])
          : null,
      prospectSheetUrl: json['prospect_sheet_url'] ?? '',
      prospectFieldMappings: Map<String, String>.from(json['prospect_field_mappings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sheet_url': sheetUrl,
      'field_mappings': fieldMappings,
      'auto_sync': autoSync,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'prospect_sheet_url': prospectSheetUrl,
      'prospect_field_mappings': prospectFieldMappings,
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
