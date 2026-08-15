import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/banks_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import '../../core/utils/client_visibility_helper.dart';
import '../../core/widgets/toggleable_filter_panel.dart';
import '../../core/widgets/interactive_hover_card.dart';

class AllDistributionsScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;
  const AllDistributionsScreen({super.key, required this.onViewClient});

  @override
  ConsumerState<AllDistributionsScreen> createState() => _AllDistributionsScreenState();
}

class _AllDistributionsScreenState extends ConsumerState<AllDistributionsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _distributions = [];
  
  // Filters
  String _selectedBankFilter = 'all';
  String _selectedProgramFilter = 'all';
  String _selectedStatusFilter = 'all';

  final Map<String, String> _statusNames = {
    'all': 'كل الحالات',
    'pending': 'قيد الانتظار ⏳',
    'accepted': 'مقبول ✅',
    'rejected': 'مرفوض ❌',
  };

  @override
  void initState() {
    super.initState();
    _loadAllDistributions();
  }

  Future<void> _loadAllDistributions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (!SupabaseConfig.isInitialized) {
        // Simulation fallback
        await Future.delayed(const Duration(milliseconds: 600));
        setState(() {
          _distributions = [
            {
              'id': 'mock-dist-1',
              'client_id': 'mock-client-1',
              'client_name': 'أحمد محمد علي',
              'program_name': 'برنامج تمويل شخصي',
              'program_id': 'mock-prog-1',
              'bank_name': 'البنك الأهلي',
              'bank_id': 'mock-bank-1',
              'employee_name': 'محمد أحمد (موظف البنك)',
              'status': 'pending',
            },
            {
              'id': 'mock-dist-2',
              'client_id': 'mock-client-2',
              'client_name': 'سارة عبد الله',
              'program_name': 'برنامج التمويل العقاري',
              'program_id': 'mock-prog-2',
              'bank_name': 'بنك الراجحي',
              'bank_id': 'mock-bank-2',
              'employee_name': 'خالد علي',
              'status': 'accepted',
            }
          ];
          _isLoading = false;
        });
        return;
      }

      final authState = ref.read(authProvider);
      final bool isUserAdmin = authState.role == 'admin';

      final response = await SupabaseConfig.client
          .from('distribution_entries')
          .select('''
            id,
            program_id,
            bank_id,
            employee_id,
            status,
            client_id,
            core_programs ( program_name ),
            banks ( bank_name ),
            bank_employees ( employee_name, phone_1 ),
            clients ( full_name )
          ''');

      final List<dynamic> rows = response as List<dynamic>;
      final List<Map<String, dynamic>> loaded = rows.map((r) {
        final clientData = r['clients'] as Map<String, dynamic>?;
        final bankData = r['banks'] as Map<String, dynamic>?;
        final programData = r['core_programs'] as Map<String, dynamic>?;
        final empData = r['bank_employees'] as Map<String, dynamic>?;

        return {
          'id': r['id'],
          'client_id': r['client_id'],
          'client_name': clientData != null ? clientData['full_name'] : 'عميل غير معروف',
          'program_name': programData != null ? programData['program_name'] : 'برنامج غير معروف',
          'program_id': r['program_id'],
          'bank_name': bankData != null ? bankData['bank_name'] : 'بنك غير معروف',
          'bank_id': r['bank_id'],
          'employee_name': empData != null
              ? (isUserAdmin
                  ? '${empData['employee_name']} ${empData['phone_1'] ?? ""}'.trim()
                  : '${empData['employee_name']}'.trim())
              : 'لم يحدد بعد',
          'status': r['status'] ?? 'pending',
        };
      }).toList();

      if (mounted) {
        // If user is a Bank Employee, isolate distributions to their specific bank
        List<Map<String, dynamic>> finalDistributions = loaded;
        if (authState.role == 'bank_employee') {
          final userBank = authState.bankName ?? '';
          if (userBank.isNotEmpty) {
            finalDistributions = loaded.where((d) {
              final bName = (d['bank_name'] ?? '').toString();
              return bName.contains(userBank) || userBank.contains(bName);
            }).toList();
          }
        }

        setState(() {
          _distributions = finalDistributions;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading all distributions: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ في تحميل التوزيعات: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateDistributionStatus(String id, String newStatus) async {
    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('distribution_entries')
            .update({'status': newStatus})
            .eq('id', id);
      }
      
      setState(() {
        final idx = _distributions.indexWhere((d) => d['id'] == id);
        if (idx != -1) {
          _distributions[idx]['status'] = newStatus;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث حالة التوزيع بنجاح", textAlign: TextAlign.right),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin' || authState.role == 'manager';
    final banksAsync = ref.watch(allBanksProvider);
    final programsAsync = ref.watch(coreProgramsProvider);

    final clientState = ref.watch(clientProvider);
    final employeesState = ref.watch(employeesProvider);
    final visibleClients = ClientVisibilityHelper.filterClients(
      clients: clientState.clients,
      authState: authState,
      allEmployees: employeesState.employees,
    );
    final visibleClientIds = visibleClients.map((c) => c.id).toSet();

    // Apply Filters locally
    final filtered = _distributions.where((d) {
      if (authState.role != 'admin' && !visibleClientIds.contains(d['client_id'])) {
        return false;
      }
      if (_selectedBankFilter != 'all' && d['bank_id'] != _selectedBankFilter) {
        return false;
      }
      if (_selectedProgramFilter != 'all' && d['program_id'] != _selectedProgramFilter) {
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
          "توزيعات البنوك العامة",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: TfcColors.primary),
            onPressed: _loadAllDistributions,
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
              title: "تصفية وتصفح التوزيعات 🔍",
              activeFilterCount: (_selectedBankFilter != 'all' ? 1 : 0) +
                  (_selectedProgramFilter != 'all' ? 1 : 0) +
                  (_selectedStatusFilter != 'all' ? 1 : 0),
              onResetFilter: () {
                setState(() {
                  _selectedBankFilter = 'all';
                  _selectedProgramFilter = 'all';
                  _selectedStatusFilter = 'all';
                });
              },
              filterContent: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 600;
                  final children = [
                    // Bank Filter - only banks present in distributions
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Builder(
                        builder: (context) {
                          // Extract unique banks from actual distributions data
                          final uniqueBanks = <String, String>{};
                          for (final d in _distributions) {
                            final bankId = d['bank_id']?.toString() ?? '';
                            final bankName = d['bank_name']?.toString() ?? '';
                            if (bankId.isNotEmpty && bankName.isNotEmpty) {
                              uniqueBanks[bankId] = bankName;
                            }
                          }
                          // Reset filter if selected bank no longer exists in data
                          if (_selectedBankFilter != 'all' && !uniqueBanks.containsKey(_selectedBankFilter)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedBankFilter = 'all');
                            });
                          }
                          return _buildFilterDropdown(
                            value: uniqueBanks.containsKey(_selectedBankFilter) || _selectedBankFilter == 'all'
                                ? _selectedBankFilter
                                : 'all',
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
                          );
                        },
                      ),
                    ),
                    if (!isWide) const SizedBox(height: 12),
                    if (isWide) const SizedBox(width: 12),

                    // Program Filter - only programs present in distributions
                    Expanded(
                      flex: isWide ? 1 : 0,
                      child: Builder(
                        builder: (context) {
                          // Extract unique programs from actual distributions data
                          final uniquePrograms = <String, String>{};
                          for (final d in _distributions) {
                            final progId = d['program_id']?.toString() ?? '';
                            final progName = d['program_name']?.toString() ?? '';
                            if (progId.isNotEmpty && progName.isNotEmpty) {
                              uniquePrograms[progId] = progName;
                            }
                          }
                          // Reset filter if selected program no longer exists in data
                          if (_selectedProgramFilter != 'all' && !uniquePrograms.containsKey(_selectedProgramFilter)) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _selectedProgramFilter = 'all');
                            });
                          }
                          return _buildFilterDropdown(
                            value: uniquePrograms.containsKey(_selectedProgramFilter) || _selectedProgramFilter == 'all'
                                ? _selectedProgramFilter
                                : 'all',
                            hint: "كل البرامج",
                            items: [
                              const DropdownMenuItem(value: 'all', child: Text("كل البرامج", textDirection: TextDirection.rtl)),
                              ...uniquePrograms.entries.map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value, textDirection: TextDirection.rtl),
                                  ))
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedProgramFilter = val);
                            },
                          );
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

            // Distributions List/Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: TfcColors.primary))
                  : filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "لا توجد توزيعات مطابقة للتصفية المحددة.",
                            style: TextStyle(color: TfcColors.outline, fontSize: 14),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final isDesktop = constraints.maxWidth >= 1024;
                            if (isDesktop) {
                              return _buildDesktopTable(filtered, isAdmin);
                            }
                            return _buildMobileCards(filtered, isAdmin);
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.white.withValues(alpha: 0.03),
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            horizontalMargin: 12,
            columnSpacing: 24,
            headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)),
            dataRowMaxHeight: 60,
            columns: const [
              DataColumn(label: Text("العميل", style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary))),
              DataColumn(label: Text("البرنامج الائتماني", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("البنك الموزع عليه", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("الموظف المسؤول", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("الحالة", style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text("التحكم / الإجراء", style: TextStyle(fontWeight: FontWeight.bold))),
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
                  DataCell(Text(d['program_name'])),
                  DataCell(Text(d['bank_name'])),
                  DataCell(Text(d['employee_name'])),
                  DataCell(_buildStatusChip(d['status'])),
                  DataCell(
                    isAdmin
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
                    InkWell(
                      onTap: () => widget.onViewClient(d['client_id']),
                      child: Text(
                        d['client_name'],
                        style: const TextStyle(
                          color: TfcColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    _buildStatusChip(d['status']),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow("البرنامج", d['program_name'], Icons.category),
                _buildInfoRow("البنك", d['bank_name'], Icons.account_balance),
                _buildInfoRow("الموظف", d['employee_name'], Icons.person),
                if (isAdmin) ...[
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
      case 'accepted':
        return TfcColors.success;
      case 'rejected':
        return TfcColors.error;
      case 'pending':
      default:
        return TfcColors.warning;
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
          DropdownMenuItem(value: 'pending', child: Text("قيد الانتظار ⏳", textDirection: TextDirection.rtl)),
          DropdownMenuItem(value: 'accepted', child: Text("مقبول ✅", textDirection: TextDirection.rtl)),
          DropdownMenuItem(value: 'rejected', child: Text("مرفوض ❌", textDirection: TextDirection.rtl)),
        ],
        onChanged: (val) {
          if (val != null && val != currentStatus) {
            _updateDistributionStatus(id, val);
          }
        },
      ),
    );
  }
}
