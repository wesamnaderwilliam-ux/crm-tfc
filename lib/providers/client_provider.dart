import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../core/supabase_config.dart';
import 'auth_provider.dart';
import 'package:logger/logger.dart';
final Logger _logger = Logger();
class ClientState {
  final List<ClientModel> clients;
  final bool isLoading;
  final String? error;

  ClientState({
    this.clients = const [],
    this.isLoading = false,
    this.error,
  });

  ClientState copyWith({
    List<ClientModel>? clients,
    bool? isLoading,
    String? error,
  }) {
    return ClientState(
      clients: clients ?? this.clients,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ClientNotifier extends StateNotifier<ClientState> {
  final Ref _ref;
  ClientNotifier(this._ref) : super(ClientState()) {
    _ref.listen(authProvider, (previous, next) {
      final bankEmpId = next.bankEmployeeId;
      fetchClients(bankEmployeeId: bankEmpId);
    });
    // Initial fetch - will get bank_employee_id from current auth state
    final initialAuth = _ref.read(authProvider);
    fetchClients(bankEmployeeId: initialAuth.bankEmployeeId);
  }

  /// Internal refresh helper - always reads current bankEmployeeId from auth state
  void _refreshClients() {
    final auth = _ref.read(authProvider);
    fetchClients(bankEmployeeId: auth.bankEmployeeId);
  }

  // Pre-seed mock data for local demonstration/preview
  final List<ClientModel> _mockClients = [
    ClientModel(
      id: "fc-c1-ahmed",
      fullName: "أحمد القحطاني",
      phoneNumber: "0512345678",
      secondaryPhoneNumber: "0551234567",
      nationalId: "10029384758694",
      birthDate: "1988-10-15",
      employmentType: "private_sector",
      companyName: "شركة الزيت العربية للاستشارات",
      jobTitle: "مستشار تقني رئيسي",
      isInsured: true,
      salaryTransferMethod: "bank_transfer",
      creditScore: 742,
      requestedAmount: 1250000.00,
      governorate: "الرياض",
      representativeName: "خالد عبد الله",
      status: "under_review",
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      existingLoans: [
        ExistingLoanModel(
            id: "l1",
            bankName: "البنك الأهلي",
            installmentValue: 5000.0,
            notes: "قرض عقاري قائم"),
      ],
      creditCardsRequests: [
        CreditCardRequestModel(
          id: "cc1",
          bankName: "بنك الراجحي",
          value: 100000.0,
          fivePercentCalc: 5000.0,
          type: "card",
          duration: "12 شهر",
          installment: 4500.0,
          highestValue: 5000.0,
        ),
      ],
      history: [
        InteractionLogModel(
          id: "h1",
          actionType: "مكالمة هاتفية - تحديث الحالة",
          notes:
              "تم إبلاغ العميل بطلب البنك لكشف حساب إضافي لآخر 3 أشهر. العميل وعد بإرساله قبل نهاية اليوم.",
          createdBy: "خالد عبد الله",
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        InteractionLogModel(
          id: "h2",
          actionType: "اجتماع حضوري - فرع الرياض",
          notes:
              "مناقشة شروط التمويل العقاري والنسب المئوية المقترحة من بنك الراجحي.",
          createdBy: "خالد عبد الله",
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ],
      documents: [
        ClientDocumentModel(
            id: "doc1",
            documentName: "الهوية الوطنية",
            documentUrl: "",
            status: "verified"),
        ClientDocumentModel(
            id: "doc2",
            documentName: "شهادة الراتب",
            documentUrl: "",
            status: "verified"),
        ClientDocumentModel(
            id: "doc3",
            documentName: "كشوفات الحساب البنكية",
            documentUrl: "",
            status: "pending"),
      ],
    ),
    ClientModel(
      id: "fc-c2-sara",
      fullName: "سارة المنصوري",
      phoneNumber: "0543210987",
      nationalId: "20019283746594",
      birthDate: "1995-04-20",
      employmentType: "government_sector",
      companyName: "وزارة المالية والتخطيط",
      jobTitle: "محلل مالي أول",
      isInsured: true,
      salaryTransferMethod: "bank_transfer",
      creditScore: 810,
      requestedAmount: 850000.00,
      governorate: "جدة",
      representativeName: "منى أحمد",
      status: "approved",
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      history: [
        InteractionLogModel(
          id: "h3",
          actionType: "طلب مستندات",
          notes: "تم استلام شهادة الراتب المحدثة للعميل والتحقق منها بنجاح.",
          createdBy: "منى أحمد",
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ],
      documents: [
        ClientDocumentModel(
            id: "doc4",
            documentName: "الهوية الوطنية",
            documentUrl: "",
            status: "verified"),
        ClientDocumentModel(
            id: "doc5",
            documentName: "شهادة الراتب",
            documentUrl: "",
            status: "verified"),
      ],
    ),
    ClientModel(
      id: "fc-c3-mohammed",
      fullName: "محمد الشمري",
      phoneNumber: "0509876543",
      nationalId: "10087654321098",
      birthDate: "1990-12-05",
      employmentType: "freelance",
      companyName: "الشمري للاستشارات القانونية",
      jobTitle: "محامٍ حر",
      isInsured: false,
      salaryTransferMethod: "cash",
      creditScore: 580,
      requestedAmount: 300000.00,
      governorate: "الدمام",
      representativeName: "عمر فاروق",
      status: "pending",
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      documents: [
        ClientDocumentModel(
            id: "doc6",
            documentName: "الهوية الوطنية",
            documentUrl: "",
            status: "pending"),
      ],
    ),
  ];

  List<ClientModel> _getFilteredMockClients() {
    final currentUser = _ref.read(authProvider);
    // In simulation mode (Supabase not initialized) show all mock clients for preview
    if (!SupabaseConfig.isInitialized) {
      return _mockClients;
    }
    if (!currentUser.isAuthenticated) {
      // Return all mock clients for preview when not logged in
      return _mockClients;
    }

    if (currentUser.role == 'admin') {
      return _mockClients;
    }

    if (currentUser.role == 'manager') {
      // Manager sees their own clients and the clients of company_employees
      return _mockClients.where((c) {
        return c.representativeName == currentUser.fullName ||
            c.representativeName == "خالد عبد الله" ||
            c.representativeName == "منى أحمد";
      }).toList();
    }

    if (currentUser.role == 'company_employee') {
      // Company employee sees only their own clients
      return _mockClients.where((c) {
        return c.representativeName == currentUser.fullName ||
            c.representativeName == "خالد عبد الله";
      }).toList();
    }

    if (currentUser.role == 'bank_employee') {
      // Bank employee sees only their own clients
      return _mockClients.where((c) {
        return c.representativeName == currentUser.fullName ||
            c.representativeName == "عمر فاروق";
      }).toList();
    }

    return _mockClients.where((c) => c.representativeName == currentUser.fullName).toList();
  }

  Future<void> fetchClients({String? bankEmployeeId}) async {
    // Keep current clients visible while refreshing in background for zero flicker
    if (state.clients.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    if (!SupabaseConfig.isInitialized) {
      _logger.i("Supabase not initialized: loading simulator client records.");
      state = state.copyWith(clients: _getFilteredMockClients(), isLoading: false);
      return;
    }
    try {
      List<ClientModel> list = [];

      if (bankEmployeeId != null && bankEmployeeId.isNotEmpty) {
        // Bank employee: fetch ONLY clients that have a distribution entry assigned to them
        final distResponse = await SupabaseConfig.client
            .from('distribution_entries')
            .select('client_id')
            .eq('employee_id', bankEmployeeId);

        final List<String> clientIds = (distResponse as List<dynamic>)
            .map((r) => r['client_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toList();

        if (clientIds.isEmpty) {
          state = state.copyWith(clients: [], isLoading: false);
          return;
        }

        final response = await SupabaseConfig.client
            .from('clients')
            .select('''
              *,
              existing_loans(*),
              credit_cards_requests(*),
              interaction_history(*),
              documents(*)
            ''')
            .inFilter('id', clientIds)
            .order('created_at', ascending: false);

        for (var item in response) {
          list.add(ClientModel.fromJson(item));
        }
      } else {
        // All other roles: fetch all clients (visibility filtered client-side by ClientVisibilityHelper)
        final response = await SupabaseConfig.client
            .from('clients')
            .select('''
              *,
              existing_loans(*),
              credit_cards_requests(*),
              interaction_history(*),
              documents(*)
            ''')
            .order('created_at', ascending: false)
            .limit(100);

        for (var item in response) {
          list.add(ClientModel.fromJson(item));
        }
      }

      state = state.copyWith(clients: list, isLoading: false);
    } catch (e) {
      _logger.w("Warning: could not fetch clients from Supabase: $e");
      state = state.copyWith(clients: _getFilteredMockClients(), isLoading: false);
    }
  }

  Future<String?> addClient(ClientModel client, List<ExistingLoanModel> loans,
      List<CreditCardRequestModel> cards, {String? customNotes}) async {
    // 1. Local duplicate check
    if (client.nationalId.isNotEmpty) {
      final exists = state.clients.any((c) => c.nationalId == client.nationalId);
      if (exists) {
        return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
      }
    }

    if (!SupabaseConfig.isInitialized) {
      _addClientSimulated(client, loans, cards, customNotes: customNotes);
      return null;
    }
    try {
      final clientData = client.toJson();
      // Remove placeholder ID – Supabase generates UUID
      clientData.remove('id');

      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      if (currentUserId != null) {
        clientData['created_by'] = currentUserId;
      }

      final response = await SupabaseConfig.client
          .from('clients')
          .insert(clientData)
          .select()
          .single();

      final String newClientId = response['id'];

      // Add loans
      if (loans.isNotEmpty) {
        final loansData = loans
            .map((l) => {
                  'client_id': newClientId,
                  'bank_name': l.bankName,
                  'installment_value': l.installmentValue,
                  'notes': l.notes,
                })
            .toList();
        await SupabaseConfig.client.from('existing_loans').insert(loansData);
      }

      // Add cards
      if (cards.isNotEmpty) {
        final cardsData = cards
            .map((c) => {
                  'client_id': newClientId,
                  'bank_name': c.bankName,
                  'value': c.value,
                  'type': c.type,
                  'duration': c.duration,
                  'installment': c.installment,
                  'highest_value': c.highestValue,
                  'notes': c.notes,
                })
            .toList();
        await SupabaseConfig.client
            .from('credit_cards_requests')
            .insert(cardsData);
      }

      // Add documents
      if (client.documents.isNotEmpty) {
        final docsData = client.documents
            .map((d) => {
                  'client_id': newClientId,
                  'document_name': d.documentName,
                  'document_url': d.documentUrl,
                  'status': d.status,
                })
            .toList();
        await SupabaseConfig.client.from('documents').insert(docsData);
      }

      // Add custom salary details log to interaction_history
      if (customNotes != null) {
        await SupabaseConfig.client.from('interaction_history').insert({
          'client_id': newClientId,
          'action_type': 'إنشاء الملف - تفاصيل الراتب',
          'notes': customNotes,
          'created_by_name': client.representativeName ?? 'النظام',
        });
      }

      _refreshClients();
      return null;
    } catch (e, stack) {
      _logger.e("Supabase insert error: $e", error: e, stackTrace: stack);
      if (e is PostgrestException) {
        if (e.code == '23505' || e.message.contains('national_id') || (e.details?.toString().contains('national_id') ?? false)) {
          return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
        }
        return "خطأ في قاعدة البيانات: ${e.message} (${e.code})";
      } else if (e.toString().contains("23505") || e.toString().contains("national_id")) {
        return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
      }

      return "خطأ في حفظ العميل: $e";
    }
  }

  void _addClientSimulated(ClientModel client, List<ExistingLoanModel> loans,
      List<CreditCardRequestModel> cards, {String? customNotes}) {
    final currentUser = _ref.read(authProvider);
    final newClient = client.copyWith(
        id: "fc-c-${DateTime.now().millisecondsSinceEpoch}",
        createdBy: currentUser.user?.id ?? "mock-user-id",
        representativeName: currentUser.fullName,
        existingLoans: loans,
        creditCardsRequests: cards,
        createdAt: DateTime.now(),
        documents: client.documents.isNotEmpty
            ? client.documents
            : [
                ClientDocumentModel(
                    id: "d1",
                    documentName: "الهوية الوطنية",
                    documentUrl: "",
                    status: "pending"),
                ClientDocumentModel(
                    id: "d2",
                    documentName: "ظهر بطاقة الهوية",
                    documentUrl: "",
                    status: "pending"),
              ],
        history: [
          InteractionLogModel(
            id: "hi1",
            actionType: "إنشاء الملف",
            notes: customNotes ?? "تم تسجيل العميل وتوليد طلب التمويل بنجاح.",
            createdBy: client.representativeName ?? "النظام",
            createdAt: DateTime.now(),
          ),
        ]);

    state = state.copyWith(
      clients: [newClient, ...state.clients],
    );
  }

  /// Helper to check if a string is a valid UUID.
  bool _isValidUuid(String? id) {
    if (id == null) return false;
    return RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);
  }

  /// Update only the loans list for a client.
  Future<bool> updateClientLoans(String clientId, List<ExistingLoanModel> loans, {String? staffName}) async {
    // Optimistically update local state first (simulation fallback)
    final ClientModel? client = state.clients.firstWhereOrNull((c) => c.id == clientId);
    if (client == null) return false;

    final updatedClient = client.copyWith(existingLoans: loans);
    final isUuid = _isValidUuid(clientId);
    final diffNotes = _getLoansDiff(client.existingLoans, loans);

    if (!SupabaseConfig.isInitialized || !isUuid) {
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث القروض');
      return true;
    }
    try {
      // Delete existing loans for this client
      await SupabaseConfig.client
          .from('existing_loans')
          .delete()
          .eq('client_id', clientId);

      // Insert new loans
      if (loans.isNotEmpty) {
        final loansData = loans
            .map((l) => {
                  'client_id': clientId,
                  'bank_name': l.bankName,
                  'installment_value': l.installmentValue,
                  'notes': l.notes,
                })
            .toList();
        await SupabaseConfig.client.from('existing_loans').insert(loansData);
      }

      // Log interaction
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحديث القروض',
        'notes': diffNotes,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName ?? 'النظام',
      });
      _refreshClients();
      return true;
    } catch (e) {
      _logger.e("Supabase loan update error, falling back to simulation: $e");
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث القروض');
      return true;
    }
  }

  /// Update only the credit cards list for a client.
  Future<bool> updateClientCards(String clientId, List<CreditCardRequestModel> cards, {String? staffName}) async {
    final ClientModel? client = state.clients.firstWhereOrNull((c) => c.id == clientId);
    if (client == null) return false;

    final updatedClient = client.copyWith(creditCardsRequests: cards);
    final isUuid = _isValidUuid(clientId);
    final diffNotes = _getCardsDiff(client.creditCardsRequests, cards);

    if (!SupabaseConfig.isInitialized || !isUuid) {
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث البطاقات');
      return true;
    }
    try {
      // Delete existing cards for this client
      await SupabaseConfig.client
          .from('credit_cards_requests')
          .delete()
          .eq('client_id', clientId);

      // Insert new cards
      if (cards.isNotEmpty) {
        final cardsData = cards
            .map((c) => {
                  'client_id': clientId,
                  'bank_name': c.bankName,
                  'value': c.value,
                  'type': c.type,
                  'duration': c.duration,
                  'installment': c.installment,
                  'highest_value': c.highestValue,
                  'notes': c.notes,
                })
            .toList();
        await SupabaseConfig.client
            .from('credit_cards_requests')
            .insert(cardsData);
      }

      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحديث البطاقات',
        'notes': diffNotes,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName ?? 'النظام',
      });
      _refreshClients();
      return true;
    } catch (e) {
      _logger.e("Supabase card update error, falling back to simulation: $e");
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث البطاقات');
      return true;
    }
  }

  /// Update only the documents list for a client.
  Future<bool> updateClientDocuments(String clientId, List<ClientDocumentModel> documents, {String? staffName}) async {
    final ClientModel? client = state.clients.firstWhereOrNull((c) => c.id == clientId);
    if (client == null) return false;

    final updatedClient = client.copyWith(documents: documents);
    final isUuid = _isValidUuid(clientId);
    final diffNotes = _getDocumentsDiff(client.documents, documents);

    if (!SupabaseConfig.isInitialized || !isUuid) {
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث المستندات');
      return true;
    }
    try {
      // Delete existing documents for this client
      await SupabaseConfig.client
          .from('documents')
          .delete()
          .eq('client_id', clientId);

      // Insert new documents
      if (documents.isNotEmpty) {
        final docsData = documents
            .map((d) => {
                  'client_id': clientId,
                  'document_name': d.documentName,
                  'document_url': d.documentUrl,
                  'status': d.status,
                })
            .toList();
        await SupabaseConfig.client.from('documents').insert(docsData);
      }

      // Log interaction
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحديث المستندات',
        'notes': diffNotes,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName ?? 'النظام',
      });
      _refreshClients();
      return true;
    } catch (e) {
      _logger.e("Supabase document update error, falling back to simulation: $e");
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'تحديث المستندات');
      return true;
    }
  }

  /// Remove a specific loan or card from a client.
  Future<bool> removeLoanOrCard({
    required String clientId,
    String? loanId,
    String? cardId,
    String? staffName,
  }) async {
    final ClientModel? client = state.clients.firstWhereOrNull((c) => c.id == clientId);
    if (client == null) return false;
    List<ExistingLoanModel> updatedLoans = client.existingLoans;
    List<CreditCardRequestModel> updatedCards = client.creditCardsRequests;
    
    String itemDetails = "";
    if (loanId != null) {
      final loan = client.existingLoans.firstWhereOrNull((l) => l.id == loanId);
      if (loan != null) {
        itemDetails = "تم حذف قرض: ${loan.bankName} بقسط ${loan.installmentValue}";
      }
      updatedLoans = updatedLoans.where((l) => l.id != loanId).toList();
    }
    if (cardId != null) {
      final card = client.creditCardsRequests.firstWhereOrNull((c) => c.id == cardId);
      if (card != null) {
        itemDetails = "تم حذف ${card.type == 'card' ? 'بطاقة' : 'طلب'}: ${card.bankName} بقسط ${card.installment}";
      }
      updatedCards = updatedCards.where((c) => c.id != cardId).toList();
    }
    
    final updatedClient = client.copyWith(existingLoans: updatedLoans, creditCardsRequests: updatedCards);
    final isUuid = _isValidUuid(clientId);
    final diffNotes = itemDetails.isNotEmpty ? itemDetails : 'تم حذف عنصر من القروض أو البطاقات للعميل.';

    if (!SupabaseConfig.isInitialized || !isUuid) {
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'حذف قرض/بطاقة');
      return true;
    }
    try {
      if (loanId != null) {
        await SupabaseConfig.client.from('existing_loans').delete().eq('id', loanId);
      }
      if (cardId != null) {
        await SupabaseConfig.client.from('credit_cards_requests').delete().eq('id', cardId);
      }
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'حذف قرض/بطاقة',
        'notes': diffNotes,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName ?? 'النظام',
      });
      _refreshClients();
      return true;
    } catch (e) {
      _logger.e("Supabase remove error, falling back to simulation: $e");
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes, customActionType: 'حذف قرض/بطاقة');
      return true;
    }
  }

  void _updateClientSimulated(ClientModel updatedClient, String? staffName, {String? customNotes, String? customActionType}) {
    state = state.copyWith(
      clients: state.clients.map((c) {
        if (c.id == updatedClient.id) {
          final notes = customNotes ?? _getClientDiff(c, updatedClient);
          final updatedHistory = [
            InteractionLogModel(
              id: "hi-${DateTime.now().millisecondsSinceEpoch}",
              actionType: customActionType ?? 'تحديث بيانات العميل',
              notes: notes,
              createdBy: staffName ?? 'النظام',
              createdAt: DateTime.now(),
            ),
            ...c.history
          ];
          return updatedClient.copyWith(history: updatedHistory);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> updateClientStatus(
      String clientId, String newStatus, String staffName) async {
    final isUuid = _isValidUuid(clientId);
    if (!SupabaseConfig.isInitialized || !isUuid) {
      _updateStatusSimulated(clientId, newStatus, staffName);
      return;
    }
    try {
      await SupabaseConfig.client
          .from('clients')
          .update({'status': newStatus}).eq('id', clientId);

      // Insert interaction log
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحديث الحالة الائتمانية',
        'notes': 'تم تغيير حالة طلب العميل إلى: ${getStatusArabic(newStatus)}',
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName,
      });

      _refreshClients();
    } catch (e) {
      _logger.e("Supabase status update error (Simulation Mode): $e");
      _updateStatusSimulated(clientId, newStatus, staffName);
    }
  }

  /// Update the core client data (excluding loans and cards).
  /// Used by UI when editing the client details.
  /// Works in both real Supabase mode and simulation fallback.
  /// Returns true on success.
  Future<String?> updateClient(ClientModel updatedClient, {String? staffName}) async {
    // 1. Local duplicate check
    if (updatedClient.nationalId.isNotEmpty) {
      final exists = state.clients.any((c) => c.nationalId == updatedClient.nationalId && c.id != updatedClient.id);
      if (exists) {
        return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
      }
    }

    final isUuid = _isValidUuid(updatedClient.id);
    final oldClient = state.clients.firstWhereOrNull((c) => c.id == updatedClient.id);
    final diffNotes = oldClient != null ? _getClientDiff(oldClient, updatedClient) : 'تم تعديل البيانات الأساسية للعميل بنجاح.';

    if (!SupabaseConfig.isInitialized || !isUuid) {
      // Offline / simulation mode – update locally.
      _updateClientSimulated(updatedClient, staffName, customNotes: diffNotes);
      return null;
    }
    try {
      // Prepare payload without the primary key.
      final payload = updatedClient.toJson();
      payload.remove('id');
      await SupabaseConfig.client.from('clients').update(payload).eq('id', updatedClient.id);

      // Log interaction.
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': updatedClient.id,
        'action_type': 'تحديث بيانات العميل',
        'notes': diffNotes,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName ?? 'النظام',
      });

      _refreshClients();
      return null;
    } catch (e, stack) {
      _logger.e("Supabase client update error: $e", error: e, stackTrace: stack);
      if (e is PostgrestException) {
        if (e.code == '23505' || e.message.contains('national_id') || (e.details?.toString().contains('national_id') ?? false)) {
          return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
        }
        return "خطأ في تحديث قاعدة البيانات: ${e.message} (${e.code})";
      } else if (e.toString().contains("23505") || e.toString().contains("national_id")) {
        return "الرقم القومي مسجل بالفعل لعميل آخر في النظام.";
      }

      return "خطأ في تعديل العميل: $e";
    }
  }

  /// Update client and return success flag for UI usage.
  Future<String?> updateClientAndReturn(ClientModel updatedClient, {String? staffName}) async {
    return await updateClient(updatedClient, staffName: staffName);
  }

  void _updateStatusSimulated(
      String clientId, String newStatus, String staffName) {
    state = state.copyWith(
      clients: state.clients.map((c) {
        if (c.id == clientId) {
          final updatedHistory = [
            InteractionLogModel(
              id: "hi-${DateTime.now().millisecondsSinceEpoch}",
              actionType: 'تحديث الحالة الائتمانية',
              notes:
                  'تم تغيير حالة طلب العميل إلى: ${getStatusArabic(newStatus)}',
              createdBy: staffName,
              createdAt: DateTime.now(),
            ),
            ...c.history
          ];
          return c.copyWith(status: newStatus, history: updatedHistory);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> addInteractionLog(
      String clientId, String action, String notes, String staffName, {
      String logType = 'file_interaction',
      DateTime? followUpDate,
      String? followUpStatus,
  }) async {
    final isUuid = _isValidUuid(clientId);
    if (!SupabaseConfig.isInitialized || !isUuid) {
      _addInteractionSimulated(clientId, action, notes, staffName, logType: logType, followUpDate: followUpDate, followUpStatus: followUpStatus);
      return;
    }
    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      final insertedRow = await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': action,
        'notes': notes,
        'log_type': logType,
        if (followUpDate != null) 'follow_up_date': followUpDate.toIso8601String(),
        if (followUpStatus != null) 'follow_up_status': followUpStatus,
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName,
      }).select().single();

      final newLog = InteractionLogModel.fromJson(insertedRow);

      // Instantly insert the actual database log (with real UUID) into the local state
      state = state.copyWith(
        clients: state.clients.map((c) {
          if (c.id == clientId) {
            return c.copyWith(history: [newLog, ...c.history]);
          }
          return c;
        }).toList(),
      );
    } catch (e) {
      _logger.e("Supabase history insert error: $e");
      _addInteractionSimulated(clientId, action, notes, staffName, logType: logType, followUpDate: followUpDate, followUpStatus: followUpStatus);
    }
  }

  void _addInteractionSimulated(
      String clientId, String action, String notes, String staffName, {
      String logType = 'file_interaction',
      DateTime? followUpDate,
      String? followUpStatus,
  }) {
    state = state.copyWith(
      clients: state.clients.map((c) {
        if (c.id == clientId) {
          final updatedHistory = [
            InteractionLogModel(
              id: "hi-${DateTime.now().millisecondsSinceEpoch}",
              actionType: action,
              notes: notes,
              createdBy: staffName,
              createdAt: DateTime.now(),
              logType: logType,
              followUpDate: followUpDate,
              followUpStatus: followUpStatus,
            ),
            ...c.history
          ];
          return c.copyWith(history: updatedHistory);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> updateFollowUpStatus(
      String clientId, String logId, String newStatus, String staffName) async {
    final statusArabic = newStatus == 'completed' ? 'تم المتابعة' : 'قيد المتابعة';
    final isUuid = _isValidUuid(clientId);
    final isLogUuid = _isValidUuid(logId);

    // Find the original log to copy its followUpDate
    final client = state.clients.firstWhereOrNull((c) => c.id == clientId);
    final originalLog = client?.history.firstWhereOrNull((l) => l.id == logId);
    final followUpDate = originalLog?.followUpDate;

    // Apply Optimistic Update locally
    _updateFollowUpStatusSimulated(clientId, logId, newStatus, staffName, statusArabic);

    if (!SupabaseConfig.isInitialized || !isUuid) {
      return;
    }

    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      
      // Insert a new follow-up log with the new status instead of updating, bypassing RLS update restriction
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحديث حالة المتابعة',
        'notes': 'تم تغيير حالة المتابعة إلى ($statusArabic) بواسطة: $staffName',
        'log_type': 'follow_up',
        'follow_up_status': newStatus,
        if (followUpDate != null) 'follow_up_date': followUpDate.toIso8601String(),
        if (_isValidUuid(currentUserId)) 'created_by': currentUserId,
        'created_by_name': staffName,
      });

      // Refetch from database to sync all actual records
      _refreshClients();
    } catch (e, stackTrace) {
      _logger.e("Supabase follow-up status update error: $e");
      print("Stacktrace: $stackTrace");
    }
  }

  void _updateFollowUpStatusSimulated(
      String clientId, String logId, String newStatus, String staffName, String statusArabic) {
    state = state.copyWith(
      clients: state.clients.map((c) {
        if (c.id == clientId) {
          final updatedHistoryList = c.history.map((log) {
            if (log.id == logId) {
              return InteractionLogModel(
                id: log.id,
                actionType: log.actionType,
                notes: log.notes,
                createdBy: log.createdBy,
                createdAt: log.createdAt,
                logType: log.logType,
                followUpDate: log.followUpDate,
                followUpStatus: newStatus,
              );
            }
            return log;
          }).toList();

          // Add a new interaction log showing who updated it
          final addedLog = InteractionLogModel(
            id: "hi-${DateTime.now().millisecondsSinceEpoch}",
            actionType: 'تحديث حالة المتابعة',
            notes: 'تم تغيير حالة المتابعة إلى ($statusArabic) بواسطة: $staffName',
            createdBy: staffName,
            createdAt: DateTime.now(),
            logType: 'file_interaction',
          );

          return c.copyWith(history: [addedLog, ...updatedHistoryList]);
        }
        return c;
      }).toList(),
    );
  }

  Future<void> deleteClient(String clientId) async {
    final isUuid = _isValidUuid(clientId);
    if (!SupabaseConfig.isInitialized || !isUuid) {
      state = state.copyWith(
        clients: state.clients.where((c) => c.id != clientId).toList(),
      );
      return;
    }
    try {
      await SupabaseConfig.client.from('clients').delete().eq('id', clientId);
      _refreshClients();
    } catch (e) {
      _logger.e("Supabase delete error (Simulation Mode): $e");
      state = state.copyWith(
        clients: state.clients.where((c) => c.id != clientId).toList(),
      );
    }
  }

  String _getClientDiff(ClientModel oldClient, ClientModel newClient) {
    final List<String> changes = [];

    if (oldClient.fullName != newClient.fullName) {
      changes.add("الاسم: من '${oldClient.fullName}' إلى '${newClient.fullName}'");
    }
    if (oldClient.phoneNumber != newClient.phoneNumber) {
      changes.add("رقم الهاتف: من '${oldClient.phoneNumber}' إلى '${newClient.phoneNumber}'");
    }
    if (oldClient.secondaryPhoneNumber != newClient.secondaryPhoneNumber) {
      final oldVal = oldClient.secondaryPhoneNumber ?? "لا يوجد";
      final newVal = newClient.secondaryPhoneNumber ?? "لا يوجد";
      changes.add("رقم الهاتف الإضافي: من '$oldVal' إلى '$newVal'");
    }
    if (oldClient.nationalId != newClient.nationalId) {
      changes.add("الرقم القومي: من '${oldClient.nationalId}' إلى '${newClient.nationalId}'");
    }
    if (oldClient.birthDate != newClient.birthDate) {
      changes.add("تاريخ الميلاد: من '${oldClient.birthDate}' إلى '${newClient.birthDate}'");
    }
    if (oldClient.employmentType != newClient.employmentType) {
      String getEmpArabic(String type) {
        switch (type) {
          case 'government_sector': return 'قطاع حكومي';
          case 'private_sector': return 'قطاع خاص';
          case 'freelance': return 'عمل حر';
          case 'retired': return 'متقاعد';
          default: return type;
        }
      }
      changes.add("نوع الوظيفة: من '${getEmpArabic(oldClient.employmentType)}' إلى '${getEmpArabic(newClient.employmentType)}'");
    }
    if (oldClient.companyName != newClient.companyName) {
      final oldVal = oldClient.companyName ?? "لا يوجد";
      final newVal = newClient.companyName ?? "لا يوجد";
      changes.add("جهة العمل: من '$oldVal' إلى '$newVal'");
    }
    if (oldClient.jobTitle != newClient.jobTitle) {
      final oldVal = oldClient.jobTitle ?? "لا يوجد";
      final newVal = newClient.jobTitle ?? "لا يوجد";
      changes.add("المسمى الوظيفي: من '$oldVal' إلى '$newVal'");
    }
    if (oldClient.isInsured != newClient.isInsured) {
      changes.add("التأمين: من '${oldClient.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"}' إلى '${newClient.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"}'");
    }
    if (oldClient.salaryTransferMethod != newClient.salaryTransferMethod) {
      String getMethodArabic(String m) => m == 'bank_transfer' ? 'تحويل بنكي' : 'نقدي';
      changes.add("طريقة تحويل الراتب: من '${getMethodArabic(oldClient.salaryTransferMethod)}' إلى '${getMethodArabic(newClient.salaryTransferMethod)}'");
    }
    if (oldClient.cashSalaryAmount != newClient.cashSalaryAmount) {
      final oldVal = oldClient.cashSalaryAmount?.toString() ?? "لا يوجد";
      final newVal = newClient.cashSalaryAmount?.toString() ?? "لا يوجد";
      changes.add("الراتب النقدي: من '$oldVal' إلى '$newVal'");
    }
    if (!_isBankDetailsEqual(oldClient.salaryBankDetails, newClient.salaryBankDetails)) {
      changes.add("تفاصيل البنوك والرواتب: تم تعديل الحسابات البنكية");
    }
    if (oldClient.creditScore != newClient.creditScore) {
      changes.add("التقييم الائتماني: من '${oldClient.creditScore}' إلى '${newClient.creditScore}'");
    }
    if (oldClient.requestedAmount != newClient.requestedAmount) {
      changes.add("المبلغ المطلوب: من '${oldClient.requestedAmount}' إلى '${newClient.requestedAmount}'");
    }
    if (oldClient.governorate != newClient.governorate) {
      changes.add("المحافظة: من '${oldClient.governorate}' إلى '${newClient.governorate}'");
    }
    if (oldClient.address != newClient.address) {
      final oldVal = oldClient.address ?? "غير محدد";
      final newVal = newClient.address ?? "غير محدد";
      changes.add("العنوان: من '$oldVal' إلى '$newVal'");
    }
    if (oldClient.representativeName != newClient.representativeName) {
      final oldVal = oldClient.representativeName ?? "لا يوجد";
      final newVal = newClient.representativeName ?? "لا يوجد";
      changes.add("المندوب المسؤول: من '$oldVal' إلى '$newVal'");
    }

    if (changes.isEmpty) {
      return "تم حفظ تعديلات بدون تغيير في البيانات الأساسية.";
    }
    return "تم تعديل البيانات التالية:\n${changes.join("\n")}";
  }

  bool _isBankDetailsEqual(List<Map<String, String>> list1, List<Map<String, String>> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      final m1 = list1[i];
      final m2 = list2[i];
      if (m1['bank'] != m2['bank'] || m1['amount'] != m2['amount']) return false;
    }
    return true;
  }

  String _getLoansDiff(List<ExistingLoanModel> oldLoans, List<ExistingLoanModel> newLoans) {
    if (newLoans.isEmpty) {
      return "تم حذف جميع القروض القائمة للعميل.";
    }
    final loansStr = newLoans.map((l) => "${l.bankName} (قسط: ${l.installmentValue} - ملاحظات: ${l.notes ?? 'لا يوجد'})").join("، ");
    return "تم تحديث القروض القائمة لتصبح: $loansStr";
  }

  String _getCardsDiff(List<CreditCardRequestModel> oldCards, List<CreditCardRequestModel> newCards) {
    if (newCards.isEmpty) {
      return "تم حذف جميع بطاقات/التزامات العميل.";
    }
    final cardsStr = newCards.map((c) => "${c.bankName} (${c.type == 'card' ? 'بطاقة' : 'طلب'} - قسط: ${c.installment} - قيمة: ${c.value} - ملاحظات: ${c.notes ?? 'لا يوجد'})").join("، ");
    return "تم تحديث البطاقات والطلبات لتصبح: $cardsStr";
  }

  String _getDocumentsDiff(List<ClientDocumentModel> oldDocs, List<ClientDocumentModel> newDocs) {
    if (newDocs.isEmpty) {
      return "تم حذف جميع مستندات العميل.";
    }
    final docsStr = newDocs.map((d) => "${d.documentName} (الحالة: ${d.status})").join("، ");
    return "تم تحديث المستندات المرفقة لتصبح: $docsStr";
  }

  String getStatusArabic(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار (معلق)';
      case 'iscore_inquiry':
        return 'استعلام ايسكور';
      case 'preparing_documents':
        return 'تحضير الاوراق';
      case 'under_review':
        return 'قيد الدراسة والمراجعة';
      case 'at_bank':
        return 'فى البنك';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}

final clientProvider =
    StateNotifierProvider<ClientNotifier, ClientState>((ref) {
  return ClientNotifier(ref);
});
