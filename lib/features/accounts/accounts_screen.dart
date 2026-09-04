import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import '../client/operations_widget.dart';
import '../../models/profile.dart';

class ExpenseModel {
  final String id;
  final String title;
  final double amount;
  final DateTime expenseDate;
  final String? notes;

  ExpenseModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.expenseDate,
    this.notes,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      expenseDate: json['expense_date'] != null
          ? DateTime.parse(json['expense_date'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }
}

class AccountsScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;
  const AccountsScreen({super.key, required this.onViewClient});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _selectedMonth = ""; // Format: YYYY-MM
  List<OperationEntry> _allOperations = [];
  List<ExpenseModel> _allExpenses = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _selectedMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (!SupabaseConfig.isInitialized) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch operations with invoices for the selected month
      final opsResponse = await SupabaseConfig.client
          .from('operation_entries')
          .select('*')
          .eq('has_invoice', true);

      // 2. Fetch expenses
      final expResponse = await SupabaseConfig.client
          .from('expenses')
          .select('*');

      final List<dynamic> opsRows = opsResponse as List<dynamic>;
      final List<dynamic> expRows = expResponse as List<dynamic>;

      if (mounted) {
        setState(() {
          _allOperations = opsRows.map((r) => OperationEntry.fromJson(r)).toList();
          _allExpenses = expRows.map((r) => ExpenseModel.fromJson(r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading accounts data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Filter operations by the selected month (using approvalDate)
  List<OperationEntry> _getFilteredOperations() {
    final parts = _selectedMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    return _allOperations.where((op) {
      if (op.approvalDate == null) return false;
      return op.approvalDate!.year == year && op.approvalDate!.month == month;
    }).toList();
  }

  // Filter expenses by the selected month
  List<ExpenseModel> _getFilteredExpenses() {
    final parts = _selectedMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    return _allExpenses.where((exp) {
      return exp.expenseDate.year == year && exp.expenseDate.month == month;
    }).toList();
  }

  void _showAddExpenseDialog() {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text(
              "إضافة مصروف جديد",
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.9,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "عنوان المصروف",
                        hintText: "مثال: إيجار المكتب، فاتورة كهرباء",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "المبلغ (ج.م)",
                        hintText: "مثال: 5000",
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha: 0.02),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("تاريخ المصروف:", style: TextStyle(color: TfcColors.outline)),
                            Text("${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: "ملاحظات إضافية",
                        hintText: "أي تفاصيل أخرى",
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
                  final title = titleController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (title.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال بيانات صحيحة", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  // Optimistic add - show instantly
                  final tempExpense = ExpenseModel(
                    id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    amount: amount,
                    expenseDate: selectedDate,
                    notes: notesController.text.trim(),
                  );
                  setState(() {
                    _allExpenses.add(tempExpense);
                  });
                  // Background server sync
                  SupabaseConfig.client.from('expenses').insert({
                    'title': title,
                    'amount': amount,
                    'expense_date': "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                    'notes': notesController.text.trim(),
                  }).then((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ تم إضافة المصروف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success, duration: Duration(seconds: 1)),
                      );
                      _loadData(); // sync real IDs
                    }
                  }).catchError((e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("خطأ أثناء الإضافة: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                      );
                      _loadData();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ المصروف", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditExpenseDialog(ExpenseModel expense) {
    final titleController = TextEditingController(text: expense.title);
    final amountController = TextEditingController(text: expense.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: expense.notes);
    DateTime selectedDate = expense.expenseDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text(
              "تعديل المصروف",
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.9,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "عنوان المصروف",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "المبلغ (ج.م)",
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white.withValues(alpha: 0.02),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("تاريخ المصروف:", style: TextStyle(color: TfcColors.outline)),
                            Text("${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: "ملاحظات إضافية",
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
                  final title = titleController.text.trim();
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (title.isEmpty || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال بيانات صحيحة", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  // Optimistic edit - update locally instantly
                  setState(() {
                    final idx = _allExpenses.indexWhere((e) => e.id == expense.id);
                    if (idx != -1) {
                      _allExpenses[idx] = ExpenseModel(
                        id: expense.id,
                        title: title,
                        amount: amount,
                        expenseDate: selectedDate,
                        notes: notesController.text.trim(),
                      );
                    }
                  });
                  // Background server sync
                  SupabaseConfig.client.from('expenses').update({
                    'title': title,
                    'amount': amount,
                    'expense_date': "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
                    'notes': notesController.text.trim(),
                  }).eq('id', expense.id).then((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("✅ تم تعديل المصروف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success, duration: Duration(seconds: 1)),
                      );
                    }
                  }).catchError((e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("خطأ أثناء التعديل: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                      );
                      _loadData();
                    }
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ التعديلات", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteExpenseConfirm(ExpenseModel expense) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: const Text("تأكيد حذف المصروف", textAlign: TextAlign.right, style: TextStyle(color: TfcColors.error, fontWeight: FontWeight.bold)),
        content: Text("هل أنت متأكد من رغبتك في حذف المصروف \"${expense.title}\" بقيمة ${_fmt(expense.amount)} ج.م؟", textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Optimistic delete - remove locally instantly
              setState(() {
                _allExpenses.removeWhere((e) => e.id == expense.id);
              });
              // Background server sync
              SupabaseConfig.client.from('expenses').delete().eq('id', expense.id).then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ تم حذف المصروف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success, duration: Duration(seconds: 1)),
                  );
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ أثناء الحذف: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                  );
                  _loadData();
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.error),
            child: const Text("حذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: TfcColors.primary));
    }

    final filteredOps = _getFilteredOperations();
    final filteredExpenses = _getFilteredExpenses();
    final employees = ref.read(employeesProvider).employees;

    // 1. Calculate Revenue aggregations
    double totalFeesDue = 0.0;
    double collectedFees = 0.0;
    double uncollectedFees = 0.0;

    double totalEmpCommission = 0.0;
    double totalMgrCommission = 0.0;
    double totalOfficeShare = 0.0;

    double collectedOfficeShare = 0.0;

    for (final op in filteredOps) {
      final fees = op.invoiceFees ?? 0.0;
      totalFeesDue += fees;

      final isCollected = op.invoiceCollected == 'collected';
      if (isCollected) {
        collectedFees += fees;
      } else {
        uncollectedFees += fees;
      }

      // Map representative to find manager
      final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
      final repName = (client?.representativeName ?? '').toLowerCase().trim();
      final empProfile = employees.firstWhereOrNull((e) => e.fullName.toLowerCase().trim() == repName);

      double empComm = fees * 0.10;
      double mgrComm = 0.0;
      double officeShare = 0.0;

      if (empProfile != null && empProfile.managerId != null) {
        final manager = employees.firstWhereOrNull((e) => e.id == empProfile.managerId);
        if (manager != null && manager.role != 'admin') {
          mgrComm = fees * 0.05;
        }
      }

      officeShare = fees - (empComm + mgrComm);

      totalEmpCommission += empComm;
      totalMgrCommission += mgrComm;
      totalOfficeShare += officeShare;

      if (isCollected) {
        collectedOfficeShare += officeShare;
      }
    }

    // Expenses total
    double totalExpensesAmount = 0.0;
    for (final exp in filteredExpenses) {
      totalExpensesAmount += exp.amount;
    }

    // Profit Calculations
    final netAccruedProfit = totalOfficeShare - totalExpensesAmount;
    final netCollectedProfit = collectedOfficeShare - totalExpensesAmount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12.0 : 24.0,
                vertical: isMobile ? 14.0 : 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  if (isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "نظام الحسابات والماليات",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: TfcColors.primary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMonth,
                                  dropdownColor: TfcColors.surfaceDim,
                                  style: const TextStyle(fontSize: 12, color: Colors.white),
                                  items: List.generate(12, (index) {
                                    final date = DateTime(DateTime.now().year, index + 1);
                                    final val = "${date.year}-${date.month.toString().padLeft(2, '0')}";
                                    return DropdownMenuItem(
                                      value: val,
                                      child: Text(val),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedMonth = val;
                                      });
                                      _loadData();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text("تتبع إيرادات المكتب وعمولات الموظفين والمصروفات", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "نظام الحسابات والماليات",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TfcColors.primary),
                            ),
                            SizedBox(height: 4),
                            Text("تتبع إيرادات المكتب وعمولات الموظفين والمصروفات الشهرية", style: TextStyle(color: TfcColors.outline)),
                          ],
                        ),
                        // Month Picker
                        Row(
                          children: [
                            const Text("عرض لشهر: ", style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedMonth,
                                  dropdownColor: TfcColors.surfaceDim,
                                  items: List.generate(12, (index) {
                                    final date = DateTime(DateTime.now().year, index + 1);
                                    final val = "${date.year}-${date.month.toString().padLeft(2, '0')}";
                                    return DropdownMenuItem(
                                      value: val,
                                      child: Text(val),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedMonth = val;
                                      });
                                      _loadData();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),

              // TabBar Selector
              TabBar(
                controller: _tabController,
                indicatorColor: TfcColors.primary,
                labelColor: TfcColors.primary,
                unselectedLabelColor: TfcColors.outline,
                tabs: const [
                  Tab(icon: Icon(Icons.show_chart), text: "الإيرادات والعمولات"),
                  Tab(icon: Icon(Icons.money_off), text: "المصروفات الشهرية"),
                ],
              ),
              const SizedBox(height: 20),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Revenues Tab View
                    _buildRevenuesTab(
                      totalFeesDue,
                      collectedFees,
                      uncollectedFees,
                      totalEmpCommission,
                      totalMgrCommission,
                      totalOfficeShare,
                      totalExpensesAmount,
                      netCollectedProfit,
                      netAccruedProfit,
                      filteredOps,
                      employees,
                      ref.watch(authProvider).role ?? '',
                    ),

                    // Expenses Tab View
                    _buildExpensesTab(
                      filteredExpenses,
                      totalExpensesAmount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
  }

  Widget _buildRevenuesTab(
    double totalFeesDue,
    double collectedFees,
    double uncollectedFees,
    double totalEmpComm,
    double totalMgrComm,
    double totalOfficeShare,
    double totalExpenses,
    double netCollectedProfit,
    double netAccruedProfit,
    List<OperationEntry> ops,
    List<Profile> employees,
    String userRole,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row of Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth < 800 ? 2 : 4;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.8,
                children: [
                  _buildStatCard("إجمالي الأتعاب المستحقة", "${_fmt(totalFeesDue)} ج.م",
                      subtext: "المحصل: ${_fmt(collectedFees)} | المتبقي: ${_fmt(uncollectedFees)}",
                      icon: Icons.payments, color: TfcColors.primary),
                  _buildStatCard("عمولة الموظفين (10%)", "${_fmt(totalEmpComm)} ج.م",
                      subtext: "توزع للمسؤولين عن العمليات",
                      icon: Icons.people, color: Colors.orangeAccent),
                  _buildStatCard("عمولة المدراء (5%)", "${_fmt(totalMgrComm)} ج.م",
                      subtext: "توزع للمدراء المباشرين (غير الأدمن)",
                      icon: Icons.manage_accounts, color: Colors.purpleAccent),
                  _buildStatCard("أتعاب المكتب المستحقة", "${_fmt(totalOfficeShare)} ج.م",
                      subtext: "المحصلة فعلياً: ${_fmt(totalOfficeShare * (totalFeesDue > 0 ? collectedFees / totalFeesDue : 0))} ج.م",
                      icon: Icons.business, color: TfcColors.success),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Total Profit Card (Calculated with Expenses)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TfcColors.primary.withValues(alpha: 0.1),
                  Colors.green.withValues(alpha: 0.05),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TfcColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.monetization_on, color: TfcColors.primary, size: 24),
                        SizedBox(width: 8),
                        Text("صافي الأرباح لشهر التقرير", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.primary)),
                      ],
                    ),
                    Text("المصروفات المخصومة: ${_fmt(totalExpenses)} ج.م", style: const TextStyle(color: TfcColors.error, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("صافي الأرباح المحصلة فعلياً (حصة المكتب المحصلة - المصروفات)", style: TextStyle(color: TfcColors.outline, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            "${_fmt(netCollectedProfit)} ج.م",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: netCollectedProfit >= 0 ? TfcColors.success : TfcColors.error),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("صافي الأرباح الكلية المتوقعة (حصة المكتب الكلية - المصروفات)", style: TextStyle(color: TfcColors.outline, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            "${_fmt(netAccruedProfit)}  ج.م",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: netAccruedProfit >= 0 ? TfcColors.primary : TfcColors.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Operations List
          const Text("تفاصيل عمولات العمليات بالفواتير", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          if (ops.isEmpty)
            const Card(
              color: Colors.white10,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text("لا توجد فواتير موافقة مسجلة لشهر التقرير", style: TextStyle(color: TfcColors.outline))),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ops.length,
              itemBuilder: (c, idx) {
                final op = ops[idx];
                final fees = op.invoiceFees ?? 0.0;
                final isCollected = op.invoiceCollected == 'collected';

                // Find representatives details
                final client = ref.read(clientProvider).clients.firstWhereOrNull((cl) => cl.id == op.clientId);
                final repName = (client?.representativeName ?? '').toLowerCase().trim();
                final emp = employees.firstWhereOrNull((e) => e.fullName.toLowerCase().trim() == repName);

                double empComm = fees * 0.10;
                double mgrComm = 0.0;
                String managerName = "لا يوجد";

                if (emp != null && emp.managerId != null) {
                  final manager = employees.firstWhereOrNull((e) => e.id == emp.managerId);
                  if (manager != null) {
                    managerName = manager.fullName;
                    if (manager.role != 'admin') {
                      mgrComm = fees * 0.05;
                    } else {
                      managerName += " (أدمن - لا عمولة)";
                    }
                  }
                }

                final officeShare = fees - (empComm + mgrComm);

                return Card(
                  color: Colors.white.withValues(alpha: 0.02),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(client?.fullName ?? "عميل غير معروف", style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text("البرنامج: ${op.programName} | البنك: ${op.bankName}", style: const TextStyle(color: TfcColors.outline, fontSize: 11)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCollected ? TfcColors.success.withValues(alpha: 0.15) : TfcColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isCollected ? "تم التحصيل" : "لم يتم التحصيل",
                                style: TextStyle(color: isCollected ? TfcColors.success : TfcColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20, color: Colors.white10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (userRole == 'admin') ...[
                              _buildMiniDetail("قيمة الأتعاب", "${_fmt(fees)} ج.م"),
                            ],
                            _buildMiniDetail("الموظف (10%)", "${_fmt(empComm)} ج.م\n($repName)"),
                            _buildMiniDetail("المدير (5%)", "${_fmt(mgrComm)} ج.م\n($managerName)"),
                            if (userRole == 'admin') ...[
                              _buildMiniDetail("حصة المكتب", "${_fmt(officeShare)} ج.م", highlight: true),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(List<ExpenseModel> expenses, double totalExpenses) {
    final isAdminOrManager = ref.read(authProvider).role == 'admin' || ref.read(authProvider).role == 'manager';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("إجمالي مصروفات الشهر: ${_fmt(totalExpenses)} ج.م", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TfcColors.error)),
            if (isAdminOrManager)
              ElevatedButton.icon(
                onPressed: _showAddExpenseDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text("إضافة مصروف"),
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary, foregroundColor: Colors.black),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: expenses.isEmpty
              ? const Center(child: Text("لا توجد مصروفات مسجلة لشهر التقرير", style: TextStyle(color: TfcColors.outline)))
              : ListView.builder(
                  itemCount: expenses.length,
                  itemBuilder: (c, idx) {
                    final exp = expenses[idx];
                    return Card(
                      color: Colors.white.withValues(alpha: 0.02),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("التاريخ: ${exp.expenseDate.year}-${exp.expenseDate.month.toString().padLeft(2, '0')}-${exp.expenseDate.day.toString().padLeft(2, '0')}", style: const TextStyle(color: TfcColors.outline, fontSize: 11)),
                            if (exp.notes != null && exp.notes!.isNotEmpty)
                              Text("ملاحظات: ${exp.notes}", style: const TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${_fmt(exp.amount)} ج.م",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.error),
                            ),
                            if (isAdminOrManager) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, color: TfcColors.primary, size: 18),
                                onPressed: () => _showEditExpenseDialog(exp),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: TfcColors.error, size: 18),
                                onPressed: () => _showDeleteExpenseConfirm(exp),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, {required String subtext, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 4),
          Text(subtext, style: const TextStyle(color: Colors.white30, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMiniDetail(String title, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: TfcColors.outline, fontSize: 10)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: highlight ? TfcColors.primary : Colors.white70,
          ),
        ),
      ],
    );
  }
}
