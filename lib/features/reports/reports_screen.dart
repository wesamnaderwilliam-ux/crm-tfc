import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:collection/collection.dart';
import 'package:printing/printing.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import '../../providers/banks_provider.dart';
import '../client/operations_widget.dart';
import '../accounts/accounts_screen.dart';
import '../../core/utils/reports_pdf_generator.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;
  const ReportsScreen({super.key, required this.onViewClient});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

enum ReportPeriodType {
  monthly, // شهري
  quarterly, // ربع سنوي
  semiAnnual, // نصف سنوي
  annual, // سنوي
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Filter States
  ReportPeriodType _periodType = ReportPeriodType.monthly;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month; // 1-12
  int _selectedQuarter = ((DateTime.now().month - 1) ~/ 3) + 1; // 1-4
  int _selectedHalf = DateTime.now().month <= 6 ? 1 : 2; // 1-2

  // Raw Loaded Data
  List<OperationEntry> _allOperations = [];
  List<ExpenseModel> _allExpenses = [];
  List<Map<String, dynamic>> _allTargets = [];
  List<Map<String, dynamic>> _allDistributions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (!SupabaseConfig.isInitialized) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch all operations
      final opsResponse = await SupabaseConfig.client
          .from('operation_entries')
          .select('*');

      // 2. Fetch all expenses
      final expResponse = await SupabaseConfig.client
          .from('expenses')
          .select('*');

      // 3. Fetch all targets
      final targetsResponse = await SupabaseConfig.client
          .from('employee_targets')
          .select('*');

      // 4. Fetch all distributions with relations
      final distResponse = await SupabaseConfig.client
          .from('distribution_entries')
          .select('''
            id,
            program_id,
            bank_id,
            employee_id,
            status,
            client_id,
            created_at,
            core_programs ( program_name ),
            banks ( bank_name ),
            bank_employees ( employee_name, phone_1 ),
            clients ( full_name, representative_name, created_by, created_at )
          ''');

      final List<dynamic> opsRows = opsResponse as List<dynamic>;
      final List<dynamic> expRows = expResponse as List<dynamic>;
      final List<dynamic> targetRows = targetsResponse as List<dynamic>;
      final List<dynamic> distRows = distResponse as List<dynamic>;

      final List<Map<String, dynamic>> parsedDist = distRows.map((r) {
        final clientData = r['clients'] as Map<String, dynamic>?;
        final bankData = r['banks'] as Map<String, dynamic>?;
        final programData = r['core_programs'] as Map<String, dynamic>?;
        final empData = r['bank_employees'] as Map<String, dynamic>?;

        DateTime? createdAt;
        if (r['created_at'] != null) {
          try {
            createdAt = DateTime.parse(r['created_at'].toString());
          } catch (_) {}
        } else if (clientData != null && clientData['created_at'] != null) {
          try {
            createdAt = DateTime.parse(clientData['created_at'].toString());
          } catch (_) {}
        }

        return {
          'id': r['id'],
          'client_id': r['client_id'],
          'client_name': clientData != null ? clientData['full_name'] : 'عميل',
          'program_name': programData != null ? programData['program_name'] : 'برنامج غير محدد',
          'program_id': r['program_id'],
          'bank_name': bankData != null ? bankData['bank_name'] : 'بنك غير محدد',
          'bank_id': r['bank_id'],
          'employee_id': r['employee_id'],
          'employee_name': empData != null ? '${empData['employee_name']}'.trim() : 'لم يحدد بعد',
          'status': r['status'] ?? 'pending',
          'created_at': createdAt,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allOperations = opsRows.map((r) => OperationEntry.fromJson(r)).toList();
          _allExpenses = expRows.map((r) => ExpenseModel.fromJson(r)).toList();
          _allTargets = targetRows.map((r) => Map<String, dynamic>.from(r)).toList();
          _allDistributions = parsedDist;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading reports data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Check if a date falls inside the selected period
  bool _isDateInSelectedPeriod(DateTime? date) {
    if (date == null) return false;
    if (date.year != _selectedYear) return false;

    switch (_periodType) {
      case ReportPeriodType.monthly:
        return date.month == _selectedMonth;
      case ReportPeriodType.quarterly:
        final q = ((date.month - 1) ~/ 3) + 1;
        return q == _selectedQuarter;
      case ReportPeriodType.semiAnnual:
        final h = date.month <= 6 ? 1 : 2;
        return h == _selectedHalf;
      case ReportPeriodType.annual:
        return true;
    }
  }

  String _getPeriodLabel() {
    switch (_periodType) {
      case ReportPeriodType.monthly:
        final months = [
          'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
          'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
        ];
        return "شهر ${months[_selectedMonth - 1]} $_selectedYear";
      case ReportPeriodType.quarterly:
        final quarters = ['الربع الأول (Q1)', 'الربع الثاني (Q2)', 'الربع الثالث (Q3)', 'الربع الرابع (Q4)'];
        return "${quarters[_selectedQuarter - 1]} لعام $_selectedYear";
      case ReportPeriodType.semiAnnual:
        final halves = ['النصف الأول (H1)', 'النصف الثاني (H2)'];
        return "${halves[_selectedHalf - 1]} لعام $_selectedYear";
      case ReportPeriodType.annual:
        return "عام $_selectedYear كامل";
    }
  }

  String _formatNumber(double amount) {
    return intl.NumberFormat('#,##0.##').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: TfcColors.primary));
    }

    final authState = ref.watch(authProvider);
    final isCurrentUserAdmin = authState.role == 'admin' ||
        authState.role == 'manager' ||
        authState.user?.email == 'wezonader@gmail.com' ||
        (authState.user?.email?.toLowerCase().contains('wezonader') ?? false);

    if (!isCurrentUserAdmin) {
      return const Center(
        child: Text(
          "عذراً، هذا القسم مخصص للإدارة العليا والأدمن فقط.",
          style: TextStyle(color: TfcColors.error, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    final clientState = ref.watch(clientProvider);
    final empState = ref.watch(employeesProvider);
    final banksAsync = ref.watch(allBanksProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Period Selector Bar
            _buildTopBar(),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: TfcColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: TfcColors.primary,
              unselectedLabelColor: TfcColors.outline,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 20), text: "التقارير المحاسبية والمالية"),
                Tab(icon: Icon(Icons.badge_outlined, size: 20), text: "تقارير الموظفين والتارجت"),
                Tab(icon: Icon(Icons.account_balance_outlined, size: 20), text: "تقارير أداء البنوك"),
                Tab(icon: Icon(Icons.category_outlined, size: 20), text: "تقارير البرامج التمويلية"),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  Builder(builder: (context) {
                    try {
                      return _buildFinancialReportsTab(clientState.clients);
                    } catch (e) {
                      return Center(child: Text("خطأ في عرض التقرير المالي: $e", style: const TextStyle(color: Colors.redAccent)));
                    }
                  }),
                  Builder(builder: (context) {
                    try {
                      return _buildEmployeesReportsTab(empState.employees, clientState.clients);
                    } catch (e) {
                      return Center(child: Text("خطأ في عرض تقرير الموظفين: $e", style: const TextStyle(color: Colors.redAccent)));
                    }
                  }),
                  Builder(builder: (context) {
                    try {
                      return _buildBanksReportsTab(banksAsync.value ?? []);
                    } catch (e) {
                      return Center(child: Text("خطأ في عرض تقرير البنوك: $e", style: const TextStyle(color: Colors.redAccent)));
                    }
                  }),
                  Builder(builder: (context) {
                    try {
                      return _buildProgramsReportsTab(banksAsync.value ?? []);
                    } catch (e) {
                      return Center(child: Text("خطأ في عرض تقرير البرامج: $e", style: const TextStyle(color: Colors.redAccent)));
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Top Filter & Period Selection Bar
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderColor: TfcColors.primary.withValues(alpha: 0.2),
      child: Wrap(
        textDirection: TextDirection.rtl,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_rounded, color: TfcColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "مركز التقارير الشاملة والذكاء المالي 📈",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  Text(
                    _getPeriodLabel(),
                    style: const TextStyle(fontSize: 12, color: TfcColors.primary),
                  ),
                ],
              ),
            ],
          ),

          // Period Filters
          Wrap(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              // Period Type Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButton<ReportPeriodType>(
                  value: _periodType,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF1E1E38),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: ReportPeriodType.monthly, child: Text("تقرير شهري")),
                    DropdownMenuItem(value: ReportPeriodType.quarterly, child: Text("تقرير ربع سنوي")),
                    DropdownMenuItem(value: ReportPeriodType.semiAnnual, child: Text("تقرير نصف سنوي")),
                    DropdownMenuItem(value: ReportPeriodType.annual, child: Text("تقرير سنوي")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _periodType = val);
                  },
                ),
              ),

              // Year Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: DropdownButton<int>(
                  value: _selectedYear,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF1E1E38),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                      .map((y) => DropdownMenuItem(value: y, child: Text("$y")))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedYear = val);
                  },
                ),
              ),

              // Specific Month Selector (If Monthly)
              if (_periodType == ReportPeriodType.monthly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedMonth,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1E1E38),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("يناير (1)")),
                      DropdownMenuItem(value: 2, child: Text("فبراير (2)")),
                      DropdownMenuItem(value: 3, child: Text("مارس (3)")),
                      DropdownMenuItem(value: 4, child: Text("أبريل (4)")),
                      DropdownMenuItem(value: 5, child: Text("مايو (5)")),
                      DropdownMenuItem(value: 6, child: Text("يونيو (6)")),
                      DropdownMenuItem(value: 7, child: Text("يوليو (7)")),
                      DropdownMenuItem(value: 8, child: Text("أغسطس (8)")),
                      DropdownMenuItem(value: 9, child: Text("سبتمبر (9)")),
                      DropdownMenuItem(value: 10, child: Text("أكتوبر (10)")),
                      DropdownMenuItem(value: 11, child: Text("نوفمبر (11)")),
                      DropdownMenuItem(value: 12, child: Text("ديسمبر (12)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),

              // Specific Quarter Selector (If Quarterly)
              if (_periodType == ReportPeriodType.quarterly)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedQuarter,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1E1E38),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("الربع الأول (يناير - مارس)")),
                      DropdownMenuItem(value: 2, child: Text("الربع الثاني (أبريل - يونيو)")),
                      DropdownMenuItem(value: 3, child: Text("الربع الثالث (يوليو - سبتمبر)")),
                      DropdownMenuItem(value: 4, child: Text("الربع الرابع (أكتوبر - ديسمبر)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedQuarter = val);
                    },
                  ),
                ),

              // Specific Half Selector (If Semi-Annual)
              if (_periodType == ReportPeriodType.semiAnnual)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedHalf,
                    underline: const SizedBox(),
                    dropdownColor: const Color(0xFF1E1E38),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text("النصف الأول (يناير - يونيو)")),
                      DropdownMenuItem(value: 2, child: Text("النصف الثاني (يوليو - ديسمبر)")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedHalf = val);
                    },
                  ),
                ),

              // Refresh Button
              IconButton(
                icon: const Icon(Icons.refresh, color: TfcColors.primary),
                onPressed: _loadAllData,
                tooltip: "تحديث البيانات",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. تبويب التقارير المحاسبية والمالية
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildFinancialReportsTab(List clients) {
    // Filter operations by period
    final periodOps = _allOperations.where((op) {
      final d = op.approvalDate ?? op.transferDate;
      return _isDateInSelectedPeriod(d);
    }).toList();

    // Invoices Ops
    final invoiceOps = periodOps.where((op) => op.hasInvoice).toList();

    // Total fees
    double totalInvoicesFees = 0.0;
    double collectedFees = 0.0;
    double uncollectedFees = 0.0;

    for (var op in invoiceOps) {
      final fees = op.invoiceFees ?? 0.0;
      totalInvoicesFees += fees;
      if (op.invoiceCollected == 'collected') {
        collectedFees += fees;
      } else {
        uncollectedFees += fees;
      }
    }

    // Filter Expenses
    final periodExpenses = _allExpenses.where((exp) {
      return _isDateInSelectedPeriod(exp.expenseDate);
    }).toList();

    double totalExpenses = periodExpenses.fold(0.0, (sum, exp) => sum + exp.amount);
    double netProfit = totalInvoicesFees - totalExpenses;

    // Prepared list for PDF & UI
    final List<Map<String, dynamic>> opsTableData = invoiceOps.map((op) {
      final client = clients.firstWhereOrNull((c) => c.id == op.clientId);
      return {
        'client': client?.fullName ?? 'عميل #${op.clientId.substring(0, 5)}',
        'bank': op.bankName,
        'approved_amount': op.approvedAmount ?? op.requestedAmount,
        'percentage': op.invoicePercentage ?? 0.0,
        'fees': op.invoiceFees ?? 0.0,
        'collected': op.invoiceCollected ?? 'not_collected',
        'status': op.status,
      };
    }).toList();

    final List<Map<String, dynamic>> expTableData = periodExpenses.map((exp) {
      return {
        'title': exp.title,
        'amount': exp.amount,
        'date': "${exp.expenseDate.day}/${exp.expenseDate.month}/${exp.expenseDate.year}",
        'notes': exp.notes ?? '—',
      };
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action & Export Bar
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ملخص الأرباح والمصروفات (${_getPeriodLabel()})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final pdfBytes = await ReportsPdfGenerator.generateFinancialReportPdf(
                    periodLabel: _getPeriodLabel(),
                    totalInvoicesFees: totalInvoicesFees,
                    collectedFees: collectedFees,
                    uncollectedFees: uncollectedFees,
                    totalExpenses: totalExpenses,
                    netProfit: netProfit,
                    operationsCount: invoiceOps.length,
                    operationsList: opsTableData,
                    expensesList: expTableData,
                  );
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'TFC_Financial_Report_${_selectedYear}.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text("طباعة وتصدير التقرير المالي (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // KPI Cards
          Row(
            children: [
              Expanded(child: _buildMetricCard("إجمالي الإيرادات والأتعاب", "${_formatNumber(totalInvoicesFees)} ج.م", Icons.savings, Colors.blueAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard("المحصل الفعلي", "${_formatNumber(collectedFees)} ج.م", Icons.check_circle, Colors.greenAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard("المستحق غير المحصل", "${_formatNumber(uncollectedFees)} ج.م", Icons.pending_actions, Colors.orangeAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard("إجمالي المصروفات", "${_formatNumber(totalExpenses)} ج.م", Icons.money_off, Colors.redAccent)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard("صافي الأرباح", "${_formatNumber(netProfit)} ج.م", Icons.account_balance, netProfit >= 0 ? Colors.greenAccent : Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 20),

          // Invoices Table
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("💳 فواتير العمليات المنفذة في ${_getPeriodLabel()} (${invoiceOps.length})",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TfcColors.primary)),
                  ],
                ),
                const SizedBox(height: 12),
                opsTableData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text("لا توجد فواتير مسجلة في هذه الفترة", style: TextStyle(color: TfcColors.outline))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("العميل", style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("البنك", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("المبلغ المعتمد", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("نسبة الأتعاب", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("قيمة الأتعاب", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("حالة التحصيل", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: opsTableData.map((d) {
                            final isColl = d['collected'] == 'collected';
                            return DataRow(
                              cells: [
                                DataCell(Text(d['client'])),
                                DataCell(Text(d['bank'])),
                                DataCell(Text("${_formatNumber(d['approved_amount'])} ج.م")),
                                DataCell(Text("${d['percentage']}%")),
                                DataCell(Text("${_formatNumber(d['fees'])} ج.م", style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isColl ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isColl ? "تم التحصيل" : "مستحق",
                                      style: TextStyle(color: isColl ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Expenses Table
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("💸 المصروفات المسجلة في ${_getPeriodLabel()} (${periodExpenses.length})",
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                  ],
                ),
                const SizedBox(height: 12),
                expTableData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text("لا توجد مصروفات مسجلة في هذه الفترة", style: TextStyle(color: TfcColors.outline))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("بند المصروف", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("القيمة", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("التاريخ", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("ملاحظات", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: expTableData.map((d) {
                            return DataRow(
                              cells: [
                                DataCell(Text(d['title'], style: const TextStyle(color: Colors.white))),
                                DataCell(Text("${_formatNumber(d['amount'])} ج.م", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                                DataCell(Text(d['date'])),
                                DataCell(Text(d['notes'])),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. تبويب تقارير الموظفين والتارجت ومقارنة الفرق
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildEmployeesReportsTab(List employees, List clients) {
    // 1. Calculate per-employee statistics in the selected period
    final List<Map<String, dynamic>> employeeStats = [];

    for (var emp in employees) {
      if (emp.role == 'bank_employee') continue;

      final empFullName = (emp.fullName as String? ?? '').trim().toLowerCase();
      final empEmail = (emp.email as String? ?? '').trim().toLowerCase();
      final empId = emp.id.toString();

      // Count clients assigned to this employee
      final empClients = clients.where((c) {
        final rep = (c.representativeName ?? '').trim().toLowerCase();
        final creator = (c.createdBy ?? '').trim().toLowerCase();
        return (rep.isNotEmpty && (rep == empFullName || rep == empEmail || rep == empId)) ||
               (creator.isNotEmpty && (creator == empFullName || creator == empEmail || creator == empId));
      }).toList();

      // Approved operations for this employee
      final empApprovedOps = _allOperations.where((op) {
        final d = op.approvalDate ?? op.transferDate;
        final opEmp = op.employeeName.trim().toLowerCase();
        final isMatch = opEmp == empFullName || (empFullName.isNotEmpty && opEmp.contains(empFullName));
        return isMatch && op.status == 'approved' && _isDateInSelectedPeriod(d);
      }).toList();

      final double achievedAmount = empApprovedOps.fold(0.0, (sum, op) => sum + (op.approvedAmount ?? op.requestedAmount));

      // Calculate Target for this period
      double targetAmount = 0.0;
      for (var t in _allTargets) {
        if (t['employee_id'] == emp.id) {
          final tMonthStr = t['target_month'] as String? ?? '';
          if (tMonthStr.isNotEmpty) {
            try {
              final tDate = DateTime.parse("$tMonthStr-01");
              if (_isDateInSelectedPeriod(tDate)) {
                targetAmount += (t['target_amount'] as num?)?.toDouble() ?? 0.0;
              }
            } catch (_) {}
          }
        }
      }

      final rate = targetAmount > 0 ? (achievedAmount / targetAmount) * 100 : (achievedAmount > 0 ? 100.0 : 0.0);

      employeeStats.add({
        'id': emp.id,
        'name': emp.fullName,
        'role_or_team': emp.role == 'manager' ? 'مدير فريق / مشرف' : 'مسؤول مبيعات',
        'clients_count': empClients.length,
        'operations_count': empApprovedOps.length,
        'target_amount': targetAmount,
        'achieved_amount': achievedAmount,
        'achievement_rate': rate,
      });
    }

    // Sort by achieved amount descending
    employeeStats.sort((a, b) => (b['achieved_amount'] as double).compareTo(a['achieved_amount'] as double));

    // 2. Team rollup statistics
    final List<Map<String, dynamic>> teamStats = [];
    final managers = employees.where((e) => e.role == 'manager' || e.role == 'admin').toList();

    for (var mgr in managers) {
      final teamMembers = employees.where((e) => e.managerId == mgr.id).toList();
      if (teamMembers.isNotEmpty) {
        double teamTarget = 0.0;
        double teamAchieved = 0.0;

        for (var member in [mgr, ...teamMembers]) {
          final stat = employeeStats.firstWhereOrNull((s) => s['id'] == member.id);
          if (stat != null) {
            teamTarget += stat['target_amount'] as double;
            teamAchieved += stat['achieved_amount'] as double;
          }
        }

        final teamRate = teamTarget > 0 ? (teamAchieved / teamTarget) * 100 : (teamAchieved > 0 ? 100.0 : 0.0);

        teamStats.add({
          'team_name': "فريق ${mgr.fullName}",
          'leader_name': mgr.fullName,
          'members_count': teamMembers.length + 1,
          'total_target': teamTarget,
          'total_achieved': teamAchieved,
          'achievement_rate': teamRate,
        });
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action & Export Bar
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "أداء الموظفين وتحقيق التارجت (${_getPeriodLabel()})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final pdfBytes = await ReportsPdfGenerator.generateEmployeesReportPdf(
                    periodLabel: _getPeriodLabel(),
                    employeeStats: employeeStats,
                    teamStats: teamStats,
                  );
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'TFC_Employees_Report_${_selectedYear}.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text("طباعة وتصدير تقرير الموظفين (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CE7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Team Comparison if available
          if (teamStats.isNotEmpty) ...[
            GlassCard(
              padding: const EdgeInsets.all(20),
              borderColor: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text("🏆 مقارنة أداء فرق العمل والمجموعات", 
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00CEC9))),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("الفريق", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        DataColumn(label: Text("قائد الفريق", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("عدد الأعضاء", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("التارجت الكلي", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("المحقق الكلي", style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text("نسبة الإنجاز", style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: teamStats.map((t) {
                        final rate = t['achievement_rate'] as double;
                        return DataRow(
                          cells: [
                            DataCell(Text(t['team_name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00CEC9)))),
                            DataCell(Text(t['leader_name'])),
                            DataCell(Text("${t['members_count']}")),
                            DataCell(Text("${_formatNumber(t['total_target'])} ج.م")),
                            DataCell(Text("${_formatNumber(t['total_achieved'])} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: rate >= 100 ? Colors.green.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text("${rate.toStringAsFixed(1)}%", style: TextStyle(color: rate >= 100 ? Colors.greenAccent : Colors.purpleAccent, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Individual Employee Performance Table
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("👤 تقييم وتصنيف أداء الموظفين الفردي (${employeeStats.length} موظف)",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TfcColors.primary)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("اسم الموظف", style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("المسمى / الفريق", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("العملاء", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("العمليات الناجحة", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("التارجت المستهدف", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("المبيعات المنفذة", style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text("نسبة الإنجاز", style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: employeeStats.map((e) {
                      final rate = e['achievement_rate'] as double;
                      return DataRow(
                        cells: [
                          DataCell(Text(e['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(e['role_or_team'])),
                          DataCell(Text("${e['clients_count']}")),
                          DataCell(Text("${e['operations_count']}")),
                          DataCell(Text("${_formatNumber(e['target_amount'])} ج.م")),
                          DataCell(Text("${_formatNumber(e['achieved_amount'])} ج.م", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: rate >= 100 ? Colors.green.withValues(alpha: 0.2) : (rate >= 50 ? Colors.orange.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text("${rate.toStringAsFixed(1)}%",
                                  style: TextStyle(
                                    color: rate >= 100 ? Colors.greenAccent : (rate >= 50 ? Colors.orangeAccent : Colors.redAccent),
                                    fontWeight: FontWeight.bold,
                                  )),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. تبويب تقارير أداء البنوك ونسب القبول ومسؤولي التنسيق (شامل التوزيع والعمليات)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildBanksReportsTab(List banks) {
    // Filter operations in period
    final periodOps = _allOperations.where((op) {
      final d = op.approvalDate ?? op.transferDate;
      return _isDateInSelectedPeriod(d);
    }).toList();

    // Filter distributions in period
    final periodDists = _allDistributions.where((d) {
      final dt = d['created_at'] as DateTime?;
      return dt != null ? _isDateInSelectedPeriod(dt) : true;
    }).toList();

    // Collect all unique bank names from banks, operations, and distributions
    final Set<String> allBankNames = {};
    for (var b in banks) {
      final name = (b['bank_name'] ?? '').toString().trim();
      if (name.isNotEmpty) allBankNames.add(name);
    }
    for (var op in periodOps) {
      if (op.bankName.trim().isNotEmpty) allBankNames.add(op.bankName.trim());
    }
    for (var dist in periodDists) {
      final name = (dist['bank_name'] ?? '').toString().trim();
      if (name.isNotEmpty && name != 'بنك غير محدد') allBankNames.add(name);
    }

    final List<Map<String, dynamic>> bankStats = [];

    for (var bName in allBankNames) {
      final bankOps = periodOps.where((o) => o.bankName.trim().toLowerCase() == bName.toLowerCase()).toList();
      final bankDists = periodDists.where((d) => (d['bank_name'] ?? '').toString().trim().toLowerCase() == bName.toLowerCase()).toList();

      final totalOpsCount = bankOps.length;
      final approvedOps = bankOps.where((o) => o.status == 'approved').toList();
      final rejectedOps = bankOps.where((o) => o.status == 'rejected').toList();
      final approvedOpsCount = approvedOps.length;
      final rejectedOpsCount = rejectedOps.length;

      final totalDistsCount = bankDists.length;
      final acceptedDists = bankDists.where((d) => d['status'] == 'accepted').toList();
      final rejectedDists = bankDists.where((d) => d['status'] == 'rejected').toList();
      final acceptedDistsCount = acceptedDists.length;
      final rejectedDistsCount = rejectedDists.length;

      // Acceptance / Approval Rates
      final double opsApprovalRate = totalOpsCount > 0 ? (approvedOpsCount / totalOpsCount) * 100 : 0.0;
      final double distAcceptanceRate = totalDistsCount > 0 ? (acceptedDistsCount / totalDistsCount) * 100 : 0.0;
      final double totalApprovedAmount = approvedOps.fold(0.0, (sum, o) => sum + (o.approvedAmount ?? o.requestedAmount));

      // Most used program for this bank
      final Map<String, int> progCount = {};
      for (var o in bankOps) {
        if (o.programName.isNotEmpty) progCount[o.programName] = (progCount[o.programName] ?? 0) + 1;
      }
      for (var d in bankDists) {
        final pName = (d['program_name'] ?? '').toString();
        if (pName.isNotEmpty && pName != 'برنامج غير محدد') progCount[pName] = (progCount[pName] ?? 0) + 1;
      }
      final sortedProgs = progCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topProgs = sortedProgs.take(2).map((e) => "${e.key} (${e.value})").join("، ");

      // Most active bank employee
      final Map<String, int> empCount = {};
      for (var o in bankOps) {
        if (o.employeeName.isNotEmpty && o.employeeName != 'لم يحدد') {
          empCount[o.employeeName] = (empCount[o.employeeName] ?? 0) + 1;
        }
      }
      for (var d in bankDists) {
        final eName = (d['employee_name'] ?? '').toString();
        if (eName.isNotEmpty && eName != 'لم يحدد بعد') {
          empCount[eName] = (empCount[eName] ?? 0) + 1;
        }
      }
      final sortedEmps = empCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final topBankEmp = sortedEmps.isNotEmpty ? "${sortedEmps.first.key} (${sortedEmps.first.value} تعامل)" : "—";

      if (totalOpsCount > 0 || totalDistsCount > 0) {
        bankStats.add({
          'bank_name': bName,
          'total_dists_count': totalDistsCount,
          'accepted_dists_count': acceptedDistsCount,
          'rejected_dists_count': rejectedDistsCount,
          'dist_acceptance_rate': distAcceptanceRate,
          'total_ops_count': totalOpsCount,
          'approved_ops_count': approvedOpsCount,
          'rejected_ops_count': rejectedOpsCount,
          'ops_approval_rate': opsApprovalRate,
          'total_approved_amount': totalApprovedAmount,
          'top_programs': topProgs.isNotEmpty ? topProgs : '—',
          'top_bank_employee': topBankEmp,
        });
      }
    }

    bankStats.sort((a, b) => ((b['total_ops_count'] as int) + (b['total_dists_count'] as int))
        .compareTo((a['total_ops_count'] as int) + (a['total_dists_count'] as int)));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action & Export Bar
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "أداء البنوك الشامل (توزيعات + عمليات) (${_getPeriodLabel()})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final pdfBytes = await ReportsPdfGenerator.generateBanksReportPdf(
                    periodLabel: _getPeriodLabel(),
                    bankStats: bankStats,
                  );
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'TFC_Banks_Performance_Report_${_selectedYear}.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text("طباعة وتصدير تقرير البنوك (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("🏦 تفاصيل أداء البنوك الشامل (${bankStats.length} بنك)",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TfcColors.primary)),
                const SizedBox(height: 12),
                bankStats.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text("لا توجد توزيعات أو عمليات مسجلة بالبنوك في هذه الفترة", style: TextStyle(color: TfcColors.outline))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("اسم البنك", style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("عملاء التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("قبول التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("نسبة قبول التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("عملاء العمليات", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("موافقة العمليات", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("نسبة قبول العمليات", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("إجمالي التمويل المعتمد", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("أكثر برنامج تنفيذاً", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("أكثر مسؤول تم التعامل معه", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: bankStats.map((b) {
                            final distRate = b['dist_acceptance_rate'] as double;
                            final opsRate = b['ops_approval_rate'] as double;
                            return DataRow(
                              cells: [
                                DataCell(Text(b['bank_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text("${b['total_dists_count']}")),
                                DataCell(Text("${b['accepted_dists_count']}", style: const TextStyle(color: Colors.greenAccent))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: distRate >= 50 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("${distRate.toStringAsFixed(1)}%",
                                        style: TextStyle(color: distRate >= 50 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text("${b['total_ops_count']}")),
                                DataCell(Text("${b['approved_ops_count']}", style: const TextStyle(color: Colors.greenAccent))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: opsRate >= 60 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("${opsRate.toStringAsFixed(1)}%",
                                        style: TextStyle(color: opsRate >= 60 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text("${_formatNumber(b['total_approved_amount'])} ج.م", style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(b['top_programs'])),
                                DataCell(Text(b['top_bank_employee'], style: const TextStyle(color: Color(0xFF00CEC9)))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. تبويب تقارير البرامج التمويلية ونسب الاستخدام حسب البنك (شامل التوزيع والعمليات)
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildProgramsReportsTab(List banks) {
    final periodOps = _allOperations.where((op) {
      final d = op.approvalDate ?? op.transferDate;
      return _isDateInSelectedPeriod(d);
    }).toList();

    final periodDists = _allDistributions.where((d) {
      final dt = d['created_at'] as DateTime?;
      return dt != null ? _isDateInSelectedPeriod(dt) : true;
    }).toList();

    final totalPeriodOpsCount = periodOps.length;
    final totalPeriodDistsCount = periodDists.length;

    // Collect all unique program names
    final Set<String> allProgNames = {};
    for (var op in periodOps) {
      final pName = op.programName.trim();
      if (pName.isNotEmpty) allProgNames.add(pName);
    }
    for (var dist in periodDists) {
      final pName = (dist['program_name'] ?? '').toString().trim();
      if (pName.isNotEmpty && pName != 'برنامج غير محدد') allProgNames.add(pName);
    }

    final List<Map<String, dynamic>> programStats = [];

    for (var pName in allProgNames) {
      final progOps = periodOps.where((o) => o.programName.trim().toLowerCase() == pName.toLowerCase()).toList();
      final progDists = periodDists.where((d) => (d['program_name'] ?? '').toString().trim().toLowerCase() == pName.toLowerCase()).toList();

      final totalOps = progOps.length;
      final approvedOps = progOps.where((o) => o.status == 'approved').toList();
      final totalDists = progDists.length;
      final acceptedDists = progDists.where((d) => d['status'] == 'accepted').toList();

      final double opsApprovalRate = totalOps > 0 ? (approvedOps.length / totalOps) * 100 : 0.0;
      final double distAcceptanceRate = totalDists > 0 ? (acceptedDists.length / totalDists) * 100 : 0.0;

      final double opsUsagePct = totalPeriodOpsCount > 0 ? (totalOps / totalPeriodOpsCount) * 100 : 0.0;
      final double distsUsagePct = totalPeriodDistsCount > 0 ? (totalDists / totalPeriodDistsCount) * 100 : 0.0;
      final double totalAmount = progOps.fold(0.0, (sum, o) => sum + (o.approvedAmount ?? o.requestedAmount));

      // Bank usage distribution for this program (combining ops and distributions)
      final Map<String, int> bankCount = {};
      for (var o in progOps) {
        if (o.bankName.isNotEmpty) bankCount[o.bankName] = (bankCount[o.bankName] ?? 0) + 1;
      }
      for (var d in progDists) {
        final bName = (d['bank_name'] ?? '').toString();
        if (bName.isNotEmpty && bName != 'بنك غير محدد') bankCount[bName] = (bankCount[bName] ?? 0) + 1;
      }
      final sortedBanks = bankCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final totalProgActions = totalOps + totalDists;
      final banksDistribution = sortedBanks.map((e) {
        final pct = totalProgActions > 0 ? (e.value / totalProgActions) * 100 : 0.0;
        return "${e.key} (${pct.toStringAsFixed(0)}%)";
      }).join("، ");

      programStats.add({
        'program_name': pName,
        'total_dists': totalDists,
        'accepted_dists': acceptedDists.length,
        'dist_acceptance_rate': distAcceptanceRate,
        'dist_usage_percentage': distsUsagePct,
        'total_ops': totalOps,
        'approved_ops': approvedOps.length,
        'ops_approval_rate': opsApprovalRate,
        'ops_usage_percentage': opsUsagePct,
        'total_amount': totalAmount,
        'banks_distribution': banksDistribution.isNotEmpty ? banksDistribution : '—',
      });
    }

    programStats.sort((a, b) => ((b['total_ops'] as int) + (b['total_dists'] as int))
        .compareTo((a['total_ops'] as int) + (a['total_dists'] as int)));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Action & Export Bar
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "تحليل البرامج التمويلية (توزيعات + عمليات) (${_getPeriodLabel()})",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final pdfBytes = await ReportsPdfGenerator.generateProgramsReportPdf(
                    periodLabel: _getPeriodLabel(),
                    programStats: programStats,
                  );
                  await Printing.layoutPdf(
                    onLayout: (_) => pdfBytes,
                    name: 'TFC_Programs_Usage_Report_${_selectedYear}.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text("طباعة وتصدير تقرير البرامج (PDF)", style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          GlassCard(
            padding: const EdgeInsets.all(20),
            borderColor: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("📈 استهلاك ونسب نجاح البرامج التمويلية (${programStats.length} برنامج)",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TfcColors.primary)),
                const SizedBox(height: 12),
                programStats.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text("لا توجد بيانات برامج منفذة في هذه الفترة", style: TextStyle(color: TfcColors.outline))),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("اسم البرنامج", style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("عملاء التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("قبول التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("نسبة قبول التوزيع", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("العمليات المنفذة", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("موافقة العمليات", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("نسبة موافقة العمليات", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("إجمالي حجم التمويل", style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text("توزيع الاستخدام حسب البنوك", style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: programStats.map((p) {
                            final distRate = p['dist_acceptance_rate'] as double;
                            final opsRate = p['ops_approval_rate'] as double;
                            return DataRow(
                              cells: [
                                DataCell(Text(p['program_name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text("${p['total_dists']}")),
                                DataCell(Text("${p['accepted_dists']}", style: const TextStyle(color: Colors.greenAccent))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: distRate >= 50 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("${distRate.toStringAsFixed(1)}%",
                                        style: TextStyle(color: distRate >= 50 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text("${p['total_ops']}")),
                                DataCell(Text("${p['approved_ops']}", style: const TextStyle(color: Colors.greenAccent))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: opsRate >= 60 ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text("${opsRate.toStringAsFixed(1)}%",
                                        style: TextStyle(color: opsRate >= 60 ? Colors.greenAccent : Colors.orangeAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                DataCell(Text("${_formatNumber(p['total_amount'])} ج.م", style: const TextStyle(fontWeight: FontWeight.bold))),
                                DataCell(Text(p['banks_distribution'])),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: color.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Flexible(child: Text(title, style: const TextStyle(fontSize: 11, color: TfcColors.outline), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
