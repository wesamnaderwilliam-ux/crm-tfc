import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/client_provider.dart';
import '../../providers/auth_provider.dart';
import 'operations_widget.dart';

class ClientInvoiceSummary {
  final String clientId;
  final String clientName;
  final String representativeName;
  final double totalFees;
  final double collectedFees;
  final double uncollectedFees;
  final int invoiceCount;
  final List<OperationEntry> operations;

  ClientInvoiceSummary({
    required this.clientId,
    required this.clientName,
    required this.representativeName,
    required this.totalFees,
    required this.collectedFees,
    required this.uncollectedFees,
    required this.invoiceCount,
    required this.operations,
  });
}

class InvoicesScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;

  const InvoicesScreen({super.key, required this.onViewClient});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  bool _isLoading = true;
  List<ClientInvoiceSummary> _summaries = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadAllInvoices();
  }

  Future<void> _loadAllInvoices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (!SupabaseConfig.isInitialized) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch all operations with invoices
      final response = await SupabaseConfig.client
          .from('operation_entries')
          .select('*')
          .eq('has_invoice', true);

      final List<dynamic> rows = response as List<dynamic>;
      final operations = rows.map((r) => OperationEntry.fromJson(r)).toList();

      // Group operations by client_id
      final groupedOps = <String, List<OperationEntry>>{};
      for (final op in operations) {
        groupedOps.putIfAbsent(op.clientId, () => []).add(op);
      }

      // Load clients to map names and representative names
      final clientState = ref.read(clientProvider);
      final clientsMap = {for (var c in clientState.clients) c.id: c};

      final List<ClientInvoiceSummary> list = [];
      groupedOps.forEach((clientId, ops) {
        final client = clientsMap[clientId];
        final clientName = client?.fullName ?? "عميل غير معروف";
        final repName = client?.representativeName ?? "لم يحدد";

        double total = 0.0;
        double collected = 0.0;
        double uncollected = 0.0;

        for (final op in ops) {
          final fees = op.invoiceFees ?? 0.0;
          total += fees;
          if (op.invoiceCollected == 'collected') {
            collected += fees;
          } else {
            uncollected += fees;
          }
        }

        list.add(ClientInvoiceSummary(
          clientId: clientId,
          clientName: clientName,
          representativeName: repName,
          totalFees: total,
          collectedFees: collected,
          uncollectedFees: uncollected,
          invoiceCount: ops.length,
          operations: ops,
        ));
      });

      if (mounted) {
        setState(() {
          _summaries = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading all invoices: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showInvoiceDetailsDialog(ClientInvoiceSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: Text(
          "فواتير العميل: ${summary.clientName}",
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary),
        ),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 600,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: summary.operations.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, idx) {
                final op = summary.operations[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.01),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            op.bankName,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("البرنامج: ${op.programName}", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                      Text("مبلغ الموافقة: ${_fmt(op.approvedAmount ?? 0.0)} ج.م", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                      Text("نسبة الأتعاب: ${op.invoicePercentage ?? 0}%", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                      Text("مبلغ الأتعاب المستحق: ${_fmt(op.invoiceFees ?? 0.0)} ج.م", style: const TextStyle(color: TfcColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إغلاق"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onViewClient(summary.clientId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
            child: const Text("عرض ملف العميل كاملاً", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(operationsRefreshTriggerProvider, (previous, next) {
      _loadAllInvoices();
    });

    final filtered = _summaries.where((s) {
      return s.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.representativeName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "فواتير وأتعاب الخدمات",
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: TfcColors.primary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "عرض ومتابعة الفواتير المحصلة وغير المحصلة لجميع العملاء المقبولين",
                        style: TextStyle(color: TfcColors.outline),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: TfcColors.primary),
                    onPressed: _loadAllInvoices,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: "البحث باسم العميل أو اسم الموظف المسؤول...",
                    prefixIcon: Icon(Icons.search, color: TfcColors.outline),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: TfcColors.primary),
                  ),
                )
              else if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  child: const Center(
                    child: Text(
                      "لا توجد فواتير مطابقة للبحث أو مسجلة حالياً",
                      style: TextStyle(color: TfcColors.outline),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return InkWell(
                      onTap: () => _showInvoiceDetailsDialog(item),
                      borderRadius: BorderRadius.circular(16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Client & Responsible employee Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person, color: TfcColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.clientName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "المسؤول: ${item.representativeName}",
                                    style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 12),

                            // Invoice totals breakdown
                            Row(
                              children: [
                                // Total Fees
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("إجمالى الأتعاب المستحقة", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${_fmt(item.totalFees)} ج.م",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TfcColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                // Collected
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("المبلغ المحصل", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${_fmt(item.collectedFees)} ج.م",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TfcColors.success),
                                      ),
                                    ],
                                  ),
                                ),
                                // Uncollected
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("المبلغ غير المحصل", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${_fmt(item.uncollectedFees)} ج.م",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TfcColors.error),
                                      ),
                                    ],
                                  ),
                                ),
                                // Invoice Count
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: TfcColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${item.invoiceCount} فاتورة",
                                    style: const TextStyle(color: TfcColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
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
        ),
      ),
    );
  }
}
