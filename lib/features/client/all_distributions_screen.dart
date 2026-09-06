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
import 'operations_widget.dart';

class AllDistributionsScreen extends ConsumerStatefulWidget {
  final Function(String) onViewClient;
  final bool bankEmployeeMode;
  const AllDistributionsScreen({
    super.key,
    required this.onViewClient,
    this.bankEmployeeMode = false,
  });

  @override
  ConsumerState<AllDistributionsScreen> createState() => _AllDistributionsScreenState();
}

class _AllDistributionsScreenState extends ConsumerState<AllDistributionsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _distributions = [];
  
  // Tab Selection: 0 = النشطة (Active), 1 = المغلقة (Closed)
  int _selectedTab = 0;

  // Filters
  String _selectedBankFilter = 'all';
  String _selectedProgramFilter = 'all';
  String _selectedStatusFilter = 'all';

  final Map<String, String> _statusNames = {
    'all': 'كل الحالات',
    'pending': 'قيد الانتظار ⏳',
    'accepted': 'مقبول ✅',
    'rejected': 'مرفوض ❌',
    'closed': 'مغلق 🔒',
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
      final bool isBankEmployee = authState.role == 'bank_employee';
      final String bankEmployeeId = (authState.bankEmployeeId ?? '').trim();

      // Build query - filter server-side for bank_employee
      var query = SupabaseConfig.client
          .from('distribution_entries')
          .select('''
            id,
            program_id,
            bank_id,
            employee_id,
            status,
            is_closed,
            client_id,
            core_programs ( program_name ),
            banks ( bank_name ),
            bank_employees ( employee_name, phone_1, job_title ),
            clients ( full_name )
          ''');

      final userFullName = authState.fullName.trim().toLowerCase();
      final userBankName = (authState.bankName ?? '').trim().toLowerCase();
      final userId = authState.user?.id ?? '';

      final response = await query;

      final List<dynamic> rows = response as List<dynamic>;
      final List<Map<String, dynamic>> loaded = rows.map((r) {
        final clientData = r['clients'] as Map<String, dynamic>?;
        final bankData = r['banks'] as Map<String, dynamic>?;
        final programData = r['core_programs'] as Map<String, dynamic>?;
        final empData = r['bank_employees'] as Map<String, dynamic>?;
        final isClosed = r['is_closed'] == true || r['status'] == 'closed';
        var rowStatus = r['status']?.toString() ?? 'pending';
        if (rowStatus == 'closed') rowStatus = 'pending';

        return {
          'id': r['id'],
          'client_id': r['client_id'],
          'client_name': clientData != null ? clientData['full_name'] : 'عميل غير معروف',
          'program_name': programData != null ? programData['program_name'] : 'برنامج غير معروف',
          'program_id': r['program_id'],
          'bank_name': bankData != null ? bankData['bank_name'] : 'بنك غير معروف',
          'bank_id': r['bank_id'],
          'employee_id': r['employee_id'],
          'employee_name': empData != null
              ? (isUserAdmin
                  ? '${empData['employee_name']} ${empData['phone_1'] ?? ""}'.trim()
                  : ((empData['job_title'] != null && empData['job_title'].toString().trim().isNotEmpty)
                      ? '${empData['employee_name']} (${empData['job_title']})'.trim()
                      : '${empData['employee_name']}'.trim()))
              : 'لم يحدد بعد',
          'status': rowStatus,
          'is_closed': isClosed,
        };
      }).where((d) {
        if (!isBankEmployee) return true;
        // Bank employees should never see closed distributions
        if (d['is_closed'] == true) return false;

        final rowEmpId = (d['employee_id']?.toString() ?? '').trim();
        final rowEmpName = (d['employee_name']?.toString() ?? '').trim().toLowerCase();

        final matchesEmpId = (bankEmployeeId.isNotEmpty && rowEmpId == bankEmployeeId) || (userId.isNotEmpty && rowEmpId == userId);
        final matchesEmpName = userFullName.isNotEmpty && rowEmpName.isNotEmpty && (rowEmpName.contains(userFullName) || userFullName.contains(rowEmpName));

        return matchesEmpId || matchesEmpName;
      }).toList();

      if (mounted) {
        setState(() {
          _distributions = loaded;
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

  Future<void> _toggleDistributionClosed(String id, bool newClosedState) async {
    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client
            .from('distribution_entries')
            .update({'is_closed': newClosedState})
            .eq('id', id);
      }

      setState(() {
        final idx = _distributions.indexWhere((d) => d['id'] == id);
        if (idx != -1) {
          _distributions[idx]['is_closed'] = newClosedState;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newClosedState ? "تم إغلاق التوزيع بنجاح 🔒" : "تمت إعادة فتح التوزيع بنجاح 🔓",
              textAlign: TextAlign.right,
            ),
            backgroundColor: newClosedState ? const Color(0xFFFFD700) : TfcColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء تغيير حالة الإغلاق: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  Future<void> _convertToOperation(Map<String, dynamic> d) async {
    final authState = ref.read(authProvider);
    final staffName = authState.fullName.isNotEmpty ? authState.fullName : 'موظف بنك';
    final amountCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: const Text("تحويل التوزيع إلى عملية", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
            content: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("العميل: ${d['client_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text("البرنامج: ${d['program_name']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Text("البنك: ${d['bank_name']}", style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "مبلغ العملية المطلوب (ج.م)",
                      hintText: "مثال: 200000",
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
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  Navigator.pop(ctx);
                  await OperationsWidget.addOperation(
                    clientId: d['client_id'],
                    bankName: d['bank_name'],
                    programName: d['program_name'],
                    employeeName: d['employee_name'],
                    requestedAmount: amt,
                    staffName: staffName,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("تم تحويل التوزيع إلى عملية بنجاح", textAlign: TextAlign.right),
                        backgroundColor: TfcColors.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("تأكيد التحويل", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestPhoneFromDistribution(Map<String, dynamic> d) async {
    final authState = ref.read(authProvider);
    final userId = authState.user?.id ?? authState.fullName;
    final userName = authState.fullName.isNotEmpty ? authState.fullName : 'موظف بنك';
    final bankName = authState.bankName ?? d['bank_name'] ?? 'البنك';

    try {
      if (SupabaseConfig.isInitialized) {
        await SupabaseConfig.client.from('phone_requests').insert({
          'client_id': d['client_id'],
          'requested_by_id': userId,
          'requested_by_name': userName,
          'bank_name': bankName,
          'status': 'pending',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم إرسال طلب إظهار رقم الهاتف إلى الإدارة بنجاح", textAlign: TextAlign.right),
            backgroundColor: TfcColors.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error requesting phone: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("حدث خطأ أثناء إرسال الطلب: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';
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

    // Separate into active vs closed datasets based on _selectedTab
    final isBankEmployee = authState.role == 'bank_employee';
    
    // Apply Filters locally
    final filtered = _distributions.where((d) {
      if (authState.role != 'admin' && !visibleClientIds.contains(d['client_id'])) {
        return false;
      }

      final isClosed = d['is_closed'] == true;
      
      // If user is Bank Employee: never see closed distributions
      if (isBankEmployee && isClosed) {
        return false;
      }

      // If user is Admin / Manager: filter by active vs closed tabs
      if (!isBankEmployee) {
        if (_selectedTab == 0 && isClosed) {
          return false; // Tab 0: Active only (pending, accepted, rejected)
        }
        if (_selectedTab == 1 && !isClosed) {
          return false; // Tab 1: Closed only
        }
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

    final int activeCount = _distributions.where((d) => d['is_closed'] != true && (authState.role == 'admin' || visibleClientIds.contains(d['client_id']))).length;
    final int closedCount = _distributions.where((d) => d['is_closed'] == true && (authState.role == 'admin' || visibleClientIds.contains(d['client_id']))).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              "توزيعات البنوك العامة",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 18 : 20),
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
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12.0 : 24.0,
              vertical: isMobile ? 12.0 : 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tabs Bar for Admin / Manager (Active vs Closed Distributions)
                if (isAdmin) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedTab = 0;
                          _selectedStatusFilter = 'all';
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? TfcColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.all_inclusive,
                                size: 18,
                                color: _selectedTab == 0 ? Colors.black : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "التوزيعات النشطة ($activeCount)",
                                style: TextStyle(
                                  color: _selectedTab == 0 ? Colors.black : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedTab = 1;
                          _selectedStatusFilter = 'all';
                        }),
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.blueGrey : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: _selectedTab == 1 ? Colors.white : Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "توزيعات مغلقة ($closedCount)",
                                style: TextStyle(
                                  color: _selectedTab == 1 ? Colors.white : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
            ],

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
                      ? Center(
                          child: Text(
                            _selectedTab == 1
                                ? "لا توجد توزيعات مغلقة حالياً 🔒"
                                : "لا توجد توزيعات مطابقة للتصفية المحددة.",
                            style: const TextStyle(color: TfcColors.outline, fontSize: 14),
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
  },
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

  Map<String, List<Map<String, dynamic>>> _groupByClient(List<Map<String, dynamic>> data) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var d in data) {
      final clientId = d['client_id']?.toString() ?? 'unknown';
      grouped.putIfAbsent(clientId, () => []).add(d);
    }
    return grouped;
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data, bool isAdmin) {
    final authState = ref.read(authProvider);
    final grouped = _groupByClient(data);

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final clientId = grouped.keys.elementAt(index);
        final clientDists = grouped[clientId]!;
        final clientName = clientDists.first['client_name'] ?? 'عميل غير معروف';

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: GlassCard(
            padding: EdgeInsets.zero,
            borderColor: Colors.white.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Client Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: TfcColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: TfcColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () => widget.onViewClient(clientId),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                clientName,
                                style: const TextStyle(
                                  color: TfcColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new, color: TfcColors.primary, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: TfcColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: TfcColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance, size: 14, color: TfcColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              "موزع على ${clientDists.length} ${clientDists.length == 1 ? 'بنك' : 'بنوك'}",
                              style: const TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Assigned Banks Table ──
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 28,
                    headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.02)),
                    dataRowMaxHeight: 65,
                    columns: const [
                      DataColumn(label: Text("البنك الموزع عليه", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      DataColumn(label: Text("البرنامج الائتماني", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      DataColumn(label: Text("الموظف المسؤول", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      DataColumn(label: Text("الحالة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      DataColumn(label: Text("التحكم / الإجراء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    ],
                    rows: clientDists.map((d) {
                      final status = d['status'] as String? ?? 'pending';
                      final statusColor = _getStatusColor(status);

                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.account_balance, size: 16, color: statusColor),
                                const SizedBox(width: 8),
                                Text(
                                  d['bank_name'] ?? 'بنك غير معروف',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(d['program_name'] ?? '—', style: const TextStyle(fontSize: 13))),
                          DataCell(Text(d['employee_name'] ?? '—', style: const TextStyle(fontSize: 13))),
                          DataCell(_buildStatusChip(status, isClosed: d['is_closed'] == true)),
                          DataCell(
                            (isAdmin || authState.role == 'bank_employee')
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildStatusActionsDropdown(d['id'], d['status'], d['is_closed'] == true),
                                      if (d['status'] == 'accepted') ...[
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _convertToOperation(d),
                                          icon: const Icon(Icons.settings_suggest, size: 12),
                                          label: const Text("تحويل لعملية", style: TextStyle(fontSize: 11)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton.icon(
                                          onPressed: () => _requestPhoneFromDistribution(d),
                                          icon: const Icon(Icons.phone_android, size: 12),
                                          label: const Text("طلب الرقم", style: TextStyle(fontSize: 11)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.greenAccent,
                                            side: const BorderSide(color: Colors.greenAccent, width: 0.8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            minimumSize: Size.zero,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                : const Text("—", style: TextStyle(color: TfcColors.outline)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCards(List<Map<String, dynamic>> data, bool isAdmin) {
    final authState = ref.read(authProvider);
    final grouped = _groupByClient(data);

    return ListView.builder(
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final clientId = grouped.keys.elementAt(index);
        final clientDists = grouped[clientId]!;
        final clientName = clientDists.first['client_name'] ?? 'عميل غير معروف';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: GlassCard(
            padding: EdgeInsets.zero,
            borderColor: Colors.white.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Client Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => widget.onViewClient(clientId),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: TfcColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  clientName,
                                  style: const TextStyle(
                                    color: TfcColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.open_in_new, color: TfcColors.primary, size: 14),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: TfcColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TfcColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          "${clientDists.length} ${clientDists.length == 1 ? 'بنك' : 'بنوك'}",
                          style: const TextStyle(color: TfcColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Sub-cards for Each Bank ──
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: clientDists.map((d) {
                      final status = d['status'] as String? ?? 'pending';
                      final statusColor = _getStatusColor(status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Bank Name (Colored by status) & Status Chip
                            Row(
                              textDirection: TextDirection.rtl,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Icon(Icons.account_balance, color: statusColor, size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          d['bank_name'] ?? 'بنك غير معروف',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                          textDirection: TextDirection.rtl,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildStatusChip(status, isClosed: d['is_closed'] == true),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildInfoRow("البرنامج", d['program_name'] ?? '—', Icons.category),
                            _buildInfoRow("الموظف", d['employee_name'] ?? '—', Icons.person),

                            if (isAdmin || authState.role == 'bank_employee') ...[
                              const SizedBox(height: 8),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 6),
                              Row(
                                textDirection: TextDirection.rtl,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "تغيير الحالة:",
                                    style: TextStyle(color: TfcColors.outline, fontSize: 12),
                                  ),
                                  _buildStatusActionsDropdown(d['id'], d['status'], d['is_closed'] == true),
                                ],
                              ),
                              if (d['status'] == 'accepted') ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.end,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _convertToOperation(d),
                                      icon: const Icon(Icons.settings_suggest, size: 12),
                                      label: const Text("تحويل لعملية", style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _requestPhoneFromDistribution(d),
                                      icon: const Icon(Icons.phone_android, size: 12),
                                      label: const Text("طلب الرقم", style: TextStyle(fontSize: 11)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.greenAccent,
                                        side: const BorderSide(color: Colors.greenAccent, width: 0.8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
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

  Widget _buildStatusChip(String status, {bool isClosed = false}) {
    final color = _getStatusColor(status);
    final text = _statusNames[status] ?? status;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
        ),
        if (isClosed) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 10, color: Color(0xFFFFD700)),
                SizedBox(width: 4),
                Text(
                  "مغلق",
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
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
        return const Color(0xFF64B5F6); // بيبي بلو (Baby Blue)
    }
  }

  Widget _buildStatusActionsDropdown(String id, String currentStatus, bool isClosed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonHideUnderline(
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
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: isClosed ? "إلغاء الإغلاق (إعادة فتح)" : "إغلاق التوزيع",
          icon: Icon(
            isClosed ? Icons.lock : Icons.lock_open,
            color: isClosed ? const Color(0xFFFFD700) : Colors.white38,
            size: 16,
          ),
          onPressed: () => _toggleDistributionClosed(id, !isClosed),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
