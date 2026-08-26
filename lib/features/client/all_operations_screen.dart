import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import '../../core/utils/client_visibility_helper.dart';
import '../../core/widgets/toggleable_filter_panel.dart';
import '../../core/widgets/interactive_hover_card.dart';

class AllOperationsScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;
  final bool bankEmployeeMode;
  const AllOperationsScreen({
    super.key,
    required this.onViewClient,
    this.bankEmployeeMode = false,
  });

  @override
  ConsumerState<AllOperationsScreen> createState() => _AllOperationsScreenState();
}

class _AllOperationsScreenState extends ConsumerState<AllOperationsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _operations = [];

  // Filters
  String _selectedBankFilter = 'all';
  String _selectedEmployeeFilter = 'all';
  String _selectedStatusFilter = 'all';

  final Map<String, String> _statusNames = {
    'all': 'كل الحالات',
    'working': 'يتم العمل ⚙️',
    'approved': 'موافقة ✅',
    'rejected': 'رفض ❌',
  };

  @override
  void initState() {
    super.initState();
    _loadAllOperations();
  }

  Future<void> _loadAllOperations() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!SupabaseConfig.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() {
          _operations = [
            {
              'id': 'mock-op-1',
              'client_id': 'mock-client-1',
              'client_name': 'عميل تجريبي',
              'bank_name': 'البنك الأهلي',
              'program_name': 'برنامج تمويل شخصي',
              'employee_name': 'محمد أحمد',
              'requested_amount': 500000.0,
              'status': 'working',
              'transfer_date': DateTime.now().toIso8601String(),
              'approval_date': null,
              'approved_amount': null,
            },
          ];
          _isLoading = false;
        });
        return;
      }

      final authState = ref.read(authProvider);
      final bool isUserAdmin = authState.role == 'admin';
      final bool isBankEmployee = authState.role == 'bank_employee';
      final String empName = authState.fullName.trim();

      // Build query - filter server-side by employee_name for bank_employee
      var query = SupabaseConfig.client
          .from('operation_entries')
          .select('''
            id,
            client_id,
            bank_name,
            program_name,
            employee_name,
            requested_amount,
            status,
            transfer_date,
            approval_date,
            approved_amount,
            clients ( full_name )
          ''');

      final response = await query;

      final List<dynamic> rows = response as List<dynamic>;
      final List<Map<String, dynamic>> loaded = rows.map((r) {
        final clientData = r['clients'] as Map<String, dynamic>?;
        final rawEmpName = r['employee_name'] ?? 'لم يحدد';
        final cleanEmpName = isUserAdmin
            ? rawEmpName
            : rawEmpName.toString().replaceAll(RegExp(r'[-–—\s]*\b0\d{8,12}\b'), '').trim();

        return {
          'id': r['id'],
          'client_id': r['client_id'],
          'client_name': clientData != null ? clientData['full_name'] : 'عميل غير معروف',
          'bank_name': r['bank_name'] ?? 'بنك غير معروف',
          'program_name': r['program_name'] ?? 'برنامج غير معروف',
          'employee_name': cleanEmpName,
          'requested_amount': (r['requested_amount'] as num?)?.toDouble() ?? 0.0,
          'status': r['status'] ?? 'working',
          'transfer_date': r['transfer_date'],
          'approval_date': r['approval_date'],
          'approved_amount': (r['approved_amount'] as num?)?.toDouble(),
        };
      }).where((op) {
        if (!isBankEmployee) return true;
        final opEmp = (op['employee_name']?.toString() ?? '').trim().toLowerCase();
        final opBank = (op['bank_name']?.toString() ?? '').trim().toLowerCase();
        final userBank = (authState.bankName ?? '').trim().toLowerCase();
        final userFull = authState.fullName.trim().toLowerCase();

        final matchesEmp = userFull.isNotEmpty && opEmp.isNotEmpty && (opEmp.contains(userFull) || userFull.contains(opEmp));
        final matchesBank = userBank.isNotEmpty && opBank.contains(userBank);

        return matchesEmp || matchesBank;
      }).toList();

      if (mounted) {
        setState(() {
          _operations = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading all operations: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ في تحميل العمليات: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateOperationStatus(String id, String newStatus) async {
    try {
      final Map<String, dynamic> updates = {'status': newStatus};
      if (newStatus == 'approved' || newStatus == 'rejected') {
        updates['approval_date'] = DateTime.now().toIso8601String();
      }
      if (newStatus == 'working') {
        updates['approval_date'] = null;
        updates['approved_amount'] = null;
      }

      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('operation_entries')
            .update(updates)
            .eq('id', id);
      }

      setState(() {
        final idx = _operations.indexWhere((d) => d['id'] == id);
        if (idx != -1) {
          _operations[idx]['status'] = newStatus;
          if (newStatus == 'approved' || newStatus == 'rejected') {
            _operations[idx]['approval_date'] = DateTime.now().toIso8601String();
          }
          if (newStatus == 'working') {
            _operations[idx]['approval_date'] = null;
            _operations[idx]['approved_amount'] = null;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث حالة العملية بنجاح", textAlign: TextAlign.right),
            backgroundColor: TfcColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء التحديث: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  String _formatNumber(double n) {
    if (n == n.truncateToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isStrictAdmin = authState.role == 'admin';
    final clientState = ref.watch(clientProvider);
    final employeesState = ref.watch(employeesProvider);
    final visibleClients = ClientVisibilityHelper.filterClients(
      clients: clientState.clients,
      authState: authState,
      allEmployees: employeesState.employees,
    );
    final allowedClientIds = visibleClients.map((c) => c.id).toSet();

    // Collect unique banks and employees for filter dropdowns
    final uniqueBanks = <String, String>{};
    final uniqueEmployees = <String, String>{};
    for (var op in _operations) {
      if (allowedClientIds.contains(op['client_id'])) {
        final bankName = op['bank_name'] as String? ?? '';
        if (bankName.isNotEmpty) uniqueBanks[bankName] = bankName;
        final empName = op['employee_name'] as String? ?? '';
        if (empName.isNotEmpty) uniqueEmployees[empName] = empName;
      }
    }

    // Apply Filters and Client Visibility restrictions
    final filtered = _operations.where((d) {
      if (!allowedClientIds.contains(d['client_id'])) {
        return false;
      }
      if (_selectedBankFilter != 'all' && d['bank_name'] != _selectedBankFilter) {
        return false;
      }
      if (_selectedEmployeeFilter != 'all' && d['employee_name'] != _selectedEmployeeFilter) {
        return false;
      }
      if (_selectedStatusFilter != 'all' && d['status'] != _selectedStatusFilter) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "العمليات العامة",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: TfcColors.primary),
            onPressed: _loadAllOperations,
            tooltip: "تحديث البيانات",
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filters Card
            ToggleableFilterPanel(
              title: "تصفية وتصفح العمليات 🔍",
              activeFilterCount: (_selectedBankFilter != 'all' ? 1 : 0) +
                  (_selectedEmployeeFilter != 'all' ? 1 : 0) +
                  (_selectedStatusFilter != 'all' ? 1 : 0),
              onResetFilter: () {
                setState(() {
                  _selectedBankFilter = 'all';
                  _selectedEmployeeFilter = 'all';
                  _selectedStatusFilter = 'all';
                });
              },
              filterContent: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final children = [
                    // Bank Filter
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildFilterDropdown(
                        value: _selectedBankFilter,
                        hint: "كل البنوك",
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text("كل البنوك", textDirection: TextDirection.rtl)),
                          ...uniqueBanks.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, textDirection: TextDirection.rtl),
                              ))
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedBankFilter = val);
                        },
                      ),
                    ),
                    if (!isWide) const SizedBox(height: 12),
                    if (isWide) const SizedBox(width: 12),

                    // Employee Filter
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildFilterDropdown(
                        value: _selectedEmployeeFilter,
                        hint: "كل المندوبين",
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text("كل المندوبين", textDirection: TextDirection.rtl)),
                          ...uniqueEmployees.entries.map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value, textDirection: TextDirection.rtl),
                              ))
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedEmployeeFilter = val);
                        },
                      ),
                    ),
                    if (!isWide) const SizedBox(height: 12),
                    if (isWide) const SizedBox(width: 12),

                    // Status Filter
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: _buildFilterDropdown(
                        value: _selectedStatusFilter,
                        hint: "كل الحالات",
                        items: _statusNames.entries
                            .map((e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value, textDirection: TextDirection.rtl),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatusFilter = val);
                        },
                      ),
                    ),
                  ];

                  return isWide
                      ? Row(textDirection: TextDirection.rtl, children: children)
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
                },
              ),
            ),
            const SizedBox(height: 20),

            // Operations List/Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: TfcColors.primary))
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_turned_in_outlined,
                                  color: TfcColors.outline.withValues(alpha: 0.3), size: 48),
                              const SizedBox(height: 12),
                              const Text(
                                "لا توجد عمليات مطابقة للتصفية المحددة.",
                                style: TextStyle(color: TfcColors.outline, fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 1024;
                            if (isDesktop) {
                              return _buildDesktopTable(filtered, isStrictAdmin);
                            }
                            return _buildMobileCards(filtered, isStrictAdmin);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: TfcColors.surfaceDim,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data, bool isAdmin) {
    final authState = ref.read(authProvider);
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.white.withValues(alpha: 0.03),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 20,
            headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)),
            dataRowMaxHeight: 60,
            columns: const [
              DataColumn(label: Text("العميل", style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary))),
              DataColumn(label: Text("البنك", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("البرنامج", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("المندوب", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("المبلغ المطلوب", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("تاريخ التحويل", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("الحالة", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("مبلغ الموافقة", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("الإجراء", style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: data.map((d) {
              return DataRow(
                cells: [
                  DataCell(
                    InkWell(
                      onTap: () => widget.onViewClient(d['client_id']),
                      child: Text(
                        d['client_name'],
                        style: const TextStyle(
                          color: TfcColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  DataCell(Text(d['bank_name'])),
                  DataCell(Text(d['program_name'])),
                  DataCell(Text(d['employee_name'])),
                  DataCell(Text("${_formatNumber(d['requested_amount'])} ج.م")),
                  DataCell(Text(_formatDate(d['transfer_date']))),
                  DataCell(_buildStatusChip(d['status'])),
                  DataCell(Text(
                    d['approved_amount'] != null
                        ? "${_formatNumber(d['approved_amount'])} ج.م"
                        : "—",
                  )),
                  DataCell(
                    (isAdmin || authState.role == 'bank_employee')
                        ? _buildStatusActionsDropdown(d['id'], d['status'])
                        : const Text("—", style: TextStyle(color: TfcColors.outline)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<Map<String, dynamic>> data, bool isAdmin) {
    final authState = ref.read(authProvider);
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final d = data[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            borderColor: _getStatusColor(d['status']).withValues(alpha: 0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => widget.onViewClient(d['client_id']),
                        child: Text(
                          d['client_name'],
                          style: const TextStyle(
                            color: TfcColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    _buildStatusChip(d['status']),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow("البنك", d['bank_name'], Icons.account_balance),
                _buildInfoRow("البرنامج", d['program_name'], Icons.category),
                _buildInfoRow("المندوب", d['employee_name'], Icons.person),
                _buildInfoRow("المبلغ المطلوب", "${_formatNumber(d['requested_amount'])} ج.م", Icons.monetization_on),
                _buildInfoRow("تاريخ التحويل", _formatDate(d['transfer_date']), Icons.calendar_today),
                if (d['approved_amount'] != null)
                  _buildInfoRow("مبلغ الموافقة", "${_formatNumber(d['approved_amount'])} ج.م", Icons.check_circle_outline),
                if (d['approval_date'] != null)
                  _buildInfoRow(
                    d['status'] == 'rejected' ? "تاريخ الرفض" : "تاريخ الموافقة",
                    _formatDate(d['approval_date']),
                    Icons.event_available,
                  ),
                if (isAdmin || authState.role == 'bank_employee') ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "تغيير الحالة:",
                        style: TextStyle(color: TfcColors.outline, fontSize: 13),
                      ),
                      SizedBox(
                        width: 150,
                        child: _buildStatusActionsDropdown(d['id'], d['status']),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 14, color: TfcColors.outline),
          const SizedBox(width: 6),
          Text("$label: ", style: const TextStyle(color: TfcColors.outline, fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    final text = _statusNames[status] ?? status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
        return TfcColors.success;
      case 'rejected':
        return TfcColors.error;
      case 'working':
      default:
        return Colors.blueAccent;
    }
  }

  Widget _buildStatusActionsDropdown(String id, String currentStatus) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: currentStatus,
        dropdownColor: TfcColors.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        icon: const Icon(Icons.edit, size: 14, color: TfcColors.primary),
        items: const [
          DropdownMenuItem(value: 'working', child: Text("يتم العمل ⚙️", textDirection: TextDirection.rtl)),
          DropdownMenuItem(value: 'approved', child: Text("موافقة ✅", textDirection: TextDirection.rtl)),
          DropdownMenuItem(value: 'rejected', child: Text("رفض ❌", textDirection: TextDirection.rtl)),
        ],
        onChanged: (val) {
          if (val != null && val != currentStatus) {
            _updateOperationStatus(id, val);
          }
        },
      ),
    );
  }
}
