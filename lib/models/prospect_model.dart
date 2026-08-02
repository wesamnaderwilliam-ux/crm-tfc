import 'package:flutter/foundation.dart';

class ProspectModel {
  final String id;
  final String fullName;
  final String? phoneNumber;
  final String? secondaryPhoneNumber;
  final String? nationalId;
  final String? governorate;
  final String? jobTitle;
  final String? companyName;
  final double? salaryAmount;
  final String? notes;
  final Map<String, dynamic> rawData;
  final String? assignedToId;
  final String? assignedToName;
  final String status; // pending, contacted, converted, rejected
  final bool isConverted;
  final String? convertedClientId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProspectModel({
    required this.id,
    required this.fullName,
    this.phoneNumber,
    this.secondaryPhoneNumber,
    this.nationalId,
    this.governorate,
    this.jobTitle,
    this.companyName,
    this.salaryAmount,
    this.notes,
    this.rawData = const {},
    this.assignedToId,
    this.assignedToName,
    this.status = 'pending',
    this.isConverted = false,
    this.convertedClientId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProspectModel.fromJson(Map<String, dynamic> json) {
    return ProspectModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? 'بدون اسم',
      phoneNumber: json['phone_number'] ?? json['phoneNumber'],
      secondaryPhoneNumber: json['secondary_phone_number'],
      nationalId: json['national_id'],
      governorate: json['governorate'],
      jobTitle: json['job_title'],
      companyName: json['company_name'],
      salaryAmount: (json['salary_amount'] as num?)?.toDouble(),
      notes: json['notes'],
      rawData: (json['raw_data'] as Map<String, dynamic>?) ?? {},
      assignedToId: json['assigned_to_id'],
      assignedToName: json['assigned_to_name'],
      status: json['status'] ?? 'pending',
      isConverted: json['is_converted'] ?? false,
      convertedClientId: json['converted_client_id'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'secondary_phone_number': secondaryPhoneNumber,
      'national_id': nationalId,
      'governorate': governorate,
      'job_title': jobTitle,
      'company_name': companyName,
      'salary_amount': salaryAmount,
      'notes': notes,
      'raw_data': rawData,
      'assigned_to_id': assignedToId,
      'assigned_to_name': assignedToName,
      'status': status,
      'is_converted': isConverted,
      'converted_client_id': convertedClientId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns JSON suitable for Supabase INSERT (no 'id' or 'created_at' so DB generates them)
  Map<String, dynamic> toInsertJson() {
    final data = toJson();
    data.remove('id');
    data.remove('created_at');
    return data;
  }

  ProspectModel copyWith({
    String? fullName,
    String? phoneNumber,
    String? secondaryPhoneNumber,
    String? nationalId,
    String? governorate,
    String? jobTitle,
    String? companyName,
    double? salaryAmount,
    String? notes,
    Map<String, dynamic>? rawData,
    String? assignedToId,
    String? assignedToName,
    String? status,
    bool? isConverted,
    String? convertedClientId,
  }) {
    return ProspectModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      secondaryPhoneNumber: secondaryPhoneNumber ?? this.secondaryPhoneNumber,
      nationalId: nationalId ?? this.nationalId,
      governorate: governorate ?? this.governorate,
      jobTitle: jobTitle ?? this.jobTitle,
      companyName: companyName ?? this.companyName,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      notes: notes ?? this.notes,
      rawData: rawData ?? this.rawData,
      assignedToId: assignedToId ?? this.assignedToId,
      assignedToName: assignedToName ?? this.assignedToName,
      status: status ?? this.status,
      isConverted: isConverted ?? this.isConverted,
      convertedClientId: convertedClientId ?? this.convertedClientId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
