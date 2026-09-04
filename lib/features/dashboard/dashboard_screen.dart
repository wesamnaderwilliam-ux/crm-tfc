import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../client/operations_widget.dart';
import '../../core/theme.dart';
import '../../providers/client_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../core/supabase_config.dart';
import '../../providers/employees_provider.dart';
import '../../models/profile.dart';
import '../accounts/accounts_screen.dart';
import '../employees/employee_targets_panel.dart';
import '../../core/widgets/interactive_hover_card.dart';
import '../client/credit_calculator_screen.dart';
import '../../core/utils/client_visibility_helper.dart';
import '../../models/client_model.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;

  const DashboardScreen({super.key, required this.onViewClient});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedStatus = "all";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final permissions = ref.watch(permissionsProvider)[authState.role] ?? RolePermissions.fromDefaults(authState.role);
    final clientState = ref.watch(clientProvider);

    if (clientState.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: TfcColors.primary));
    }

    final employeesState = ref.watch(employeesProvider);

    // Role & Manager-hierarchy based visibility filtering
    final visibleClients = ClientVisibilityHelper.filterClients(
      clients: clientState.clients,
      authState: authState,
      allEmployees: employeesState.employees,
    );

    // Search and Status Filter logic on top of visible clients
    final filteredClients = visibleClients.where((client) {
      final matchesSearch =
          client.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              client.nationalId.contains(_searchQuery) ||
              client.phoneNumber.contains(_searchQuery) ||
              (client.secondaryPhoneNumber ?? '').contains(_searchQuery);

      final matchesStatus =
          _selectedStatus == "all" || client.status == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Financial calculations based on visible clients
    double totalRequestedAmount = 0;
    double approvedAmount = 0;
    double averageCreditScore = 0;
    int pendingCount = 0;

    if (visibleClients.isNotEmpty) {
      double totalCredit = 0;
      for (var c in visibleClients) {
        if (c.status != 'rejected') {
          totalRequestedAmount += c.requestedAmount;
        }
        totalCredit += c.creditScore;
        if (c.status == 'approved') {
          approvedAmount += c.requestedAmount;
        } else if (c.status == 'pending') {
          pendingCount++;
        }
      }
      averageCreditScore = totalCredit / visibleClients.length;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, screenConstraints) {
          final isMobile = screenConstraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 14 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Page Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "لوحة التحكم المالية",
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 26,
                              fontWeight: FontWeight.bold,
                              color: TfcColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "مرحباً بك، ${authState.fullName} - تابع طلبات التمويل والقروض",
                            style: TextStyle(
                              color: TfcColors.outline,
                              fontSize: isMobile ? 11 : 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: TfcColors.primary),
                      tooltip: "تحديث",
                      onPressed: () =>
                          ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: ref.read(authProvider).bankEmployeeId),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 32),

            // 1. KPI Financial cards (visible conditionally if user can view analytics)
            if (permissions.canViewAnalytics) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet = constraints.maxWidth >= 600 &&
                      constraints.maxWidth < 1100;

                  return GridView.count(
                    crossAxisCount: isMobile ? 2 : (isTablet ? 2 : 4),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: isMobile ? 10 : 16,
                    mainAxisSpacing: isMobile ? 10 : 16,
                    childAspectRatio: isMobile ? 1.6 : 2.2,
                    children: [
                      _buildKpiCard(
                        title: "إجمالي التمويل المطلوب",
                        value: "${_formatMoney(totalRequestedAmount)} ج.م",
                        icon: Icons.payments,
                        color: TfcColors.primary,
                      ),
                      _buildKpiCard(
                        title: "التمويلات المعتمدة",
                        value: "${_formatMoney(approvedAmount)} ج.m",
                        icon: Icons.check_circle,
                        color: TfcColors.success,
                      ),
                      _buildKpiCard(
                        title: "متوسط التقييم الائتماني",
                        value: averageCreditScore.toStringAsFixed(0),
                        icon: Icons.speed,
                        color: TfcColors.secondary,
                        subText: "/ 850 درجة",
                      ),
                      _buildKpiCard(
                        title: "الطلبات المعلقة",
                        value: pendingCount.toString(),
                        icon: Icons.hourglass_empty,
                        color: Colors.amber,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ] else ...[
              // Locked Analytics placeholder
              const GlassCard(
                padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, color: TfcColors.secondary),
                    SizedBox(width: 12),
                    Text(
                      "إحصائيات لوحة التحكم مخفية من قِبل الإدارة للمسمى الوظيفي الحالي",
                      style: TextStyle(color: TfcColors.outline),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],

            // Target Performance Widget - visible for ALL employees
            const _DashboardTargetPerformanceWidget(),
            const SizedBox(height: 12),

            // Wallet Widget - Shows personal commission details
            const _DashboardWalletWidget(),
            const SizedBox(height: 12),

            // 2. Comprehensive Status Breakdown Widget (توزيع حالات الطلبات)
            _DashboardStatusBreakdownWidget(
              visibleClients: visibleClients,
              onViewClient: widget.onViewClient,
            ),
            const SizedBox(height: 24),

            // 3. Follow-ups Table (جدول المتابعات)
            Builder(
              builder: (context) {
                // Group follow-ups by client and date to resolve status overrides (taking the newest log per day)
                final Map<String, Map<String, dynamic>> resolvedFollowUps = {};

                for (var client in visibleClients) {
                  for (var log in client.history) {
                    if (log.logType == 'follow_up' && log.followUpDate != null) {
                      // Create a unique key per client and date
                      final dateKey = "${log.followUpDate!.year}-${log.followUpDate!.month}-${log.followUpDate!.day}";
                      final uniqueKey = "${client.id}_$dateKey";
                      
                      final existing = resolvedFollowUps[uniqueKey];
                      if (existing == null) {
                        resolvedFollowUps[uniqueKey] = {
                          'client': client,
                          'log': log,
                        };
                      } else {
                        // Keep the newest log (highest creation date or update)
                        final existingLog = existing['log'] as InteractionLogModel;
                        if (log.createdAt.isAfter(existingLog.createdAt)) {
                          resolvedFollowUps[uniqueKey] = {
                            'client': client,
                            'log': log,
                          };
                        }
                      }
                    }
                  }
                }

                final List<Map<String, dynamic>> allFollowUps = resolvedFollowUps.values.toList();

                // Sort by follow-up date (newest first), then by creation date
                allFollowUps.sort((a, b) {
                  final logA = a['log'] as InteractionLogModel;
                  final logB = b['log'] as InteractionLogModel;
                  final dateA = logA.followUpDate ?? logA.createdAt;
                  final dateB = logB.followUpDate ?? logB.createdAt;
                  return dateB.compareTo(dateA);
                });

                // Filter for Dashboard: Only follow-ups that are due today/overdue (pending) OR due tomorrow
                // All other distant follow-ups and completed ones will remain in the dedicated Follow-ups section
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                // End of tomorrow (inclusive): today + 2 days start
                final dayAfterTomorrowStart = todayStart.add(const Duration(days: 2));

                final pendingFollowUps = allFollowUps.where((f) {
                  final log = f['log'] as InteractionLogModel;
                  if (log.followUpStatus == 'completed') return false;
                  if (log.followUpDate == null) return false;
                  
                  // Must be due today or in the past (تاريخها جه ولم تتغير حالتها) OR due tomorrow (فاضل عليه يوم)
                  final fDate = log.followUpDate!;
                  return fDate.isBefore(dayAfterTomorrowStart);
                }).toList();

                final sortedFollowUps = pendingFollowUps;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(Icons.schedule, color: TfcColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          "جدول المتابعات العاجلة (${pendingFollowUps.length} تتطلب إجراء اليوم / غداً)",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: 16,
                      child: sortedFollowUps.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(40),
                              child: Center(
                                child: Text("لا توجد متابعات حالياً",
                                    style: TextStyle(color: TfcColors.outline)),
                              ),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                    // ignore: deprecated_member_use
                                    Colors.white.withOpacity(0.02)),
                                dataRowMinHeight: 64,
                                dataRowMaxHeight: 80,
                                dividerThickness: 0.5,
                                columns: const [
                                  DataColumn(
                                      label: Text("اسم العميل",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("تاريخ المتابعة",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("الحالة",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("الملاحظات",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("بواسطة",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("المندوب",
                                          style: TextStyle(color: TfcColors.primary))),
                                  DataColumn(
                                      label: Text("الإجراءات",
                                          style: TextStyle(color: TfcColors.primary))),
                                ],
                                rows: sortedFollowUps.map((item) {
                                  final client = item['client'] as ClientModel;
                                  final log = item['log'] as InteractionLogModel;
                                  final isPending = log.followUpStatus != 'completed';
                                  final isOverdue = isPending && log.followUpDate != null && log.followUpDate!.isBefore(DateTime.now());

                                  String followUpDateStr = '-';
                                  if (log.followUpDate != null) {
                                    followUpDateStr = "${log.followUpDate!.day}/${log.followUpDate!.month}/${log.followUpDate!.year}";
                                  }

                                  return DataRow(
                                    // ignore: deprecated_member_use
                                    color: WidgetStateProperty.all(
                                      isOverdue
                                          // ignore: deprecated_member_use
                                          ? Colors.redAccent.withOpacity(0.04)
                                          : Colors.transparent,
                                    ),
                                    cells: [
                                      DataCell(InkWell(
                                        onTap: () => widget.onViewClient(client.id),
                                        child: Text(client.fullName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                decoration: TextDecoration.underline)),
                                      )),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isOverdue)
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(Icons.warning_amber, size: 14, color: Colors.redAccent),
                                            ),
                                          Text(
                                            followUpDateStr,
                                            style: TextStyle(
                                              color: isOverdue ? Colors.redAccent : null,
                                              fontWeight: isOverdue ? FontWeight.bold : null,
                                            ),
                                          ),
                                        ],
                                      )),
                                      DataCell(
                                        PopupMenuButton<String>(
                                          tooltip: "تغيير حالة المتابعة",
                                          onSelected: (newStatus) {
                                            ref.read(clientProvider.notifier).updateFollowUpStatus(
                                                  client.id,
                                                  log.id,
                                                  newStatus,
                                                  ref.read(authProvider).fullName,
                                                );
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'pending',
                                              child: Text("قيد المتابعة ⏳", textDirection: TextDirection.rtl),
                                            ),
                                            const PopupMenuItem(
                                              value: 'completed',
                                              child: Text("تمت المتابعة ✅", textDirection: TextDirection.rtl),
                                            ),
                                          ],
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isPending
                                                  // ignore: deprecated_member_use
                                                  ? Colors.orangeAccent.withOpacity(0.1)
                                                  // ignore: deprecated_member_use
                                                  : TfcColors.success.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isPending
                                                    // ignore: deprecated_member_use
                                                    ? Colors.orangeAccent.withOpacity(0.3)
                                                    // ignore: deprecated_member_use
                                                    : TfcColors.success.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  isPending ? "قيد المتابعة" : "تمت المتابعة",
                                                  style: TextStyle(
                                                    color: isPending ? Colors.orangeAccent : TfcColors.success,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                const Icon(Icons.arrow_drop_down, size: 14, color: Colors.white60),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            log.notes.isNotEmpty ? log.notes : "-",
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(log.createdBy, style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(client.representativeName ?? "-", style: const TextStyle(fontSize: 12))),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isPending)
                                              IconButton(
                                                icon: const Icon(Icons.check, color: TfcColors.success, size: 16),
                                                tooltip: "إكمال المتابعة",
                                                onPressed: () {
                                                  ref.read(clientProvider.notifier).updateFollowUpStatus(
                                                        client.id,
                                                        log.id,
                                                        'completed',
                                                        ref.read(authProvider).fullName,
                                                      );
                                                },
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.arrow_forward_ios,
                                                  color: TfcColors.primary, size: 14),
                                              tooltip: "فتح ملف العميل",
                                              onPressed: () => widget.onViewClient(client.id),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    },
  ),
);
}

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        // ignore: deprecated_member_use
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedStatus,
          dropdownColor: TfcColors.surfaceDim,
          items: const [
            DropdownMenuItem(value: "all", child: Text("كل الحالات")),
            DropdownMenuItem(value: "pending", child: Text("قيد الانتظار")),
            DropdownMenuItem(value: "iscore_inquiry", child: Text("استعلام ايسكور")),
            DropdownMenuItem(value: "preparing_documents", child: Text("تحضير الاوراق")),
            DropdownMenuItem(
                value: "under_review", child: Text("قيد الدراسة والمراجعة")),
            DropdownMenuItem(value: "at_bank", child: Text("فى البنك")),
            DropdownMenuItem(value: "approved", child: Text("مقبول")),
            DropdownMenuItem(value: "rejected", child: Text("مرفوض")),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedStatus = val;
              });
            }
          },
        ),
      ),
    );
  }

  void _confirmDelete(String clientId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: Text("هل أنت متأكد من حذف ملف العميل '$name' نهائياً؟",
            textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(clientProvider.notifier).deleteClient(clientId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("تم حذف العميل بنجاح",
                        textAlign: TextAlign.right)),
              );
            },
            child: const Text("حذف"),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
      {required String title,
      required String value,
      required IconData icon,
      required Color color,
      String? subText}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 220;

        return GlassCard(
          padding: EdgeInsets.symmetric(
            vertical: isCompact ? 10 : 16,
            horizontal: isCompact ? 10 : 16,
          ),
          borderRadius: 14,
          borderColor: color.withValues(alpha: 0.15),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: TfcColors.onSurfaceVariant,
                        fontSize: isCompact ? 10 : 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: isCompact ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          if (subText != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              subText,
                              style: TextStyle(
                                fontSize: isCompact ? 9 : 11,
                                color: TfcColors.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: isCompact ? 18 : 22),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'approved':
        color = TfcColors.success;
        label = "مقبول";
        break;
      case 'under_review':
        color = Colors.blueAccent;
        label = "قيد الدراسة";
        break;
      case 'iscore_inquiry':
        color = Colors.orangeAccent;
        label = "استعلام ايسكور";
        break;
      case 'preparing_documents':
        color = Colors.cyan;
        label = "تحضير الاوراق";
        break;
      case 'at_bank':
        color = Colors.deepPurpleAccent;
        label = "فى البنك";
        break;
      case 'rejected':
        color = Colors.redAccent;
        label = "مرفوض";
        break;
      default:
        color = Colors.amber;
        label = "معلق";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        // ignore: deprecated_member_use
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Color _getCreditScoreColor(int score) {
    if (score >= 700) return TfcColors.success;
    if (score >= 600) return Colors.amber;
    return Colors.redAccent;
  }

  String _formatMoney(double value) {
    if (value >= 1000000) {
      return "${(value / 1000000).toStringAsFixed(2)}M";
    }
    if (value >= 1000) {
      return "${(value / 1000).toStringAsFixed(0)}K";
    }
    return value.toStringAsFixed(0);
  }
}

// ============================================================
// Dashboard Target Performance Widget
// ============================================================
class _DashboardTargetPerformanceWidget extends ConsumerStatefulWidget {
  const _DashboardTargetPerformanceWidget();

  @override
  ConsumerState<_DashboardTargetPerformanceWidget> createState() => _DashboardTargetPerformanceWidgetState();
}

class _DashboardTargetPerformanceWidgetState extends ConsumerState<_DashboardTargetPerformanceWidget> {
  bool _isLoading = true;
  double _targetAmount = 0.0;
  double _achievedAmount = 0.0;
  String _monthStr = "";
  int _remainingDays = 1;
  TargetRollupNode? _userNode;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _monthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    
    // Calculate remaining days
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    _remainingDays = daysInMonth - now.day + 1;
    if (_remainingDays < 1) _remainingDays = 1;

    _loadTargetPerformance();
  }

  Future<void> _loadTargetPerformance() async {
    try {
      if (!SupabaseConfig.isInitialized) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch targets for current month
      final targetsResponse = await SupabaseConfig.client
          .from('employee_targets')
          .select('*')
          .eq('target_month', _monthStr);

      // Fetch approved operations for current month
      final opsResponse = await SupabaseConfig.client
          .from('operation_entries')
          .select('*')
          .eq('status', 'approved');

      final List<dynamic> targetsRows = targetsResponse as List<dynamic>;
      final List<dynamic> opsRows = opsResponse as List<dynamic>;

      final targets = targetsRows.map((r) => EmployeeTargetModel.fromJson(r)).toList();
      final operations = opsRows.map((r) => OperationEntry.fromJson(r)).toList();

      final empState = ref.read(employeesProvider);
      final activeEmployees = empState.employees
          .where((e) => e.employeeStatus == 'active' && e.role != 'bank_employee')
          .toList();

      // Find current employee profile
      final currentProfile = activeEmployees.firstWhereOrNull((e) => e.id == currentUserId);
      if (currentProfile == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Rollup calculations
      final Map<String, double> targetMap = {
        for (var t in targets) t.employeeId: t.targetAmount
      };

      // Calculate personal achieved for each active employee
      final Map<String, double> achievedMap = {};
      final now = DateTime.now();
      
      for (final emp in activeEmployees) {
        double achieved = 0.0;
        final cleanEmpName = emp.fullName.toLowerCase().trim();
        
        for (final op in operations) {
          if (op.approvalDate != null &&
              op.approvalDate!.year == now.year &&
              op.approvalDate!.month == now.month) {
            final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
            final repName = (client?.representativeName ?? '').toLowerCase().trim();
            
            if (repName == cleanEmpName && op.approvedAmount != null) {
              achieved += op.approvedAmount!;
            }
          }
        }
        achievedMap[emp.id] = achieved;
      }

      // Construct nodes
      final Map<String, TargetRollupNode> nodes = {
        for (var emp in activeEmployees)
          emp.id: TargetRollupNode(
            employee: emp,
            personalTarget: targetMap[emp.id] ?? 0.0,
            personalAchieved: achievedMap[emp.id] ?? 0.0,
          )
      };

      // Link children
      for (final node in nodes.values) {
        final managerId = node.employee.managerId;
        if (managerId != null && nodes.containsKey(managerId)) {
          nodes[managerId]!.children.add(node);
        }
      }

      // Find target node for current logged in user
      final userNode = nodes[currentUserId];
      if (userNode != null) {
        if (mounted) {
          setState(() {
            _userNode = userNode;
            _targetAmount = userNode.totalTarget;
            _achievedAmount = userNode.totalAchieved;
            _isLoading = false;
          });
        }
      } else {
        // Fallback if user profile node is missing
        if (mounted) {
          setState(() {
            _userNode = null;
            _targetAmount = targetMap[currentUserId] ?? 0.0;
            _achievedAmount = achievedMap[currentUserId] ?? 0.0;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading dashboard target: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_targetAmount <= 0) {
      return const SizedBox.shrink(); // No target set for this user, hide card
    }

    final remaining = _targetAmount - _achievedAmount;
    final remainingAmount = remaining > 0 ? remaining : 0.0;
    final double percent = (_achievedAmount / _targetAmount) * 100;
    final dailyAvgRequired = remainingAmount / _remainingDays;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              TfcColors.primary.withValues(alpha: 0.08),
              Colors.orangeAccent.withValues(alpha: 0.03),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TfcColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TfcColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.track_changes, color: TfcColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "مقياس الأهداف البيعية (تارجت الشهر الحالي)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TfcColors.primary),
                      ),
                      Text(
                        "يحتوي على أهدافك الشخصية بالإضافة إلى أهداف فريقك البيعي بالتبعية",
                        style: TextStyle(color: TfcColors.outline, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "متبقي $_remainingDays يوم",
                    style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("الهدف البيعي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                    Text("${_fmt(_targetAmount)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("المحقق الفعلي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                    Text(
                      "${_fmt(_achievedAmount)} ج.م", 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.success)
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("المتبقي لتحقيق الهدف", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                    Text(
                      "${_fmt(remainingAmount)} ج.م", 
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 16, 
                        color: remainingAmount > 0 ? TfcColors.error : TfcColors.success
                      )
                    ),
                  ],
                ),
                Text(
                  "${percent.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 22, 
                    color: percent >= 100 
                        ? TfcColors.success 
                        : percent >= 50 
                            ? Colors.orangeAccent 
                            : TfcColors.error
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _targetAmount > 0 ? (_achievedAmount / _targetAmount).clamp(0.0, 1.0) : 0.0,
                backgroundColor: Colors.white10,
                color: percent >= 100 
                    ? TfcColors.success 
                    : percent >= 50 
                        ? Colors.orangeAccent 
                        : TfcColors.error,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 12),

            // Daily average Required
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("المتوسط اليومي المطلوب للأيام المتبقية في الشهر:", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                Text(
                  remainingAmount > 0
                      ? "${_fmt(dailyAvgRequired)} ج.م / يومياً"
                      : "تم تحقيق الهدف الشهري بنجاح! 🎉",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: remainingAmount > 0 ? Colors.orangeAccent : TfcColors.success,
                  ),
                ),
              ],
            ),
            if (_userNode != null && _userNode!.children.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(color: Colors.white10),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.people_outline, color: TfcColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text(
                    "تفاصيل المستهدف لفريق العمل",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMemberTargetRow(
                "أدائي الشخصي (${_userNode!.employee.fullName})",
                _userNode!.personalTarget,
                _userNode!.personalAchieved,
                isSelf: true,
              ),
              ..._userNode!.children.map((childNode) {
                return _buildMemberTargetRow(
                  childNode.employee.fullName,
                  childNode.personalTarget,
                  childNode.personalAchieved,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTargetRow(String name, double target, double achieved, {bool isSelf = false}) {
    if (target <= 0) return const SizedBox.shrink();
    
    final percent = target > 0 ? (achieved / target) * 100 : 0.0;
    final displayPercent = percent.toStringAsFixed(1);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
                  color: isSelf ? TfcColors.primary : Colors.white70,
                ),
              ),
              Text(
                "المحقق: ${_fmt(achieved)} / المستهدف: ${_fmt(target)} ج.م ($displayPercent%)",
                style: TextStyle(
                  fontSize: 11,
                  color: percent >= 100 
                      ? TfcColors.success 
                      : percent >= 50 
                          ? Colors.orangeAccent 
                          : TfcColors.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: target > 0 ? (achieved / target).clamp(0.0, 1.0) : 0.0,
              backgroundColor: Colors.white10,
              color: percent >= 100 
                  ? TfcColors.success 
                  : percent >= 50 
                      ? Colors.orangeAccent 
                      : TfcColors.error,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dashboard Wallet Widget (المحفظة الشخصية)
// ============================================================
class _DashboardWalletWidget extends ConsumerStatefulWidget {
  const _DashboardWalletWidget();

  @override
  ConsumerState<_DashboardWalletWidget> createState() => _DashboardWalletWidgetState();
}

class _DashboardWalletWidgetState extends ConsumerState<_DashboardWalletWidget> {
  bool _isLoading = true;
  List<OperationEntry> _myCollectedOps = [];
  List<OperationEntry> _myUncollectedOps = [];
  double _totalCommission = 0.0;
  double _collectedCommission = 0.0;
  double _uncollectedCommission = 0.0;
  double _totalExpenses = 0.0;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  // Normalized name helper to ignore spacing, Arabic hamza variations, and phone numbers
  String normalizeName(String name) {
    return name
        .replaceAll(RegExp(r'\s*\(تجريبي\)'), '')
        .replaceAll(RegExp(r'\d+'), '') // Remove any numbers/phone numbers in the name
        .replaceAll("أ", "ا")
        .replaceAll("إ", "ا")
        .replaceAll("آ", "ا")
        .replaceAll("ة", "ه")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  Future<void> _loadWalletData() async {
    try {
      if (!SupabaseConfig.isInitialized) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final authState = ref.read(authProvider);
      final currentUserId = authState.user?.id;
      if (currentUserId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final cleanUser = normalizeName(authState.fullName);
      final bool isManager = authState.role == 'manager';
      final bool isAdmin = authState.role == 'admin';

      // Get all employees to check manager relations
      final empState = ref.read(employeesProvider);
      final List<Profile> allProfiles = List<Profile>.from(empState.employees);
      final mySubordinates = isManager 
          ? allProfiles.where((e) => e.managerId == currentUserId).toList()
          : <Profile>[];
      
      final List<String> subordinateNames = mySubordinates
          .map((e) => normalizeName(e.fullName))
          .toList();

      // Fetch all operations with invoices
      final opsResponse = await SupabaseConfig.client
          .from('operation_entries')
          .select('*')
          .eq('has_invoice', true);

      final List<dynamic> opsRows = opsResponse as List<dynamic>;
      final operations = opsRows.map((r) => OperationEntry.fromJson(r)).toList();

      if (isAdmin) {
        // Fetch all expenses to subtract from profits
        final expResponse = await SupabaseConfig.client.from('expenses').select('*');
        final List<dynamic> expRows = expResponse as List<dynamic>;
        final List<ExpenseModel> expenses = expRows.map((r) => ExpenseModel.fromJson(r)).toList();
        
        double totalExpenses = 0.0;
        final now = DateTime.now();
        for (var exp in expenses) {
          if (exp.expenseDate.year == now.year && exp.expenseDate.month == now.month) {
            totalExpenses += exp.amount;
          }
        }

        // Admin calculations (Collected fees, Uncollected fees, Commissions)
        double totalCollectedFees = 0.0;
        double totalUncollectedFees = 0.0;
        double totalCollectedCommissions = 0.0;
        double totalUncollectedCommissions = 0.0;

        for (var op in operations) {
          if (op.approvalDate != null &&
              op.approvalDate!.year == now.year &&
              op.approvalDate!.month == now.month) {
            
            final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
            final repName = (client?.representativeName ?? '').toLowerCase().trim();
            final empProfile = allProfiles.firstWhereOrNull((e) => e.fullName.toLowerCase().trim() == repName);

            final fees = op.invoiceFees ?? 0.0;
            final isCollected = op.invoiceCollected == 'collected';

            double empComm = fees * 0.10;
            double mgrComm = 0.0;

            if (empProfile != null && empProfile.managerId != null) {
              final manager = allProfiles.firstWhereOrNull((e) => e.id == empProfile.managerId);
              if (manager != null && manager.role != 'admin') {
                mgrComm = fees * 0.05;
              }
            }

            final double totalComm = empComm + mgrComm;

            if (isCollected) {
              totalCollectedFees += fees;
              totalCollectedCommissions += totalComm;
            } else {
              totalUncollectedFees += fees;
              totalUncollectedCommissions += totalComm;
            }
          }
        }

        // صافي أرباح محصلة = إجمالي الأتعاب المحصلة - (إجمالي العمولات المحصلة + إجمالي المصاريف)
        final double collectedProfit = totalCollectedFees - (totalCollectedCommissions + totalExpenses);
        // أرباح غير محصلة = إجمالي الأتعاب غير المحصلة - إجمالي العمولات غير المحصلة
        final double uncollectedProfit = totalUncollectedFees - totalUncollectedCommissions;
        // صافي الأرباح الكلية المتوقعة = محصل + غير محصل
        final double totalExpectedProfit = collectedProfit + uncollectedProfit;

        if (mounted) {
          setState(() {
            _myCollectedOps = operations.where((op) => op.invoiceCollected == 'collected').toList();
            _myUncollectedOps = operations.where((op) => op.invoiceCollected != 'collected').toList();
            _totalCommission = totalExpectedProfit;
            _collectedCommission = collectedProfit;
            _uncollectedCommission = uncollectedProfit;
            _totalExpenses = totalExpenses;
            _isLoading = false;
          });
        }
        return;
      }

      // Filter operations relevant to this wallet for managers/employees
      final myOps = operations.where((op) {
        final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
        if (client == null) return false;
        
        final cleanRepName = normalizeName(client.representativeName ?? '');
        
        bool isPersonal = cleanRepName == cleanUser || cleanRepName.contains(cleanUser) || cleanUser.contains(cleanRepName);
        if (isPersonal) return true;
        
        if (isManager) {
          return subordinateNames.any((subName) => cleanRepName == subName || cleanRepName.contains(subName) || subName.contains(cleanRepName));
        }
        return false;
      }).toList();

      final collected = myOps.where((op) => op.invoiceCollected == 'collected').toList();
      final uncollected = myOps.where((op) => op.invoiceCollected != 'collected').toList();

      // Calculation of commissions
      double total = 0.0;
      double collComm = 0.0;
      double uncollComm = 0.0;

      for (var op in myOps) {
        final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
        final cleanRepName = normalizeName(client?.representativeName ?? '');
        final fees = op.invoiceFees ?? 0.0;
        final isCollected = op.invoiceCollected == 'collected';
        
        double comm = 0.0;
        bool isPersonal = cleanRepName == cleanUser || cleanRepName.contains(cleanUser) || cleanUser.contains(cleanRepName);
        
        if (isPersonal) {
          comm = fees * 0.10; // 10%
        } else if (isManager) {
          comm = fees * 0.05; // 5%
        }
        
        total += comm;
        if (isCollected) {
          collComm += comm;
        } else {
          uncollComm += comm;
        }
      }

      if (mounted) {
        setState(() {
          _myCollectedOps = collected;
          _myUncollectedOps = uncollected;
          _totalCommission = total;
          _collectedCommission = collComm;
          _uncollectedCommission = uncollComm;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading wallet details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  void _showDetailsDialog({required String title, required List<OperationEntry> ops, required bool isCollected}) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TfcColors.surfaceDim,
          title: Text(
            title,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isCollected ? TfcColors.success : Colors.orangeAccent,
              fontSize: 16,
            ),
          ),
          content: SizedBox(
            width: 500,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ops.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text("لا توجد فواتير في هذا القسم حالياً.", textAlign: TextAlign.center, style: TextStyle(color: TfcColors.outline)),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: ops.length,
                            separatorBuilder: (c, i) => const Divider(color: Colors.white10),
                            itemBuilder: (context, index) {
                        final op = ops[index];
                        final clientState = ref.read(clientProvider);
                        final client = clientState.clients.firstWhereOrNull((c) => c.id == op.clientId);
                        final clientName = client?.fullName ?? "عميل غير معروف";
                        
                        final authState = ref.read(authProvider);
                        final bool isAdminUser = authState.role == 'admin';
                        final cleanUser = normalizeName(authState.fullName);
                        final cleanRepName = normalizeName(client?.representativeName ?? '');
                        
                        final opFees = op.invoiceFees ?? 0.0;
                        final repName = client?.representativeName ?? 'غير محدد';

                        if (isAdminUser) {
                          // Admin view: show office profit per operation
                          final empState = ref.read(employeesProvider);
                          final allProfiles = List<Profile>.from(empState.employees);
                          final repNameLower = (client?.representativeName ?? '').toLowerCase().trim();
                          final empProfile = allProfiles.firstWhereOrNull((e) => e.fullName.toLowerCase().trim() == repNameLower);

                          double empComm = opFees * 0.10;
                          double mgrComm = 0.0;
                          if (empProfile != null && empProfile.managerId != null) {
                            final manager = allProfiles.firstWhereOrNull((e) => e.id == empProfile.managerId);
                            if (manager != null && manager.role != 'admin') {
                              mgrComm = opFees * 0.05;
                            }
                          }
                          final double totalComm = empComm + mgrComm;
                          final double officeProfit = opFees - totalComm;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                                    Text("ربح المكتب: ${_fmt(officeProfit)} ج.م", style: TextStyle(fontWeight: FontWeight.bold, color: isCollected ? TfcColors.success : Colors.orangeAccent)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text("البنك: ${op.bankName} - ${op.programName}", style: const TextStyle(fontSize: 11, color: TfcColors.outline)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("الموظف: $repName", style: const TextStyle(fontSize: 11, color: TfcColors.outline)),
                                    Text("أتعاب: ${_fmt(opFees)} ج.م", style: const TextStyle(fontSize: 11, color: Colors.white30)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "عمولة موظف: ${_fmt(empComm)} ج.م${mgrComm > 0 ? '  |  عمولة إشراف: ${_fmt(mgrComm)} ج.م' : ''}",
                                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                                ),
                              ],
                            ),
                          );
                        }

                        // Manager/Employee view: show personal commission
                        bool isPersonal = cleanRepName == cleanUser || cleanRepName.contains(cleanUser) || cleanUser.contains(cleanRepName);
                        final double myComm = isPersonal ? (opFees * 0.10) : (opFees * 0.05);
                        final String commType = isPersonal 
                            ? "عمولة شخصية (10%)" 
                            : "عمولة إشراف (5%) - $repName";

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(clientName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                                  Text("${_fmt(myComm)} ج.م", style: TextStyle(fontWeight: FontWeight.bold, color: isCollected ? TfcColors.success : Colors.orangeAccent)),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("البنك: ${op.bankName} - ${op.programName}", style: const TextStyle(fontSize: 11, color: TfcColors.outline)),
                                  Text(commType, style: const TextStyle(fontSize: 11, color: TfcColors.outline)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (!isCollected) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.15)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.info_outline, size: 13, color: Colors.orangeAccent),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          "سبب عدم التحصيل: الفاتورة معلقة أو قيد المتابعة المالية ولم يقم العميل بسداد المستحقات بعد.",
                                          style: TextStyle(fontSize: 10, color: Colors.orangeAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                            },
                          ),
                        ),
                        // Show expenses summary for admin collected view
                        if (ref.read(authProvider).role == 'admin' && isCollected && _totalExpenses > 0) ...[
                          const Divider(color: Colors.white24, thickness: 1.5),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, size: 20, color: Colors.redAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("إجمالي المصاريف المخصومة (هذا الشهر)", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Text("- ${_fmt(_totalExpenses)} ج.م", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("إغلاق"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    final authState = ref.watch(authProvider);
    final bool isAdmin = authState.role == 'admin';
    final totalOpsCount = _myCollectedOps.length + _myUncollectedOps.length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              TfcColors.secondary.withValues(alpha: 0.08),
              Colors.cyan.withValues(alpha: 0.03),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TfcColors.secondary.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TfcColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet, color: TfcColors.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin ? "المحفظة المالية للمكتب (صافي الأرباح)" : "محفظتي المالية (العمولات المستحقة)",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: TfcColors.secondary),
                      ),
                      Text(
                        isAdmin
                            ? "تتبع صافي أرباح المكتب المتوقعة والمحصلة لشهر ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')} بعد خصم العمولات والمصاريف"
                            : "تتبع عمولاتك الشخصية المستحقة بناءً على فواتير العمليات (10% من قيمة الأتعاب)",
                        style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large Commission Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAdmin ? "صافي الأرباح الكلية المتوقعة" : "إجمالي العمولات المستحقة",
                      style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text("${_fmt(_totalCommission)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.white)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAdmin ? "إجمالي الفواتير النشطة: $totalOpsCount" : "إجمالي الفواتير: $totalOpsCount",
                    style: const TextStyle(color: TfcColors.outline, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),

            // Split Grid
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 500;
                return Flex(
                  direction: isMobile ? Axis.vertical : Axis.horizontal,
                  children: [
                    // Collected Panel
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: InkWell(
                        onTap: () => _showDetailsDialog(
                          title: isAdmin ? "تفاصيل أرباح العمليات المحصلة" : "تفاصيل الفواتير المحصلة",
                          ops: _myCollectedOps,
                          isCollected: true,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Tooltip(
                          message: isAdmin ? "انقر لعرض تفاصيل أرباح المعاملات المحصلة" : "انقر لعرض تفاصيل الفواتير المحصلة",
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: TfcColors.success.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: TfcColors.success.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, color: TfcColors.success, size: 28),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAdmin ? "صافي أرباح محصلة فعلياً" : "محصل",
                                        style: const TextStyle(color: TfcColors.outline, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("${_fmt(_collectedCommission)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.success)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: TfcColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!isMobile) const SizedBox(width: 16),
                    if (isMobile) const SizedBox(height: 12),
                    // Uncollected Panel
                    Expanded(
                      flex: isMobile ? 0 : 1,
                      child: InkWell(
                        onTap: () => _showDetailsDialog(
                          title: isAdmin ? "تفاصيل الأرباح غير المحصلة" : "تفاصيل الفواتير غير المحصلة",
                          ops: _myUncollectedOps,
                          isCollected: false,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        child: Tooltip(
                          message: isAdmin ? "انقر لعرض تفاصيل العمليات غير المحصلة بعد" : "انقر لعرض تفاصيل الفواتير غير المحصلة وأسباب المعاملة المعلقة",
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.hourglass_bottom, color: Colors.orangeAccent, size: 28),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAdmin ? "أرباح غير محصلة" : "غير محصل",
                                        style: const TextStyle(color: TfcColors.outline, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text("${_fmt(_uncollectedCommission)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orangeAccent)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: TfcColors.outline),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatusBreakdownWidget extends StatefulWidget {
  final List<ClientModel> visibleClients;
  final Function(String) onViewClient;

  const _DashboardStatusBreakdownWidget({
    required this.visibleClients,
    required this.onViewClient,
  });

  @override
  State<_DashboardStatusBreakdownWidget> createState() =>
      __DashboardStatusBreakdownWidgetState();
}

class __DashboardStatusBreakdownWidgetState
    extends State<_DashboardStatusBreakdownWidget> {
  static const Map<String, Map<String, dynamic>> _statusMeta = {
    'pending': {
      'label': 'قيد الانتظار',
      'icon': Icons.hourglass_empty,
      'color': Colors.amber,
    },
    'iscore_inquiry': {
      'label': 'استعلام أي سكور',
      'icon': Icons.search,
      'color': Colors.cyan,
    },
    'preparing_documents': {
      'label': 'تحضير الأوراق',
      'icon': Icons.folder_open,
      'color': Colors.blueAccent,
    },
    'under_review': {
      'label': 'قيد الدراسة والمراجعة',
      'icon': Icons.fact_check_outlined,
      'color': Colors.purpleAccent,
    },
    'at_bank': {
      'label': 'في البنك',
      'icon': Icons.account_balance,
      'color': Colors.orangeAccent,
    },
    'approved': {
      'label': 'موافق عليه',
      'icon': Icons.check_circle_outline,
      'color': TfcColors.success,
    },
    'rejected': {
      'label': 'مرفوض',
      'icon': Icons.cancel_outlined,
      'color': Colors.redAccent,
    },
  };

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.visibleClients.length;

    // Map each status to list of clients
    final Map<String, List<ClientModel>> statusClientsMap = {};
    for (var key in _statusMeta.keys) {
      statusClientsMap[key] = [];
    }
    for (var client in widget.visibleClients) {
      if (statusClientsMap.containsKey(client.status)) {
        statusClientsMap[client.status]!.add(client);
      } else {
        // Fallback for unexpected status string
        statusClientsMap['pending']?.add(client);
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 16,
      borderColor: TfcColors.primary.withValues(alpha: 0.15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.pie_chart_outline,
                      color: TfcColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "توزيع حالات الطلبات الحالية",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: TfcColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  "إجمالي الطلبات: $totalCount",
                  style: const TextStyle(
                    color: TfcColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final isTablet =
                  constraints.maxWidth >= 600 && constraints.maxWidth < 1000;
              final crossAxisCount = isMobile ? 2 : (isTablet ? 3 : 4);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: isMobile ? 8 : 12,
                  mainAxisSpacing: isMobile ? 8 : 12,
                  childAspectRatio: isMobile ? 1.6 : 2.2,
                ),
                itemCount: _statusMeta.keys.length,
                itemBuilder: (context, index) {
                  final statusKey = _statusMeta.keys.elementAt(index);
                  final meta = _statusMeta[statusKey]!;
                  final clients = statusClientsMap[statusKey] ?? [];
                  final count = clients.length;
                  final percentage = totalCount > 0
                      ? ((count / totalCount) * 100).toStringAsFixed(1)
                      : "0.0";
                  final Color color = meta['color'] as Color;

                  return InteractiveHoverCard(
                    onTap: () => _showStatusClientsDialog(
                      context,
                      meta['label'] as String,
                      color,
                      clients,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(meta['icon'] as IconData,
                                      color: color, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    meta['label'] as String,
                                    style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(Icons.touch_app_outlined,
                                  color: color.withValues(alpha: 0.5), size: 14),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Row(
                                textBaseline: TextBaseline.alphabetic,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                children: [
                                  Text(
                                    "$count",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    "طلب",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white60),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "%$percentage",
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showStatusClientsDialog(
    BuildContext context,
    String statusTitle,
    Color statusColor,
    List<ClientModel> clients,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxHeight: 600),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 16,
            borderColor: statusColor.withValues(alpha: 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "عملاء حالة: $statusTitle",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                if (clients.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        "لا يوجد عملاء حالياً في حالة ($statusTitle)",
                        style: const TextStyle(color: TfcColors.outline),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: clients.length,
                      separatorBuilder: (ctx, i) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, index) {
                        final client = clients[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          title: Text(
                            client.fullName,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            "الهاتف: ${client.phoneNumber} | المبلغ: ${client.requestedAmount.toStringAsFixed(0)} ج.م",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              color: TfcColors.outline,
                            ),
                          ),
                          leading: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 14,
                            color: TfcColors.primary,
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              client.representativeName ?? "غير محدد",
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white70),
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            widget.onViewClient(client.id);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


