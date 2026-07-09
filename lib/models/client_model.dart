class ClientModel {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? secondaryPhoneNumber;
  final String nationalId;
  final String birthDate;
  final String employmentType; // private_sector, government_sector, freelance, retired
  final String? companyName;
  final String? jobTitle;
  final bool isInsured;
  final String salaryTransferMethod; // bank_transfer, cash
  final List<Map<String, String>> salaryBankDetails; // [{bank: ..., amount: ...}]
  final double? cashSalaryAmount;
  final int creditScore;
  final double requestedAmount;
  final String governorate;
  final String? representativeName;
  final String? createdBy;
  final String status; // pending, iscore_inquiry, preparing_documents, under_review, at_bank, approved, rejected
  final DateTime createdAt;
  
  final List<ExistingLoanModel> existingLoans;
  final List<CreditCardRequestModel> creditCardsRequests;
  final List<InteractionLogModel> history;
  final List<ClientDocumentModel> documents;

  ClientModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    this.secondaryPhoneNumber,
    required this.nationalId,
    required this.birthDate,
    required this.employmentType,
    this.companyName,
    this.jobTitle,
    required this.isInsured,
    required this.salaryTransferMethod,
    this.salaryBankDetails = const [],
    this.cashSalaryAmount,
    required this.creditScore,
    required this.requestedAmount,
    required this.governorate,
    this.representativeName,
    this.createdBy,
    required this.status,
    required this.createdAt,
    this.existingLoans = const [],
    this.creditCardsRequests = const [],
    this.history = const [],
    this.documents = const [],
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      secondaryPhoneNumber: json['secondary_phone_number'],
      nationalId: json['national_id'] ?? '',
      birthDate: json['birth_date'] ?? '',
      employmentType: json['employment_type'] ?? 'private_sector',
      companyName: json['company_name'],
      jobTitle: json['job_title'],
      isInsured: json['is_insured'] ?? false,
      salaryTransferMethod: json['salary_transfer_method'] ?? 'bank_transfer',
      salaryBankDetails: (json['salary_bank_details'] as List?)
              ?.map((e) => Map<String, String>.from(e as Map))
              .toList() ?? [],
      cashSalaryAmount: (json['cash_salary_amount'] as num?)?.toDouble(),
      creditScore: json['credit_score'] ?? 600,
      requestedAmount: (json['requested_amount'] as num?)?.toDouble() ?? 0.0,
      governorate: json['governorate'] ?? '',
      representativeName: json['representative_name'],
      createdBy: json['created_by'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      existingLoans: (json['existing_loans'] as List?)
              ?.map((e) => ExistingLoanModel.fromJson(e))
              .toList() ?? [],
      creditCardsRequests: (json['credit_cards_requests'] as List?)
              ?.map((e) => CreditCardRequestModel.fromJson(e))
              .toList() ?? [],
      history: (json['interaction_history'] as List?)
              ?.map((e) => InteractionLogModel.fromJson(e))
              .toList() ?? [],
      documents: (json['documents'] as List?)
              ?.map((e) => ClientDocumentModel.fromJson(e))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'secondary_phone_number': secondaryPhoneNumber,
      'national_id': nationalId.isEmpty ? null : nationalId,
      'birth_date': birthDate,
      'employment_type': employmentType,
      'company_name': companyName,
      'job_title': jobTitle,
      'is_insured': isInsured,
      'salary_transfer_method': salaryTransferMethod,
      'salary_bank_details': salaryBankDetails,
      'cash_salary_amount': cashSalaryAmount,
      'credit_score': creditScore,
      'requested_amount': requestedAmount,
      'governorate': governorate,
      'representative_name': representativeName,
      'created_by': createdBy,
      'status': status,
    };
  }

  ClientModel copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? secondaryPhoneNumber,
    String? nationalId,
    String? birthDate,
    String? employmentType,
    String? companyName,
    String? jobTitle,
    bool? isInsured,
    String? salaryTransferMethod,
    List<Map<String, String>>? salaryBankDetails,
    double? cashSalaryAmount,
    int? creditScore,
    double? requestedAmount,
    String? governorate,
    String? representativeName,
    String? createdBy,
    String? status,
    DateTime? createdAt,
    List<ExistingLoanModel>? existingLoans,
    List<CreditCardRequestModel>? creditCardsRequests,
    List<InteractionLogModel>? history,
    List<ClientDocumentModel>? documents,
  }) {
    return ClientModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      secondaryPhoneNumber: secondaryPhoneNumber ?? this.secondaryPhoneNumber,
      nationalId: nationalId ?? this.nationalId,
      birthDate: birthDate ?? this.birthDate,
      employmentType: employmentType ?? this.employmentType,
      companyName: companyName ?? this.companyName,
      jobTitle: jobTitle ?? this.jobTitle,
      isInsured: isInsured ?? this.isInsured,
      salaryTransferMethod: salaryTransferMethod ?? this.salaryTransferMethod,
      salaryBankDetails: salaryBankDetails ?? this.salaryBankDetails,
      cashSalaryAmount: cashSalaryAmount ?? this.cashSalaryAmount,
      creditScore: creditScore ?? this.creditScore,
      requestedAmount: requestedAmount ?? this.requestedAmount,
      governorate: governorate ?? this.governorate,
      representativeName: representativeName ?? this.representativeName,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      existingLoans: existingLoans ?? this.existingLoans,
      creditCardsRequests: creditCardsRequests ?? this.creditCardsRequests,
      history: history ?? this.history,
      documents: documents ?? this.documents,
    );
  }
}

class ExistingLoanModel {
  final String id;
  final String bankName;
  final double installmentValue;
  final String? notes;

  ExistingLoanModel({
    required this.id,
    required this.bankName,
    required this.installmentValue,
    this.notes,
  });

  factory ExistingLoanModel.fromJson(Map<String, dynamic> json) {
    return ExistingLoanModel(
      id: json['id'] ?? '',
      bankName: json['bank_name'] ?? '',
      installmentValue: (json['installment_value'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'installment_value': installmentValue,
      'notes': notes,
    };
  }
  ExistingLoanModel copyWith({
    String? id,
    String? bankName,
    double? installmentValue,
    String? notes,
  }) {
    return ExistingLoanModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      installmentValue: installmentValue ?? this.installmentValue,
      notes: notes ?? this.notes,
    );
  }
}


class CreditCardRequestModel {
  final String id;
  final String bankName;
  final double value;
  final double fivePercentCalc;
  final String type; // card, request
  final String duration;
  final double installment;
  final double highestValue;
  final String? notes;

  CreditCardRequestModel({
    required this.id,
    required this.bankName,
    required this.value,
    required this.fivePercentCalc,
    required this.type,
    required this.duration,
    required this.installment,
    required this.highestValue,
    this.notes,
  });

  factory CreditCardRequestModel.fromJson(Map<String, dynamic> json) {
    return CreditCardRequestModel(
      id: json['id'] ?? '',
      bankName: json['bank_name'] ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      fivePercentCalc: (json['five_percent_calc'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? 'card',
      duration: json['duration'] ?? '',
      installment: (json['installment'] as num?)?.toDouble() ?? 0.0,
      highestValue: (json['highest_value'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bank_name': bankName,
      'value': value,
      'type': type,
      'duration': duration,
      'installment': installment,
      'highest_value': highestValue,
      'notes': notes,
    };
  }

  // Added copyWith method for immutable updates
  CreditCardRequestModel copyWith({
    String? id,
    String? bankName,
    double? value,
    double? fivePercentCalc,
    String? type,
    String? duration,
    double? installment,
    double? highestValue,
    String? notes,
  }) {
    return CreditCardRequestModel(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      value: value ?? this.value,
      fivePercentCalc: fivePercentCalc ?? this.fivePercentCalc,
      type: type ?? this.type,
      duration: duration ?? this.duration,
      installment: installment ?? this.installment,
      highestValue: highestValue ?? this.highestValue,
      notes: notes ?? this.notes,
    );
  }
}

class InteractionLogModel {
  final String id;
  final String actionType;
  final String notes;
  final String createdBy;
  final DateTime createdAt;
  final String logType; // file_interaction, follow_up, bank_follow_up
  final DateTime? followUpDate;
  final String? followUpStatus; // pending, completed

  InteractionLogModel({
    required this.id,
    required this.actionType,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    this.logType = 'file_interaction',
    this.followUpDate,
    this.followUpStatus,
  });

  factory InteractionLogModel.fromJson(Map<String, dynamic> json) {
    return InteractionLogModel(
      id: json['id'] ?? '',
      actionType: json['action_type'] ?? '',
      notes: json['notes'] ?? '',
      createdBy: json['created_by_name'] ?? json['created_by'] ?? 'النظام',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      logType: json['log_type'] ?? 'file_interaction',
      followUpDate: json['follow_up_date'] != null
          ? DateTime.parse(json['follow_up_date'])
          : null,
      followUpStatus: json['follow_up_status'],
    );
  }
}

class ClientDocumentModel {
  final String id;
  final String documentName;
  final String documentUrl;
  final String status; // pending, verified, rejected

  ClientDocumentModel({
    required this.id,
    required this.documentName,
    required this.documentUrl,
    required this.status,
  });

  ClientDocumentModel copyWith({
    String? id,
    String? documentName,
    String? documentUrl,
    String? status,
  }) {
    return ClientDocumentModel(
      id: id ?? this.id,
      documentName: documentName ?? this.documentName,
      documentUrl: documentUrl ?? this.documentUrl,
      status: status ?? this.status,
    );
  }

  factory ClientDocumentModel.fromJson(Map<String, dynamic> json) {
    return ClientDocumentModel(
      id: json['id'] ?? '',
      documentName: json['document_name'] ?? '',
      documentUrl: json['document_url'] ?? '',
      status: json['status'] ?? 'pending',
    );
  }
}
