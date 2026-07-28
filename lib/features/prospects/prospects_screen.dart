import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/prospect_model.dart';
import '../../models/client_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/prospects_provider.dart';
import '../../providers/employees_provider.dart';
import '../../core/widgets/toggleable_filter_panel.dart';
import '../../core/widgets/interactive_hover_card.dart';
import '../../core/widgets/phone_action_widget.dart';
import '../../providers/client_provider.dart';
import '../../core/utils/client_visibility_helper.dart';

class ProspectsScreen extends ConsumerStatefulWidget {
  final Function(String clientId)? onNavigateToClientDetails;

  const ProspectsScreen({
    super.key,
    this.onNavigateToClientDetails,
  });

  @override
  ConsumerState<ProspectsScreen> createState() => _ProspectsScreenState();
}

class _ProspectsScreenState extends ConsumerState<ProspectsScreen> {
  final Set<String> _selectedProspectIds = {};
  String _searchQuery = "";
  String _selectedStatusFilter = 'all';
  String _selectedEmployeeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final prospectsState = ref.watch(prospectsProvider);
    final authState = ref.watch(authProvider);
    final employeesState = ref.watch(employeesProvider);
    final isAdmin = authState.role == 'admin';
    final currentUserEmail = authState.user?.email ?? '';
    final currentUserName = authState.fullName;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Title & Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'العملاء المحتملين',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAdmin
                            ? 'إدارة العملاء الجدد المكتسبين وتوزيعهم على الموظفين ومتابعة تحويلهم'
                            : 'قائمة العملاء المحتملين المسندين إليك للمتابعة والتحويل',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Sync button from Google Sheets
                      ElevatedButton.icon(
                        onPressed: () => _handleSyncFromGoogleSheets(context),
                        icon: const Icon(Icons.sync_rounded, size: 18),
                        label: const Text('مزامنة من جوجل شيت'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TfcColors.primary.withValues(alpha: 0.2),
                          foregroundColor: TfcColors.primary,
                          side: const BorderSide(color: TfcColors.primary),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Add Manual Prospect
                      ElevatedButton.icon(
                        onPressed: () => _showAddOrEditProspectDialog(context),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('إضافة عميل محتمل'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TfcColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Filter Bar & Bulk Actions
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ToggleableFilterPanel(
                      title: "تصفية وتصفح العملاء المحتملين 🔍",
                      activeFilterCount: (_searchQuery.isNotEmpty ? 1 : 0) +
                          (_selectedStatusFilter != 'all' ? 1 : 0) +
                          (_selectedEmployeeFilter != 'all' ? 1 : 0),
                      onResetFilter: () {
                        setState(() {
                          _searchQuery = '';
                          _selectedStatusFilter = 'all';
                          _selectedEmployeeFilter = 'all';
                        });
                      },
                      filterContent: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 600;
                          final children = [
                            // Search Field
                            Expanded(
                              flex: isWide ? 3 : 0,
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'بحث بالاسم، الهاتف، الشركة...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                                  prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                                  filled: true,
                                  fillColor: Colors.black.withValues(alpha: 0.2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ),
                            if (!isWide) const SizedBox(height: 12),
                            if (isWide) const SizedBox(width: 12),

                            // Filter by Status
                            Expanded(
                              flex: isWide ? 2 : 0,
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedStatusFilter,
                                dropdownColor: const Color(0xFF1E2430),
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'الحالة',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                  filled: true,
                                  fillColor: Colors.black.withValues(alpha: 0.2),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'all', child: Text('جميع الحالات')),
                                  DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                                  DropdownMenuItem(value: 'contacted', child: Text('تم التواصل')),
                                  DropdownMenuItem(value: 'converted', child: Text('تم التحويل لعميل')),
                                  DropdownMenuItem(value: 'rejected', child: Text('مرفوض / غير مهتم')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedStatusFilter = val);
                                },
                              ),
                            ),
                            if (!isWide && isAdmin) const SizedBox(height: 12),
                            if (isWide && isAdmin) const SizedBox(width: 12),

                            // Filter by Employee (Admin Only)
                            if (isAdmin)
                              Expanded(
                                flex: isWide ? 2 : 0,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedEmployeeFilter,
                                  dropdownColor: const Color(0xFF1E2430),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'الموظف المسند إليه',
                                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                                    filled: true,
                                    fillColor: Colors.black.withValues(alpha: 0.2),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    const DropdownMenuItem(value: 'all', child: Text('كل الموظفين')),
                                    const DropdownMenuItem(value: 'unassigned', child: Text('غير مسند لموظف')),
                                    ...employeesState.employees
                                        .where((emp) => emp.role != 'bank_employee')
                                        .map((emp) => DropdownMenuItem(
                                              value: emp.id,
                                              child: Text(emp.fullName),
                                            )),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedEmployeeFilter = val);
                                  },
                                ),
                              ),
                          ];

                          return isWide
                              ? Row(children: children)
                              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
                        },
                      ),
                    ),

                    // Bulk Actions Bar if selection is active
                    if (_selectedProspectIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: TfcColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TfcColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تم تحديد ${_selectedProspectIds.length} عميل محتمل',
                              style: const TextStyle(
                                color: TfcColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _showBulkAssignDialog(context),
                                  icon: const Icon(Icons.assignment_ind, size: 16),
                                  label: const Text('توزيع على موظف'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TfcColors.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () => setState(() => _selectedProspectIds.clear()),
                                  child: const Text('إلغاء التحديد', style: TextStyle(color: Colors.white70)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Prospects Table List
              Expanded(
                child: prospectsState.when(
                  data: (prospects) {
                    // First filter prospects by role & manager hierarchy
                    final scopeFiltered = ClientVisibilityHelper.filterProspects(
                      prospects: prospects,
                      authState: authState,
                      allEmployees: employeesState.employees,
                    );

                    // Filter according to selected UI filters
                    final filtered = scopeFiltered.where((p) {
                      // Employee Filter (for Admin / Manager)
                      if (_selectedEmployeeFilter != 'all') {
                        if (_selectedEmployeeFilter == 'unassigned') {
                          if (p.assignedToId != null && p.assignedToId!.isNotEmpty) {
                            return false;
                          }
                        } else {
                          if (p.assignedToId != _selectedEmployeeFilter &&
                              p.assignedToName != _selectedEmployeeFilter) {
                            return false;
                          }
                        }
                      }

                      // 2. Status Filter
                      if (_selectedStatusFilter != 'all' && p.status != _selectedStatusFilter) {
                        return false;
                      }

                      // 3. Search Filter
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        final matchesName = p.fullName.toLowerCase().contains(q);
                        final matchesPhone = p.phoneNumber?.contains(q) ?? false;
                        final matchesCompany = p.companyName?.toLowerCase().contains(q) ?? false;
                        if (!matchesName && !matchesPhone && !matchesCompany) return false;
                      }

                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.white.withValues(alpha: 0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'لا يوجد عملاء محتملين مطاطقين لشروط الفلترة',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return GlassCard(
                      padding: const EdgeInsets.all(0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                          columnSpacing: 20,
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.05)),
                          columns: [
                            DataColumn(
                              label: Checkbox(
                                value: _selectedProspectIds.length == filtered.length && filtered.isNotEmpty,
                                activeColor: TfcColors.primary,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedProspectIds.addAll(filtered.map((e) => e.id));
                                    } else {
                                      _selectedProspectIds.clear();
                                    }
                                  });
                                },
                              ),
                            ),
                            const DataColumn(label: Text('اسم العميل المحتمل', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('رقم الهاتف', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('الشركة / الوظيفة', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('المحافظة', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('الموظف المسند إليه', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('الحالة', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                            const DataColumn(label: Text('الإجراءات', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((prospect) {
                            final isSelected = _selectedProspectIds.contains(prospect.id);
                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedProspectIds.add(prospect.id);
                                  } else {
                                    _selectedProspectIds.remove(prospect.id);
                                  }
                                });
                              },
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: TfcColors.primary,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedProspectIds.add(prospect.id);
                                        } else {
                                          _selectedProspectIds.remove(prospect.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(
                                  InkWell(
                                    onTap: () => _showProspectDetailsDialog(context, prospect),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                prospect.fullName,
                                                style: const TextStyle(
                                                  color: TfcColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                              if (prospect.isConverted)
                                                const Text('تم التحويل لعميل رسمياً', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(width: 6),
                                          const Icon(Icons.open_in_new, size: 14, color: TfcColors.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  prospect.phoneNumber != null && prospect.phoneNumber!.isNotEmpty
                                    ? PhoneActionWidget(label: '', phoneNumber: prospect.phoneNumber!)
                                    : const Text('غير محدد', style: TextStyle(color: Colors.white70)),
                                ),
                                DataCell(Text(
                                  '${prospect.companyName ?? ''} ${prospect.jobTitle != null ? '(${prospect.jobTitle})' : ''}'.trim(),
                                  style: const TextStyle(color: Colors.white70),
                                )),
                                DataCell(Text(prospect.governorate ?? 'غير محدد', style: const TextStyle(color: Colors.white70))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (prospect.assignedToName != null && prospect.assignedToName!.isNotEmpty)
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      prospect.assignedToName ?? 'غير مسند',
                                      style: TextStyle(
                                        color: (prospect.assignedToName != null && prospect.assignedToName!.isNotEmpty)
                                            ? Colors.lightBlueAccent
                                            : Colors.orangeAccent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(_buildStatusBadge(prospect.status)),
                                DataCell(
                                  Row(
                                    children: [
                                      // View Details Popup
                                      IconButton(
                                        icon: const Icon(Icons.visibility_outlined, color: TfcColors.primary, size: 20),
                                        tooltip: 'عرض تفاصيل العميل',
                                        onPressed: () => _showProspectDetailsDialog(context, prospect),
                                      ),
                                      // Edit Action
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                        tooltip: 'تعديل البيانات',
                                        onPressed: () => _showAddOrEditProspectDialog(context, prospect: prospect),
                                      ),

                                      // Convert to Client Button
                                      if (!prospect.isConverted)
                                        ElevatedButton.icon(
                                          onPressed: () => _handleConvertToClient(context, prospect),
                                          icon: const Icon(Icons.arrow_forward, size: 14),
                                          label: const Text('تحويل لعميل', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
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
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: TfcColors.primary)),
                  error: (err, stack) => Center(child: Text('خطأ في جلب العملاء المحتملين: $err', style: const TextStyle(color: Colors.redAccent))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;
    switch (status) {
      case 'converted':
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.greenAccent;
        text = 'تم التحويل';
        break;
      case 'contacted':
        bg = Colors.blue.withValues(alpha: 0.2);
        fg = Colors.lightBlueAccent;
        text = 'تم التواصل';
        break;
      case 'rejected':
        bg = Colors.red.withValues(alpha: 0.2);
        fg = Colors.redAccent;
        text = 'مرفوض';
        break;
      default:
        bg = Colors.amber.withValues(alpha: 0.2);
        fg = Colors.amberAccent;
        text = 'قيد الانتظار';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  // Handle conversion to official client
  void _handleConvertToClient(BuildContext context, ProspectModel prospect) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        title: const Text('تحويل إلى عميل رسمياً', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد نقل بيانات "${prospect.fullName}" لجدول العملاء الأساسي لطلب التمويل؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              
              navigator.pop();
              // Mark prospect converted
              final updated = prospect.copyWith(isConverted: true, status: 'converted');
              await ref.read(prospectsProvider.notifier).updateProspect(updated);

              // 1. Parse custom mapped data from prospect.rawData
              final raw = prospect.rawData;
              final hasCompound = raw['has_compound_unit'] == true || raw['compound_name'] != null;
              final hasCar = raw['has_modern_car'] == true || raw['car_brand'] != null;

              final List<Map<String, dynamic>> compoundUnits = [];
              if (raw['compound_name'] != null) {
                compoundUnits.add({
                  'compound_name': raw['compound_name'] ?? '',
                  'developer_name': raw['developer_name'] ?? '',
                  'contract_date': raw['contract_date'] ?? '',
                  'unit_value': (raw['unit_value'] as num?)?.toDouble() ?? 0.0,
                  'down_payment': (raw['down_payment'] as num?)?.toDouble() ?? 0.0,
                });
              }

              final List<Map<String, dynamic>> modernCars = [];
              if (raw['car_brand'] != null) {
                modernCars.add({
                  'car_brand': raw['car_brand'] ?? '',
                  'car_model_year': raw['car_model_year'] ?? '',
                  'car_market_value': (raw['car_market_value'] as num?)?.toDouble() ?? 0.0,
                  'car_license_status': raw['car_license_status'] ?? 'بدون حظر',
                });
              }

              // 2. Build official ClientModel
              final newClient = ClientModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                fullName: prospect.fullName,
                phoneNumber: prospect.phoneNumber ?? '',
                secondaryPhoneNumber: prospect.secondaryPhoneNumber,
                nationalId: prospect.nationalId ?? '',
                birthDate: raw['birth_date'] ?? '1990-01-01',
                employmentType: raw['employment_type'] ?? 'private_sector',
                companyName: prospect.companyName,
                jobTitle: prospect.jobTitle,
                isInsured: false,
                salaryTransferMethod: raw['salary_transfer_method'] ?? 'bank_transfer',
                cashSalaryAmount: prospect.salaryAmount,
                creditScore: int.tryParse(raw['credit_score']?.toString() ?? '') ?? 650,
                requestedAmount: (raw['requested_amount'] as num?)?.toDouble() ?? prospect.salaryAmount ?? 0,
                governorate: prospect.governorate ?? 'القاهرة',
                representativeName: prospect.assignedToName,
                status: 'pending',
                createdAt: DateTime.now(),
                hasCompoundUnit: hasCompound,
                hasModernCar: hasCar,
                compoundUnitsData: compoundUnits,
                modernCarsData: modernCars,
              );

              // 3. Add to Clients List
              await ref.read(clientProvider.notifier).addClient(newClient, [], []);

              // 4. Navigate directly to Client Details
              if (widget.onNavigateToClientDetails != null) {
                widget.onNavigateToClientDetails!(newClient.id);
              }

              messenger.showSnackBar(
                const SnackBar(content: Text('تم تحويل العميل بنجاح وتوجيهك لصفحة تفاصيل العميل!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد التحويل', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Bulk assignment dialog for selected prospects
  void _showBulkAssignDialog(BuildContext context) {
    final employeesState = ref.watch(employeesProvider);
    final companyEmployees = employeesState.employees.where((e) => e.role != 'bank_employee').toList();
    String? selectedEmpId;
    String? selectedEmpName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2430),
          title: Text('توزيع ${_selectedProspectIds.length} عميل محتمل على موظف', style: const TextStyle(color: Colors.white)),
          content: DropdownButtonFormField<String>(
            dropdownColor: const Color(0xFF1E2430),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'اختر الموظف (موظفي الشركة)',
              labelStyle: TextStyle(color: Colors.white70),
            ),
            items: companyEmployees.map((emp) => DropdownMenuItem(
              value: emp.id,
              child: Text(emp.fullName),
            )).toList(),
            onChanged: (val) {
              final emp = companyEmployees.firstWhere((e) => e.id == val);
              setDialogState(() {
                selectedEmpId = emp.id;
                selectedEmpName = emp.fullName;
              });
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: (selectedEmpId != null)
                  ? () async {
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      
                      navigator.pop();
                      final success = await ref.read(prospectsProvider.notifier).assignProspectsBulk(
                            _selectedProspectIds.toList(),
                            selectedEmpId!,
                            selectedEmpName!,
                          );
                      if (success) {
                        setState(() => _selectedProspectIds.clear());
                        messenger.showSnackBar(
                          const SnackBar(content: Text('تم إسناد العملاء المحددين بنجاح!')),
                        );
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
              child: const Text('تطبيق التوزيع', style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  // Prospect details modal popup displaying all Google Sheet fields
  void _showProspectDetailsDialog(BuildContext context, ProspectModel prospect) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: TfcColors.primary, size: 28),
                const SizedBox(width: 10),
                Text(
                  'تفاصيل العميل المحتمل: ${prospect.fullName}',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Highlight Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TfcColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('الحالة الحالية: ', style: TextStyle(color: Colors.white70)),
                          _buildStatusBadge(prospect.status),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('الموظف المسند إليه: ', style: TextStyle(color: Colors.white70)),
                          Text(
                            prospect.assignedToName ?? 'غير مسند',
                            style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main Parsed Fields Section
                const Text(
                  '📊 البيانات الأساسية المحددة:',
                  style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildDetailInfoTile('👤 الاسم الكامل', prospect.fullName),
                    if (prospect.phoneNumber != null && prospect.phoneNumber!.isNotEmpty)
                      PhoneActionWidget(label: '📞 رقم الهاتف الأساسي', phoneNumber: prospect.phoneNumber!),
                    if (prospect.secondaryPhoneNumber != null && prospect.secondaryPhoneNumber!.isNotEmpty)
                      PhoneActionWidget(label: '📱 رقم الهاتف الإضافي', phoneNumber: prospect.secondaryPhoneNumber!),
                    if (prospect.nationalId != null)
                      _buildDetailInfoTile('🆔 الرقم القومي', prospect.nationalId!),
                    _buildDetailInfoTile('🏢 جهة العمل / الشركة', prospect.companyName ?? 'غير محدد'),
                    _buildDetailInfoTile('💼 المسمى الوظيفي', prospect.jobTitle ?? 'غير محدد'),
                    _buildDetailInfoTile('📍 المحافظة', prospect.governorate ?? 'غير محدد'),
                    if (prospect.salaryAmount != null)
                      _buildDetailInfoTile('💰 صافي الدخل الشهري', '${prospect.salaryAmount} ج.م'),
                  ],
                ),
                const SizedBox(height: 20),

                // Raw Data from Google Sheet Section
                if (prospect.rawData.isNotEmpty) ...[
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 10),
                  const Text(
                    '📄 كافة الحقول الواردة من شيت جوجل (Raw Sheet Data):',
                    style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: prospect.rawData.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.key}: ',
                                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
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
            child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
          ),
          if (!prospect.isConverted)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _handleConvertToClient(context, prospect);
              },
              icon: const Icon(Icons.transform, color: Colors.white),
              label: const Text('جاهز للتحويل لعميل رسمياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailInfoTile(String title, String value) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  // Handle Syncing from Google Sheets
  Future<void> _handleSyncFromGoogleSheets(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final configState = ref.watch(googleSheetConfigProvider);
    final config = configState.value;

    if (config == null || config.sheetUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('يرجى أولاً ضبط رابط ورابط حقول جوجل شيت في شاشة الإعدادات!')),
      );
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('جاري جلب ومزامنة الصفوف من Google Sheet...')),
    );

    final rawRows = await ref.read(googleSheetConfigProvider.notifier).syncRowsFromSheet(config.sheetUrl);
    if (rawRows.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على بيانات في شيت جوجل أو الرابط غير صالح.')),
      );
      return;
    }

    final mappings = config.fieldMappings;
    final newProspects = <ProspectModel>[];

    for (final row in rawRows) {
      String name = 'عميل جديد';
      String? phone;
      String? company;
      String? job;
      String? gov;
      double? salary;

      mappings.forEach((sheetHeader, targetField) {
        final val = row[sheetHeader];
        if (val != null && val.isNotEmpty) {
          switch (targetField) {
            case 'full_name':
              name = val;
              break;
            case 'phone_number':
              phone = val;
              break;
            case 'company_name':
              company = val;
              break;
            case 'job_title':
              job = val;
              break;
            case 'governorate':
              gov = val;
              break;
            case 'salary_amount':
              salary = double.tryParse(val.replaceAll(',', ''));
              break;
          }
        }
      });

      newProspects.add(ProspectModel(
        id: '',
        fullName: name,
        phoneNumber: phone,
        companyName: company,
        jobTitle: job,
        governorate: gov,
        salaryAmount: salary,
        rawData: row,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    await ref.read(prospectsProvider.notifier).addProspectsList(newProspects);
    messenger.showSnackBar(
      SnackBar(content: Text('تمت مزامنة واستيراد ${newProspects.length} عميل محتمل بنجاح!')),
    );
  }

  // Add / Edit Dialog
  void _showAddOrEditProspectDialog(BuildContext context, {ProspectModel? prospect}) {
    final isEdit = prospect != null;
    final nameCtrl = TextEditingController(text: prospect?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: prospect?.phoneNumber ?? '');
    final companyCtrl = TextEditingController(text: prospect?.companyName ?? '');
    final jobCtrl = TextEditingController(text: prospect?.jobTitle ?? '');
    final govCtrl = TextEditingController(text: prospect?.governorate ?? '');
    String status = prospect?.status ?? 'pending';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        title: Text(isEdit ? 'تعديل بيانات العميل المحتمل' : 'إضافة عميل محتمل جديد', style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'الاسم الكامل', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'رقم الهاتف', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              TextField(controller: companyCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'جهة العمل / الشركة', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              TextField(controller: jobCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'المسمى الوظيفي', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              TextField(controller: govCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'المحافظة', labelStyle: TextStyle(color: Colors.white70))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
                dropdownColor: const Color(0xFF1E2430),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'الحالة', labelStyle: TextStyle(color: Colors.white70)),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                  DropdownMenuItem(value: 'contacted', child: Text('تم التواصل')),
                  DropdownMenuItem(value: 'rejected', child: Text('مرفوض / غير مهتم')),
                ],
                onChanged: (val) {
                  if (val != null) status = val;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              if (isEdit) {
                final updated = prospect.copyWith(
                  fullName: nameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  companyName: companyCtrl.text.trim(),
                  jobTitle: jobCtrl.text.trim(),
                  governorate: govCtrl.text.trim(),
                  status: status,
                );
                await ref.read(prospectsProvider.notifier).updateProspect(updated);
              } else {
                final newP = ProspectModel(
                  id: '',
                  fullName: nameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  companyName: companyCtrl.text.trim(),
                  jobTitle: jobCtrl.text.trim(),
                  governorate: govCtrl.text.trim(),
                  status: status,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await ref.read(prospectsProvider.notifier).addProspectsList([newP]);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
            child: const Text('حفظ', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
