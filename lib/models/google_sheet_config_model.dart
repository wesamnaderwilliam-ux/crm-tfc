class GoogleSheetConfigModel {
  final String id;
  final String sheetUrl;
  final Map<String, String> fieldMappings; // { "اسم العميل": "full_name", ... }
  final bool autoSync;
  final DateTime? lastSyncedAt;

  GoogleSheetConfigModel({
    this.id = '',
    required this.sheetUrl,
    required this.fieldMappings,
    this.autoSync = true,
    this.lastSyncedAt,
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
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'sheet_url': sheetUrl,
      'field_mappings': fieldMappings,
      'auto_sync': autoSync,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
}
