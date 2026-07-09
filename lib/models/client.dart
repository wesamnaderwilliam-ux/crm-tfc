class Client {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String? secondaryPhoneNumber;
  final String nationalId;
  final DateTime birthDate;
  final String employmentType;
  final String? companyName;
  final String? jobTitle;
  final bool isInsured;
  final String salaryTransferMethod;
  final List<dynamic> salaryBankDetails;
  final double? cashSalaryAmount;
  final int creditScore;
  final double requestedAmount;
  final String governorate;
  final String? representativeName;
  final String? createdBy;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
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
    required this.salaryBankDetails,
    this.cashSalaryAmount,
    required this.creditScore,
    required this.requestedAmount,
    required this.governorate,
    this.representativeName,
    this.createdBy,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Client.fromMap(Map<String, dynamic> map) => Client(
        id: map['id'] as String,
        fullName: map['full_name'] as String,
        phoneNumber: map['phone_number'] as String,
        secondaryPhoneNumber: map['secondary_phone_number'] as String?,
        nationalId: map['national_id'] as String,
        birthDate: DateTime.parse(map['birth_date'] as String),
        employmentType: map['employment_type'] as String,
        companyName: map['company_name'] as String?,
        jobTitle: map['job_title'] as String?,
        isInsured: map['is_insured'] as bool,
        salaryTransferMethod: map['salary_transfer_method'] as String,
        salaryBankDetails: (map['salary_bank_details'] as List?) ?? [],
        cashSalaryAmount: (map['cash_salary_amount'] as num?)?.toDouble(),
        creditScore: map['credit_score'] as int,
        requestedAmount: (map['requested_amount'] as num).toDouble(),
        governorate: map['governorate'] as String,
        representativeName: map['representative_name'] as String?,
        createdBy: map['created_by'] as String?,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'secondary_phone_number': secondaryPhoneNumber,
        'national_id': nationalId,
        'birth_date': birthDate.toIso8601String(),
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
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
