import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/client_provider.dart';
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
  final bool isClosed; // true if all operations with invoices for this client are marked closed

  ClientInvoiceSummary({
    required this.clientId,
    required this.clientName,
    required this.representativeName,
    required this.totalFees,
    required this.collectedFees,
    required this.uncollectedFees,
    required this.invoiceCount,
    required this.operations,
    required this.isClosed,
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
  int _selectedTab = 0; // 0: مفتوح (Open), 1: مغلق (Closed)

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

        // A client summary is considered closed if all of its invoice operations are marked closed
        final bool isSummaryClosed = ops.isNotEmpty && ops.every((op) => op.isInvoiceClosed == true);

        list.add(ClientInvoiceSummary(
          clientId: clientId,
          clientName: clientName,
          representativeName: repName,
          totalFees: total,
          collectedFees: collected,
          uncollectedFees: uncollected,
          invoiceCount: ops.length,
          operations: ops,
          isClosed: isSummaryClosed,
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

  Future<void> _toggleInvoiceClosed(OperationEntry op, bool newClosedState) async {
    try {
      if (SupabaseConfig.isInitialized) {
        try {
          await SupabaseConfig.client
              .from('operation_entries')
              .update({'is_invoice_closed': newClosedState})
              .eq('id', op.id);
        } catch (e) {
          debugPrint("Failed to update is_invoice_closed in DB: $e");
        }
      }

      setState(() {
        op.isInvoiceClosed = newClosedState;
      });

      // Reload invoices to refresh summaries and tab counts
      await _loadAllInvoices();

      // Trigger global operations refresh
      ref.read(operationsRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newClosedState ? "تم نقل الفاتورة إلى قسم مغلق 🔒" : "تمت إعادة فتح الفاتورة بنجاح 🔓",
              textAlign: TextAlign.right,
            ),
            backgroundColor: newClosedState ? Colors.blueGrey : TfcColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error toggling invoice closed state: $e");
    }
  }

  Future<void> _closeAllClientInvoices(ClientInvoiceSummary summary) async {
    try {
      final collectedOps = summary.operations.where((op) => op.invoiceCollected == 'collected' && !op.isInvoiceClosed).toList();
      if (collectedOps.isEmpty) return;

      if (SupabaseConfig.isInitialized) {
        for (final op in collectedOps) {
          try {
            await SupabaseConfig.client
                .from('operation_entries')
                .update({'is_invoice_closed': true})
                .eq('id', op.id);
          } catch (e) {
            debugPrint("Failed to close invoice ${op.id}: $e");
          }
        }
      }

      await _loadAllInvoices();
      ref.read(operationsRefreshTriggerProvider.notifier).state++;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إغلاق ونقل جميع الفواتير المحصلة إلى تبويب مغلق 🔒", textAlign: TextAlign.right),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error closing all client invoices: $e");
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showInvoiceDetailsDialog(ClientInvoiceSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: TfcColors.surfaceDim,
          title: Text(
            "فواتير العميل: ${summary.clientName}",
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary),
          ),
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: MediaQuery.of(context).size.width > 700 ? 650 : MediaQuery.of(context).size.width * 0.95,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: summary.operations.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                itemBuilder: (context, idx) {
                  final op = summary.operations[idx];
                  final isCollected = op.invoiceCollected == 'collected';
                  final isClosed = op.isInvoiceClosed;

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
                            Wrap(
                              spacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (isClosed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blueGrey, width: 0.5),
                                    ),
                                    child: const Text(
                                      "مغلق 🔒",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCollected
                                        ? TfcColors.success.withValues(alpha: 0.15)
                                        : TfcColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCollected ? "تم التحصيل ✅" : "لم يتم التحصيل ❌",
                                    style: TextStyle(
                                      color: isCollected ? TfcColors.success : TfcColors.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("البرنامج: ${op.programName}", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                        Text("مبلغ الموافقة: ${_fmt(op.approvedAmount ?? 0.0)} ج.م", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                        Text("نسبة الأتعاب: ${op.invoicePercentage ?? 0}%", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
                        Text("مبلغ الأتعاب المستحق: ${_fmt(op.invoiceFees ?? 0.0)} ج.م", style: const TextStyle(color: TfcColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        // Action button for closing/reopening invoice if collected
                        if (isCollected) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final newState = !isClosed;
                                  await _toggleInvoiceClosed(op, newState);
                                  setDialogState(() {
                                    op.isInvoiceClosed = newState;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isClosed
                                      ? Colors.blueGrey.withValues(alpha: 0.25)
                                      : const Color(0xFFFFD700).withValues(alpha: 0.18),
                                  foregroundColor: isClosed ? Colors.white70 : const Color(0xFFFFD700),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                      color: isClosed ? Colors.blueGrey : const Color(0xFFFFD700),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                icon: Icon(isClosed ? Icons.lock_open : Icons.lock_outline, size: 14),
                                label: Text(
                                  isClosed ? "إعادة فتح الفاتورة 🔓" : "إغلاق الفاتورة (تحويل للمغلق) 🔒",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ],
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
              child: const Text("إغلاق النافذة"),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(operationsRefreshTriggerProvider, (previous, next) {
      _loadAllInvoices();
    });

    final searchFiltered = _summaries.where((s) {
      return s.clientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.representativeName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Tab counts
    final int openCount = searchFiltered.where((s) => !s.isClosed).length;
    final int closedCount = searchFiltered.where((s) => s.isClosed).length;

    // Filter by selected tab
    final filtered = searchFiltered.where((s) {
      if (_selectedTab == 0) {
        return !s.isClosed;
      } else {
        return s.isClosed;
      }
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 10 : 14,
                vertical: isMobile ? 8 : 10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "فواتير وأتعاب الخدمات",
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 18,
                                fontWeight: FontWeight.bold,
                                color: TfcColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isMobile ? "متابعة الفواتير المفتوحة والمغلقة" : "عرض ومتابعة الفواتير المحصلة وغير المحصلة لجميع العملاء المقبولين",
                              style: TextStyle(color: TfcColors.outline, fontSize: isMobile ? 10 : 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: TfcColors.primary),
                        onPressed: _loadAllInvoices,
                        tooltip: "تحديث البيانات",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tabs Bar (مفتوح / مغلق)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // Tab 0: مفتوح (Open)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 0),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 0 ? TfcColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 15,
                                    color: _selectedTab == 0 ? Colors.black : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "فواتير مفتوحة ($openCount)",
                                    style: TextStyle(
                                      color: _selectedTab == 0 ? Colors.black : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Tab 1: مغلق (Closed)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedTab = 1),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTab == 1 ? Colors.blueGrey : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 15,
                                    color: _selectedTab == 1 ? Colors.white : Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "فواتير مغلقة ($closedCount)",
                                    style: TextStyle(
                                      color: _selectedTab == 1 ? Colors.white : Colors.white70,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search Bar
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  const SizedBox(height: 10),

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
                      child: Center(
                        child: Text(
                          _selectedTab == 0
                              ? "لا توجد فواتير مفتوحة حالياً"
                              : "لا توجد فواتير مغلقة حالياً",
                          style: const TextStyle(color: TfcColors.outline),
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
                        // Check if this client has any collected invoice that is not yet closed
                        final hasCollectedNotClosed = item.operations.any((op) => op.invoiceCollected == 'collected' && !op.isInvoiceClosed);

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
                                        if (item.isClosed) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blueGrey.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.blueGrey, width: 0.5),
                                            ),
                                            child: const Text(
                                              "مغلق 🔒",
                                              style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        // Quick close button if client has collected invoices in the open tab
                                        if (_selectedTab == 0 && hasCollectedNotClosed) ...[
                                          ElevatedButton.icon(
                                            onPressed: () => _closeAllClientInvoices(item),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                              foregroundColor: const Color(0xFFFFD700),
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                side: const BorderSide(color: Color(0xFFFFD700), width: 0.5),
                                              ),
                                            ),
                                            icon: const Icon(Icons.lock_outline, size: 12),
                                            label: const Text(
                                              "إغلاق 🔒",
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
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
          );
        },
      ),
    );
  }
}
