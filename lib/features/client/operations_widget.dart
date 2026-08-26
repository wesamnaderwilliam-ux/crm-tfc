import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../models/client_model.dart';

final operationsRefreshTriggerProvider = StateProvider<int>((ref) => 0);

class OperationEntry {
  final String id;
  final String clientId;
  final String bankName;
  final String programName;
  final String employeeName;
  final double requestedAmount;
  String status; // 'working', 'approved', 'rejected'
  final DateTime transferDate;
  DateTime? approvalDate;
  double? approvedAmount;
  bool hasInvoice;
  double? invoicePercentage;
  double? invoiceFees;
  String? invoiceCollected; // 'collected', 'not_collected'

  OperationEntry({
    required this.id,
    required this.clientId,
    required this.bankName,
    required this.programName,
    required this.employeeName,
    required this.requestedAmount,
    required this.status,
    required this.transferDate,
    this.approvalDate,
    this.approvedAmount,
    this.hasInvoice = false,
    this.invoicePercentage,
    this.invoiceFees,
    this.invoiceCollected,
  });

  factory OperationEntry.fromJson(Map<String, dynamic> json) {
    return OperationEntry(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      bankName: json['bank_name'] ?? '',
      programName: json['program_name'] ?? '',
      employeeName: json['employee_name'] ?? 'لم يحدد',
      requestedAmount: (json['requested_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'working',
      transferDate: json['transfer_date'] != null
          ? DateTime.parse(json['transfer_date'])
          : DateTime.now(),
      approvalDate: json['approval_date'] != null
          ? DateTime.parse(json['approval_date'])
          : null,
      approvedAmount: (json['approved_amount'] as num?)?.toDouble(),
      hasInvoice: json['has_invoice'] ?? false,
      invoicePercentage: (json['invoice_percentage'] as num?)?.toDouble(),
      invoiceFees: (json['invoice_fees'] as num?)?.toDouble(),
      invoiceCollected: json['invoice_collected'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'bank_name': bankName,
      'program_name': programName,
      'employee_name': employeeName,
      'requested_amount': requestedAmount,
      'status': status,
      'transfer_date': transferDate.toIso8601String(),
      'approval_date': approvalDate?.toIso8601String(),
      'approved_amount': approvedAmount,
      'has_invoice': hasInvoice,
      'invoice_percentage': invoicePercentage,
      'invoice_fees': invoiceFees,
      'invoice_collected': invoiceCollected,
    };
  }
}

class OperationsWidget extends ConsumerStatefulWidget {
  final String clientId;
  const OperationsWidget({super.key, required this.clientId});

  // Temporary local cache for simulation mode
  static final List<OperationEntry> _localMockOperations = [];

  // Static helper to add operation from external widgets (like Distribution)
  static Future<void> addOperation({
    required String clientId,
    required String bankName,
    required String programName,
    required String employeeName,
    required double requestedAmount,
    String? staffName,
  }) async {
    final newOpData = {
      'client_id': clientId,
      'bank_name': bankName,
      'program_name': programName,
      'employee_name': employeeName,
      'requested_amount': requestedAmount,
      'status': 'working',
      'transfer_date': DateTime.now().toIso8601String(),
    };

    if (SupabaseConfig.isInitialized) {
      await SupabaseConfig.client.from('operation_entries').insert(newOpData);
      
      // Log interaction
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      final creator = staffName ?? 'النظام';
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': clientId,
        'action_type': 'تحويل للعمليات',
        'notes': 'تم تحويل المعاملة للعمليات (البنك: $bankName، البرنامج: $programName) بواسطة: $creator',
        if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
        'created_by_name': creator,
      });
    } else {
      _localMockOperations.add(OperationEntry(
        id: "mock-op-${DateTime.now().millisecondsSinceEpoch}",
        clientId: clientId,
        bankName: bankName,
        programName: programName,
        employeeName: employeeName,
        requestedAmount: requestedAmount,
        status: 'working',
        transferDate: DateTime.now(),
      ));
      
      // Update local client simulated history (cannot use ref since this is static, but we can access/modify the list if needed. However, since this is a static method we do not have 'ref'. 
      // Instead, the calling widget will trigger the rebuild/refresh. Let's make sure the calling widget handles refresh or passes a ref if needed. In distribution_widget, ref.read(clientProvider.notifier) is already available so we can call it there.
    }
  }

  @override
  ConsumerState<OperationsWidget> createState() => _OperationsWidgetState();
}

class _OperationsWidgetState extends ConsumerState<OperationsWidget> {
  bool _isLoading = false;
  List<OperationEntry> _operations = [];

  @override
  void initState() {
    super.initState();
    _loadOperations();
  }

  Future<void> _loadOperations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!SupabaseConfig.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 400));
        setState(() {
          _operations = OperationsWidget._localMockOperations
              .where((op) => op.clientId == widget.clientId)
              .toList();
          _isLoading = false;
        });
        return;
      }

      List<dynamic> rows = [];
      try {
        final response = await SupabaseConfig.client
            .from('operation_entries')
            .select('*')
            .eq('client_id', widget.clientId);
        rows = response as List<dynamic>;
      } catch (dbError) {
        debugPrint("Remote columns missing, retrying query with basic fields: $dbError");
        // Safe retry without the new invoice columns if the schema is not updated yet
        final response = await SupabaseConfig.client
            .from('operation_entries')
            .select('id, client_id, bank_name, program_name, employee_name, requested_amount, status, transfer_date, approval_date, approved_amount')
            .eq('client_id', widget.clientId);
        rows = response as List<dynamic>;
      }

      final authState = ref.read(authProvider);
      final bool isUserAdmin = authState.role == 'admin';
      final bool isBankEmp = authState.role == 'bank_employee';
      final String userFullName = authState.fullName.trim().toLowerCase();
      final String userBankName = authState.bankName?.trim().toLowerCase() ?? '';

      final loaded = rows.map((r) {
        final entry = OperationEntry.fromJson(r);
        if (!isUserAdmin) {
          final cleanName = entry.employeeName.replaceAll(RegExp(r'[-–—\s]*\b0\d{8,12}\b'), '').trim();
          return OperationEntry(
            id: entry.id,
            clientId: entry.clientId,
            bankName: entry.bankName,
            programName: entry.programName,
            employeeName: cleanName,
            requestedAmount: entry.requestedAmount,
            status: entry.status,
            transferDate: entry.transferDate,
            approvalDate: entry.approvalDate,
            approvedAmount: entry.approvedAmount,
            hasInvoice: entry.hasInvoice,
            invoicePercentage: entry.invoicePercentage,
            invoiceFees: entry.invoiceFees,
            invoiceCollected: entry.invoiceCollected,
          );
        }
        return entry;
      }).where((op) {
        if (!isBankEmp) return true;
        final opEmp = op.employeeName.trim().toLowerCase();
        final matchesEmp = userFullName.isNotEmpty && opEmp.isNotEmpty && (opEmp.contains(userFullName) || userFullName.contains(opEmp));
        return matchesEmp;
      }).toList();

      if (mounted) {
        setState(() {
          _operations = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading operations: $e");
      // Fallback to local mock if table doesn't exist
      if (mounted) {
        setState(() {
          _operations = OperationsWidget._localMockOperations
              .where((op) => op.clientId == widget.clientId)
              .toList();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateOperation(OperationEntry op) async {
    try {
      final authState = ref.read(authProvider);
      final staffName = authState.fullName;

      if (SupabaseConfig.isInitialized) {
        try {
          // Attempt full update including invoice fields
          await SupabaseConfig.client
              .from('operation_entries')
              .update({
                'status': op.status,
                'approval_date': op.approvalDate?.toIso8601String(),
                'approved_amount': op.approvedAmount,
                'has_invoice': op.hasInvoice,
                'invoice_percentage': op.invoicePercentage,
                'invoice_fees': op.invoiceFees,
                'invoice_collected': op.invoiceCollected,
              })
              .eq('id', op.id);
        } catch (updateError) {
          debugPrint("Failed to update invoice columns, falling back to basic columns update: $updateError");
          // Fallback to basic fields if schema is not migrated yet
          await SupabaseConfig.client
              .from('operation_entries')
              .update({
                'status': op.status,
                'approval_date': op.approvalDate?.toIso8601String(),
                'approved_amount': op.approvedAmount,
              })
              .eq('id', op.id);
        }

        // Log transaction history
        final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
        String statusArabic = op.status == 'approved'
            ? 'موافقة'
            : op.status == 'rejected'
                ? 'رفض'
                : 'يتم العمل';
        
        await SupabaseConfig.client.from('interaction_history').insert({
          'client_id': op.clientId,
          'action_type': 'تحديث حالة العملية',
          'notes': 'تم تحديث حالة العملية لـ (${op.bankName}) لتصبح ($statusArabic) بواسطة: $staffName',
          if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
          'created_by_name': staffName,
        });

        // Trigger updates in other widgets
        ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: ref.read(authProvider).bankEmployeeId);
        ref.read(operationsRefreshTriggerProvider.notifier).state++;
      } else {
        final idx = OperationsWidget._localMockOperations.indexWhere((o) => o.id == op.id);
        if (idx != -1) {
          OperationsWidget._localMockOperations[idx] = op;
        }
        
        // Simulation log update
        final clientState = ref.read(clientProvider);
        final client = clientState.clients.firstWhereOrNull((c) => c.id == op.clientId);
        if (client != null) {
          String statusArabic = op.status == 'approved'
              ? 'موافقة'
              : op.status == 'rejected'
                  ? 'رفض'
                  : 'يتم العمل';
          final newHistory = [
            InteractionLogModel(
              id: "hi-${DateTime.now().millisecondsSinceEpoch}",
              actionType: 'تحديث حالة العملية',
              notes: 'تم تحديث حالة العملية لـ (${op.bankName}) لتصبح ($statusArabic) بواسطة: $staffName',
              createdBy: staffName,
              createdAt: DateTime.now(),
            ),
            ...client.history
          ];
          ref.read(clientProvider.notifier).state = clientState.copyWith(
            clients: clientState.clients.map((c) => c.id == op.clientId ? c.copyWith(history: newHistory) : c).toList(),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث حالة العملية بنجاح", textAlign: TextAlign.right),
            backgroundColor: TfcColors.success,
          ),
        );
        _loadOperations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء تحديث العملية: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  void _confirmDeleteOperation(OperationEntry op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: const Text("تأكيد حذف العملية", textAlign: TextAlign.right),
        content: const Text(
          "هل أنت متأكد من رغبتك في حذف هذه العملية نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteOperation(op);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("حذف نهائي", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOperation(OperationEntry op) async {
    final authState = ref.read(authProvider);
    final staffName = authState.fullName;

    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('operation_entries')
            .delete()
            .eq('id', op.id);

        final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
        await SupabaseConfig.client.from('interaction_history').insert({
          'client_id': op.clientId,
          'action_type': 'حذف عملية',
          'notes': 'تم حذف العملية لـ (${op.bankName}) بواسطة المدير: $staffName',
          if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
          'created_by_name': staffName,
        });

        ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: ref.read(authProvider).bankEmployeeId);
      } else {
        OperationsWidget._localMockOperations.removeWhere((o) => o.id == op.id);

        // Simulation log update
        final clientState = ref.read(clientProvider);
        final client = clientState.clients.firstWhereOrNull((c) => c.id == op.clientId);
        if (client != null) {
          final newHistory = [
            InteractionLogModel(
              id: "hi-${DateTime.now().millisecondsSinceEpoch}",
              actionType: 'حذف عملية',
              notes: 'تم حذف العملية لـ (${op.bankName}) بواسطة المدير: $staffName',
              createdBy: staffName,
              createdAt: DateTime.now(),
            ),
            ...client.history
          ];
          ref.read(clientProvider.notifier).state = clientState.copyWith(
            clients: clientState.clients.map((c) => c.id == op.clientId ? c.copyWith(history: newHistory) : c).toList(),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم حذف العملية بنجاح", textAlign: TextAlign.right),
            backgroundColor: TfcColors.success,
          ),
        );
        _loadOperations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء حذف العملية: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  void _showAddOperationForBankDialog() {
    final authState = ref.read(authProvider);
    final bankName = authState.bankName ?? 'البنك';
    final empName = authState.fullName.isNotEmpty ? authState.fullName : 'موظف بنك';
    final programCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("إضافة عملية جديدة للعميل", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("البنك: $bankName", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Text("الموظف: $empName", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: programCtrl,
                      decoration: const InputDecoration(
                        labelText: "اسم البرنامج التمويلي",
                        hintText: "مثال: تمويل شخصي بضمان المرتب",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "قيمة القرض / المبلغ المطلوب (ج.م)",
                        hintText: "مثال: 150000",
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          textDirection: TextDirection.rtl,
                          children: [
                            const Text("تاريخ التحويل / الإضافة:", style: TextStyle(color: TfcColors.outline)),
                            Text(
                              "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final progName = programCtrl.text.trim();
                  final reqAmt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (progName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال اسم البرنامج", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  await OperationsWidget.addOperation(
                    clientId: widget.clientId,
                    bankName: bankName,
                    programName: progName,
                    employeeName: empName,
                    requestedAmount: reqAmt,
                    staffName: empName,
                  );
                  _loadOperations();
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ وإضافة العملية", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditOperationLoanAndDateDialog(OperationEntry op) {
    final amountCtrl = TextEditingController(text: op.requestedAmount.toString());
    DateTime selectedDate = op.transferDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("تعديل قيمة القرض والتاريخ", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "قيمة القرض / المبلغ المطلوب (ج.م)",
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          const Text("تاريخ العملية:", style: TextStyle(color: TfcColors.outline)),
                          Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newAmt = double.tryParse(amountCtrl.text.trim()) ?? op.requestedAmount;
                  if (SupabaseConfig.isInitialized) {
                    await SupabaseConfig.client.from('operation_entries').update({
                      'requested_amount': newAmt,
                      'transfer_date': selectedDate.toIso8601String(),
                    }).eq('id', op.id);
                  }
                  Navigator.pop(ctx);
                  _loadOperations();
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ التعديل", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditStatusDialog(OperationEntry op) {
    String selectedStatus = op.status;
    final amountCtrl = TextEditingController(text: op.approvedAmount?.toString() ?? '');
    DateTime? selectedDate = op.approvalDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("تحديث حالة العملية", textAlign: TextAlign.right),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: DropdownButtonFormField<String>(
                    value: selectedStatus,
                    dropdownColor: TfcColors.surfaceDim,
                    decoration: const InputDecoration(labelText: "الحالة"),
                    items: const [
                      DropdownMenuItem(value: 'working', child: Text("يتم العمل ⚙️")),
                      DropdownMenuItem(value: 'approved', child: Text("موافقة ✅")),
                      DropdownMenuItem(value: 'rejected', child: Text("رفض ❌")),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedStatus = val;
                        });
                      }
                    },
                  ),
                ),
                if (selectedStatus == 'approved') ...[
                  const SizedBox(height: 12),
                  // Approved Amount
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "مبلغ الموافقة (ج.م)",
                        hintText: "مثال: 500000",
                      ),
                    ),
                  ),
                ],
                if (selectedStatus == 'approved' || selectedStatus == 'rejected') ...[
                  const SizedBox(height: 12),
                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text(
                            selectedStatus == 'approved' ? "تاريخ الموافقة:" : "تاريخ الرفض:",
                            style: const TextStyle(color: TfcColors.outline),
                          ),
                          Text(
                            selectedDate != null
                                ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                                : "اختر التاريخ",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () {
                  op.status = selectedStatus;
                  if (selectedStatus == 'approved') {
                    op.approvedAmount = double.tryParse(amountCtrl.text);
                    op.approvalDate = selectedDate ?? DateTime.now();
                  } else if (selectedStatus == 'rejected') {
                    op.approvedAmount = null;
                    op.approvalDate = selectedDate ?? DateTime.now();
                  } else {
                    op.approvedAmount = null;
                    op.approvalDate = null;
                  }
                  Navigator.pop(ctx);
                  _updateOperation(op);
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ التغييرات", style: TextStyle(color: Colors.black)),
              ),
            ],
          );
        },
      ),
    );
  }
  void _showCreateInvoiceDialog(OperationEntry op) {
    final percentCtrl = TextEditingController();
    double feesResult = 0.0;
    final approvedAmount = op.approvedAmount ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("عمل فاتورة جديدة", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("مبلغ الموافقة: ${_formatNumber(approvedAmount)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "نسبة الأتعاب المستحقة (%)",
                      hintText: "مثال: 5",
                    ),
                    onChanged: (val) {
                      final parsedPercent = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        feesResult = (approvedAmount * parsedPercent) / 100;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("مبلغ الأتعاب المقدر:", style: TextStyle(color: TfcColors.outline)),
                        Text("${_formatNumber(feesResult)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () {
                  final percent = double.tryParse(percentCtrl.text) ?? 0.0;
                  if (percent <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("الرجاء إدخال نسبة أتعاب صحيحة", textAlign: TextAlign.right),
                        backgroundColor: TfcColors.error,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    op.hasInvoice = true;
                    op.invoicePercentage = percent;
                    op.invoiceFees = (approvedAmount * percent) / 100;
                    op.invoiceCollected = 'not_collected';
                  });
                  Navigator.pop(ctx);
                  _updateOperation(op);
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("إنشاء وحفظ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditInvoiceDialog(OperationEntry op) {
    final percentCtrl = TextEditingController(text: (op.invoicePercentage ?? 0).toString());
    final approvedAmount = op.approvedAmount ?? 0.0;
    double feesResult = op.invoiceFees ?? 0.0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("تعديل الفاتورة", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("مبلغ الموافقة: ${_formatNumber(approvedAmount)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: percentCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "نسبة الأتعاب المستحقة (%)",
                      hintText: "مثال: 5",
                    ),
                    onChanged: (val) {
                      final parsedPercent = double.tryParse(val) ?? 0.0;
                      setDialogState(() {
                        feesResult = (approvedAmount * parsedPercent) / 100;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("مبلغ الأتعاب المقدر:", style: TextStyle(color: TfcColors.outline)),
                        Text("${_formatNumber(feesResult)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.success)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () {
                  final percent = double.tryParse(percentCtrl.text) ?? 0.0;
                  if (percent <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("الرجاء إدخال نسبة أتعاب صحيحة", textAlign: TextAlign.right),
                        backgroundColor: TfcColors.error,
                      ),
                    );
                    return;
                  }
                  setState(() {
                    op.invoicePercentage = percent;
                    op.invoiceFees = (approvedAmount * percent) / 100;
                  });
                  Navigator.pop(ctx);
                  _updateOperation(op);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ تم تعديل الفاتورة بنجاح", textAlign: TextAlign.right),
                      backgroundColor: TfcColors.success,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteInvoice(OperationEntry op) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: const Text("حذف الفاتورة", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: const Directionality(
          textDirection: TextDirection.rtl,
          child: Text("هل أنت متأكد من حذف هذه الفاتورة؟ سيتم إزالة جميع بيانات الأتعاب المسجلة."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                op.hasInvoice = false;
                op.invoicePercentage = null;
                op.invoiceFees = null;
                op.invoiceCollected = null;
              });
              Navigator.pop(ctx);
              _updateOperation(op);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("🗑️ تم حذف الفاتورة بنجاح", textAlign: TextAlign.right),
                  backgroundColor: TfcColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(operationsRefreshTriggerProvider, (previous, next) {
      _loadOperations();
    });

    final authState = ref.watch(authProvider);
    final isStrictAdmin = authState.role == 'admin';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: Colors.blueAccent.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_suggest_outlined, color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "متابعة العمليات القائمة",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: TfcColors.onSurface,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (authState.role == 'bank_employee') ...[
                ElevatedButton.icon(
                  onPressed: _showAddOperationForBankDialog,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text("إضافة عملية", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: TfcColors.primary),
              ),
            )
          else if (_operations.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(Icons.assignment_turned_in_outlined,
                      color: TfcColors.outline.withValues(alpha: 0.3), size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    "لا توجد عمليات محولة لهذا العميل حالياً",
                    style: TextStyle(color: TfcColors.outline, fontSize: 13),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _operations.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 24),
              itemBuilder: (context, index) {
                final op = _operations[index];
                final statusColor = _getStatusColor(op.status);
                final statusLabel = _getStatusLabel(op.status);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.01),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            op.bankName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          _buildStatusChip(op.status),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Info Rows
                      _buildDetailRow("البرنامج", op.programName),
                      _buildDetailRow("الموظف", op.employeeName),
                      _buildDetailRow("المبلغ المطلوب", "${_formatNumber(op.requestedAmount)} ج.م"),
                      _buildDetailRow(
                        "تاريخ التحويل",
                        "${op.transferDate.day}/${op.transferDate.month}/${op.transferDate.year}",
                      ),

                      if (op.status == 'approved') ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          "مبلغ الموافقة",
                          op.approvedAmount != null ? "${_formatNumber(op.approvedAmount!)} ج.م" : "—",
                          highlight: true,
                        ),
                        _buildDetailRow(
                          "تاريخ الموافقة",
                          op.approvalDate != null
                              ? "${op.approvalDate!.day}/${op.approvalDate!.month}/${op.approvalDate!.year}"
                              : "—",
                          highlight: true,
                        ),

                        // --- Invoice Card section ---
                        if (op.hasInvoice) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: TfcColors.primary.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: TfcColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  textDirection: TextDirection.rtl,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(Icons.receipt_long, color: TfcColors.primary, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          "بيانات الفاتورة",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TfcColors.primary),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: op.invoiceCollected == 'collected'
                                            ? TfcColors.success.withValues(alpha: 0.15)
                                            : TfcColors.error.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        op.invoiceCollected == 'collected' ? "تم التحصيل ✅" : "لم يتم التحصيل ❌",
                                        style: TextStyle(
                                          color: op.invoiceCollected == 'collected' ? TfcColors.success : TfcColors.error,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildDetailRow("نسبة الأتعاب", "${op.invoicePercentage ?? 0}%"),
                                _buildDetailRow("مبلغ الأتعاب المستحق", "${_formatNumber(op.invoiceFees ?? 0)} ج.م", highlight: true),
                                
                                // Admin Collection Action Buttons
                                if (isStrictAdmin) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            op.invoiceCollected = 'collected';
                                          });
                                          _updateOperation(op);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TfcColors.success.withValues(alpha: 0.2),
                                          foregroundColor: TfcColors.success,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: const BorderSide(color: TfcColors.success, width: 0.5),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check, size: 14),
                                        label: const Text("تم التحصيل", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            op.invoiceCollected = 'not_collected';
                                          });
                                          _updateOperation(op);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TfcColors.error.withValues(alpha: 0.2),
                                          foregroundColor: TfcColors.error,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: const BorderSide(color: TfcColors.error, width: 0.5),
                                          ),
                                        ),
                                        icon: const Icon(Icons.close, size: 14),
                                        label: const Text("لم يتم التحصيل", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  // Admin Edit/Delete Invoice Buttons
                                  const Divider(color: Colors.white12, height: 20),
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showEditInvoiceDialog(op),
                                        icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.orangeAccent),
                                        label: const Text("تعديل الفاتورة", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () => _confirmDeleteInvoice(op),
                                        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                                        label: const Text("حذف الفاتورة", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ] else if (op.status == 'rejected' && op.approvalDate != null) ...[
                        const SizedBox(height: 8),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          "تاريخ الرفض",
                          "${op.approvalDate!.day}/${op.approvalDate!.month}/${op.approvalDate!.year}",
                          highlight: false,
                        ),
                      ],

                      if (isStrictAdmin) ...[
                        const SizedBox(height: 12),
                        Row(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (op.status == 'approved' && !op.hasInvoice) ...[
                              TextButton.icon(
                                onPressed: () => _showCreateInvoiceDialog(op),
                                icon: const Icon(Icons.receipt_long, size: 14, color: TfcColors.secondary),
                                label: const Text("عمل فاتورة",
                                    style: TextStyle(color: TfcColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            TextButton.icon(
                              onPressed: () => _showEditStatusDialog(op),
                              icon: const Icon(Icons.edit, size: 14, color: TfcColors.primary),
                              label: const Text("تحديث الحالة والبيانات",
                                  style: TextStyle(color: TfcColors.primary, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _confirmDeleteOperation(op),
                              icon: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                              label: const Text("حذف العملية",
                                  style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                            ),
                          ],
                        ),
                      ] else if (authState.role == 'bank_employee') ...[
                        const SizedBox(height: 12),
                        Row(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () => _showEditOperationLoanAndDateDialog(op),
                              icon: const Icon(Icons.edit_calendar, size: 14, color: Colors.tealAccent),
                              label: const Text("تعديل قيمة القرض والتاريخ",
                                  style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _showEditStatusDialog(op),
                              icon: const Icon(Icons.swap_horiz, size: 14, color: TfcColors.primary),
                              label: const Text("تغيير الحالة",
                                  style: TextStyle(color: TfcColors.primary, fontSize: 12)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: highlight ? TfcColors.success : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = TfcColors.warning;
    String label = "يتم العمل";
    if (status == 'approved') {
      color = TfcColors.success;
      label = "موافقة";
    } else if (status == 'rejected') {
      color = TfcColors.error;
      label = "رفض";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'approved') return TfcColors.success;
    if (status == 'rejected') return TfcColors.error;
    return TfcColors.warning;
  }

  String _getStatusLabel(String status) {
    if (status == 'approved') return "موافقة";
    if (status == 'rejected') return "رفض";
    return "يتم العمل";
  }

  String _formatNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
