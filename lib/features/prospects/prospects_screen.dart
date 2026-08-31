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
                  if (isAdmin)
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
                                value: _selectedStatusFilter,
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
                                  DropdownMenuItem(value: 'pending', child: Text('— فارغ (قيد الانتظار) —')),
                                  DropdownMenuItem(value: 'yes', child: Text('YES (أصفر)')),
                                  DropdownMenuItem(value: 'no', child: Text('NO (أحمر)')),
                                  DropdownMenuItem(value: 'finish', child: Text('Finish (بني)')),
                                  DropdownMenuItem(value: 'converted', child: Text('تم التحويل لعميل (أخضر)')),
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
                                  value: _selectedEmployeeFilter,
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

                    // Scrollbar Controller for bottom horizontal scrolling
                    final horizontalScrollController = ScrollController();

                    return GlassCard(
                      padding: const EdgeInsets.all(0),
                      child: Scrollbar(
                        controller: horizontalScrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        thickness: 8,
                        radius: const Radius.circular(8),
                        child: SingleChildScrollView(
                          controller: horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: DataTable(
                              columnSpacing: 18,
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
                                const DataColumn(label: Text('التحويل', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                                const DataColumn(label: Text('الإجراءات', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold))),
                              ],
                              rows: filtered.map((prospect) {
                                final isSelected = _selectedProspectIds.contains(prospect.id);
                                final isConverted = prospect.isConverted || prospect.status == 'converted';
                                final statusVal = prospect.status.toLowerCase().trim();

                                return DataRow(
                                  selected: isSelected,
                                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                                    // 1. إذا تم التحويل لعميل: أخضر كامل
                                    if (isConverted) {
                                      return const Color(0xFF1B5E20).withValues(alpha: 0.90);
                                    }
                                    // 2. إذا كانت الحالة YES: أصفر واضح ومريح مع تباين
                                    if (statusVal == 'yes') {
                                      return const Color(0xFFFBC02D).withValues(alpha: 0.85);
                                    }
                                    // 3. إذا كانت الحالة NO: أحمر واضح ومريح
                                    if (statusVal == 'no' || statusVal == 'rejected') {
                                      return const Color(0xFFC62828).withValues(alpha: 0.85);
                                    }
                                    // 4. إذا كانت الحالة Finish: بني أنيق وواضح
                                    if (statusVal == 'finish') {
                                      return const Color(0xFF6D4C41).withValues(alpha: 0.90);
                                    }
                                    // 5. إذا كانت فارغة أو pending: لون الصف العادي
                                    if (states.contains(WidgetState.hovered)) {
                                      return Colors.white.withValues(alpha: 0.06);
                                    }
                                    if (states.contains(WidgetState.selected)) {
                                      return TfcColors.primary.withValues(alpha: 0.15);
                                    }
                                    return null;
                                  }),
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
                                        activeColor: isConverted ? Colors.white : TfcColors.primary,
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
                                              Text(
                                                prospect.fullName,
                                                style: TextStyle(
                                                  color: isConverted
                                                      ? Colors.white
                                                      : (statusVal == 'yes' ? Colors.black87 : Colors.white),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  decoration: TextDecoration.underline,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.open_in_new,
                                                size: 14,
                                                color: isConverted
                                                    ? Colors.white
                                                    : (statusVal == 'yes' ? Colors.black87 : TfcColors.primary),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      prospect.phoneNumber != null && prospect.phoneNumber!.isNotEmpty
                                          ? PhoneActionWidget(
                                              label: '',
                                              phoneNumber: prospect.phoneNumber!,
                                            )
                                          : Text(
                                              'غير محدد',
                                              style: TextStyle(
                                                color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white70,
                                              ),
                                            ),
                                    ),
                                    DataCell(Text(
                                      '${prospect.companyName ?? ''} ${prospect.jobTitle != null ? '(${prospect.jobTitle})' : ''}'.trim().isEmpty
                                          ? 'غير محدد'
                                          : '${prospect.companyName ?? ''} ${prospect.jobTitle != null ? '(${prospect.jobTitle})' : ''}'.trim(),
                                      style: TextStyle(
                                        color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                                    DataCell(Text(
                                      prospect.governorate ?? 'غير محدد',
                                      style: TextStyle(
                                        color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    )),
                                    DataCell(
                                      isAdmin
                                          ? DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: (prospect.assignedToId != null && prospect.assignedToId!.isNotEmpty)
                                                    ? prospect.assignedToId
                                                    : 'unassigned',
                                                dropdownColor: const Color(0xFF1E2430),
                                                style: TextStyle(
                                                  color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                items: [
                                                  const DropdownMenuItem(value: 'unassigned', child: Text('غير مسند')),
                                                  ...employeesState.employees
                                                      .where((emp) => emp.role != 'bank_employee')
                                                      .map((emp) => DropdownMenuItem(
                                                            value: emp.id,
                                                            child: Text(emp.fullName),
                                                          )),
                                                ],
                                                onChanged: (newEmpId) async {
                                                  if (newEmpId == 'unassigned') {
                                                    final updated = prospect.copyWith(assignedToId: '', assignedToName: '');
                                                    await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                                  } else if (newEmpId != null) {
                                                    final emp = employeesState.employees.firstWhere((e) => e.id == newEmpId);
                                                    final updated = prospect.copyWith(assignedToId: emp.id, assignedToName: emp.fullName);
                                                    await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                                  }
                                                },
                                              ),
                                            )
                                          : Text(
                                              prospect.assignedToName ?? 'غير مسند',
                                              style: TextStyle(
                                                color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                    ),
                                    // 2. خانة الحالة: قائمة منسدلة (فارغ، YES، NO، Finish)
                                    DataCell(
                                      DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: ['yes', 'no', 'finish', 'pending'].contains(statusVal)
                                              ? (statusVal == 'pending' ? 'pending' : statusVal)
                                              : (statusVal == 'rejected' ? 'no' : 'pending'),
                                          dropdownColor: const Color(0xFF1E2430),
                                          style: TextStyle(
                                            color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          items: const [
                                            DropdownMenuItem(value: 'pending', child: Text('— فارغ (بدون) —', style: TextStyle(color: Colors.white70))),
                                            DropdownMenuItem(
                                              value: 'yes',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle, color: Color(0xFFFBC02D), size: 14),
                                                  SizedBox(width: 4),
                                                  Text('YES (أصفر)', style: TextStyle(color: Color(0xFFFBC02D), fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'no',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.cancel, color: Color(0xFFE53935), size: 14),
                                                  SizedBox(width: 4),
                                                  Text('NO (أحمر)', style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            DropdownMenuItem(
                                              value: 'finish',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.flag, color: Color(0xFF8D6E63), size: 14),
                                                  SizedBox(width: 4),
                                                  Text('Finish (بني)', style: TextStyle(color: Color(0xFFBCAAA4), fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          ],
                                          onChanged: (newStatus) async {
                                            if (newStatus != null) {
                                              final updated = prospect.copyWith(
                                                status: newStatus,
                                              );
                                              await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    // 3. خانة التحويل
                                    DataCell(
                                      isConverted
                                          ? Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.white, size: 14),
                                                  SizedBox(width: 4),
                                                  Text('تم التحويل ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                ],
                                              ),
                                            )
                                          : ElevatedButton.icon(
                                              onPressed: () => _handleConvertToClient(context, prospect),
                                              icon: const Icon(Icons.transform, size: 13),
                                              label: const Text('تحويل لعميل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2E7D32),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                            ),
                                    ),
                                    // 4. الإجراءات (عرض، تعديل، حذف)
                                    DataCell(
                                      Row(
                                        children: [
                                          // View Details Popup
                                          IconButton(
                                            icon: Icon(
                                              Icons.visibility_outlined,
                                              color: statusVal == 'yes' && !isConverted ? Colors.black87 : TfcColors.primary,
                                              size: 20,
                                            ),
                                            tooltip: 'عرض تفاصيل العميل',
                                            onPressed: () => _showProspectDetailsDialog(context, prospect),
                                          ),
                                          // Edit Action - Admin Only
                                          if (isAdmin)
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                color: statusVal == 'yes' && !isConverted ? Colors.black87 : Colors.white70,
                                                size: 20,
                                              ),
                                              tooltip: 'تعديل البيانات',
                                              onPressed: () => _showAddOrEditProspectDialog(context, prospect: prospect),
                                            ),
                                          // Delete Action - Admin Only
                                          if (isAdmin)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                              tooltip: 'حذف العميل',
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    backgroundColor: const Color(0xFF1E2430),
                                                    title: const Text('حذف عميل محتمل', style: TextStyle(color: Colors.white)),
                                                    content: const Text('هل أنت متأكد من حذف هذا العميل المحتمل نهائياً؟', style: TextStyle(color: Colors.white70)),
                                                    actions: [
                                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                                      ElevatedButton(
                                                        onPressed: () => Navigator.pop(ctx, true),
                                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                        child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true) {
                                                  await ref.read(prospectsProvider.notifier).deleteProspect(prospect.id);
                                                }
                                              },
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

              // 1.5. Compile Google Sheet Raw Data into formatted notes
              final rawNotesBuffer = StringBuffer();
              if (prospect.notes != null && prospect.notes!.isNotEmpty) {
                rawNotesBuffer.writeln(prospect.notes);
                rawNotesBuffer.writeln('────────────────────────');
              }
              if (raw.isNotEmpty) {
                rawNotesBuffer.writeln('📋 [بيانات مستوردة من شيت جوجل]:');
                raw.forEach((k, v) {
                  if (v != null && v.toString().trim().isNotEmpty) {
                    rawNotesBuffer.writeln('• $k: $v');
                  }
                });
              }

              final notesContent = rawNotesBuffer.isNotEmpty ? rawNotesBuffer.toString().trim() : null;
              final initialHistory = <InteractionLogModel>[];
              if (notesContent != null) {
                initialHistory.add(
                  InteractionLogModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    actionType: 'تحويل من عميل محتمل',
                    notes: notesContent,
                    createdBy: prospect.assignedToName ?? 'النظام',
                    createdAt: DateTime.now(),
                  ),
                );
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
                history: initialHistory,
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
  // Prospect details modal popup displaying all Google Sheet fields with Admin editing capabilities
  void _showProspectDetailsDialog(BuildContext context, ProspectModel initialProspect) {
    final authState = ref.read(authProvider);
    final isAdmin = authState.role == 'admin';

    showDialog(
      context: context,
      builder: (ctx) {
        ProspectModel currentProspect = initialProspect;
        final currentRawData = Map<String, dynamic>.from(initialProspect.rawData);

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
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
                        'تفاصيل العميل المحتمل: ${currentProspect.fullName}',
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
                width: 700,
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
                                _buildStatusBadge(currentProspect.status),
                              ],
                            ),
                            Row(
                              children: [
                                const Text('الموظف المسند إليه: ', style: TextStyle(color: Colors.white70)),
                                Text(
                                  currentProspect.assignedToName ?? 'غير مسند',
                                  style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Main Parsed Fields Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '📊 البيانات الأساسية المحددة:',
                            style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (isAdmin)
                            TextButton.icon(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                _showAddOrEditProspectDialog(context, prospect: currentProspect);
                              },
                              icon: const Icon(Icons.edit, size: 16, color: TfcColors.primary),
                              label: const Text('تعديل البيانات الأساسية', style: TextStyle(color: TfcColors.primary, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildDetailInfoTile('👤 الاسم الكامل', currentProspect.fullName),
                          if (currentProspect.phoneNumber != null && currentProspect.phoneNumber!.isNotEmpty)
                            PhoneActionWidget(label: '📞 رقم الهاتف الأساسي', phoneNumber: currentProspect.phoneNumber!),
                          if (currentProspect.secondaryPhoneNumber != null && currentProspect.secondaryPhoneNumber!.isNotEmpty)
                            PhoneActionWidget(label: '📱 رقم الهاتف الإضافي', phoneNumber: currentProspect.secondaryPhoneNumber!),
                          if (currentProspect.nationalId != null && currentProspect.nationalId!.isNotEmpty)
                            _buildDetailInfoTile('🆔 الرقم القومي', currentProspect.nationalId!),
                          _buildDetailInfoTile('🏢 جهة العمل / الشركة', currentProspect.companyName ?? 'غير محدد'),
                          _buildDetailInfoTile('💼 المسمى الوظيفي', currentProspect.jobTitle ?? 'غير محدد'),
                          _buildDetailInfoTile('📍 المحافظة', currentProspect.governorate ?? 'غير محدد'),
                          if (currentProspect.salaryAmount != null)
                            _buildDetailInfoTile('💰 صافي الدخل الشهري', '${currentProspect.salaryAmount} ج.م'),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Raw Data from Google Sheet Section
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '📄 كافة الحقول الواردة من شيت جوجل (Google Sheet Data):',
                            style: TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (isAdmin)
                            ElevatedButton.icon(
                              onPressed: () {
                                _showAddOrEditRawFieldDialog(
                                  dialogCtx,
                                  onSave: (newKey, newVal) async {
                                    setDialogState(() {
                                      currentRawData[newKey] = newVal;
                                    });
                                    final updated = currentProspect.copyWith(rawData: currentRawData);
                                    await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                    currentProspect = updated;
                                  },
                                );
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('إضافة حقل جديد', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (currentRawData.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Center(
                            child: Text('لا توجد حقول إضافية مسجلة من الشيت', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ),
                        )
                      else
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
                            children: currentRawData.entries.map((entry) {
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        '${entry.key}: ',
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        entry.value?.toString() ?? '',
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ),
                                    if (isAdmin) ...[
                                      // Edit Field Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Colors.lightBlueAccent, size: 18),
                                        tooltip: 'تعديل هذا الحقل',
                                        onPressed: () {
                                          _showAddOrEditRawFieldDialog(
                                            dialogCtx,
                                            fieldKey: entry.key,
                                            fieldValue: entry.value?.toString(),
                                            onSave: (newKey, newVal) async {
                                              setDialogState(() {
                                                if (newKey != entry.key) {
                                                  currentRawData.remove(entry.key);
                                                }
                                                currentRawData[newKey] = newVal;
                                              });
                                              final updated = currentProspect.copyWith(rawData: currentRawData);
                                              await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                              currentProspect = updated;
                                            },
                                          );
                                        },
                                      ),
                                      // Delete Field Button
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        tooltip: 'حذف هذا الحقل',
                                        onPressed: () async {
                                          setDialogState(() {
                                            currentRawData.remove(entry.key);
                                          });
                                          final updated = currentProspect.copyWith(rawData: currentRawData);
                                          await ref.read(prospectsProvider.notifier).updateProspect(updated);
                                          currentProspect = updated;
                                        },
                                      ),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إغلاق', style: TextStyle(color: Colors.white70)),
                ),
                if (!currentProspect.isConverted)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleConvertToClient(context, currentProspect);
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
            );
          },
        );
      },
    );
  }

  // Dialog for Adding or Editing a Raw Data field from Google Sheet
  void _showAddOrEditRawFieldDialog(
    BuildContext context, {
    String? fieldKey,
    String? fieldValue,
    required Future<void> Function(String key, String value) onSave,
  }) {
    final keyController = TextEditingController(text: fieldKey);
    final valueController = TextEditingController(text: fieldValue);
    final isEditing = fieldKey != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          isEditing ? 'تعديل حقل شيت جوجل' : 'إضافة حقل شيت جديد',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم الحقل / العمود',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'مثال: رقم السجل، عنوان الفرع...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'قيمة الحقل',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: 'أدخل قيمة هذا الحقل...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final key = keyController.text.trim();
              final val = valueController.text.trim();
              if (key.isNotEmpty) {
                Navigator.pop(ctx);
                await onSave(key, val);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
            child: Text(isEditing ? 'حفظ التعديل' : 'إضافة', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
    final configState = ref.read(googleSheetConfigProvider);
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

    // Build set of existing phone numbers to avoid duplicates
    final existingProspects = ref.read(prospectsProvider).value ?? [];
    final existingClients = ref.read(clientProvider).clients;

    // Normalize phone: remove spaces, dashes, + prefix
    String normalizePhone(String? phone) {
      if (phone == null) return '';
      return phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), '').trim();
    }

    final existingPhones = <String>{
      ...existingProspects
          .map((p) => normalizePhone(p.phoneNumber))
          .where((p) => p.isNotEmpty),
      ...existingClients
          .map((c) => normalizePhone(c.phoneNumber))
          .where((p) => p.isNotEmpty),
    };

    final mappings = config.fieldMappings;
    final newProspects = <ProspectModel>[];
    int skippedCount = 0;

    for (final row in rawRows) {
      String name = 'عميل جديد';
      String? phone;
      String? secondaryPhone;
      String? nationalId;
      String? company;
      String? job;
      String? gov;
      double? salary;
      String? notes;
      String? employmentType;
      String? salaryTransferMethod;
      String? status;
      final rawData = Map<String, dynamic>.from(row);

      // Apply field mappings - each sheet column → target field
      mappings.forEach((sheetHeader, targetField) {
        final val = row[sheetHeader];
        if (val != null && val.toString().trim().isNotEmpty) {
          final strVal = val.toString().trim();
          switch (targetField) {
            case 'full_name':
              name = strVal;
              break;
            case 'phone_number':
              phone = strVal;
              break;
            case 'secondary_phone_number':
              secondaryPhone = strVal;
              break;
            case 'national_id':
              nationalId = strVal;
              break;
            case 'company_name':
              company = strVal;
              break;
            case 'job_title':
              job = strVal;
              break;
            case 'governorate':
              gov = strVal;
              break;
            case 'salary_amount':
            case 'cash_salary_amount':
              salary = double.tryParse(strVal.replaceAll(',', '').replaceAll('٬', ''));
              break;
            case 'notes':
              notes = strVal;
              break;
            case 'employment_type':
              employmentType = strVal;
              break;
            case 'salary_transfer_method':
              salaryTransferMethod = strVal;
              break;
            case 'status':
              status = strVal;
              break;
          }
          // Store mapped value in rawData under target field key
          rawData[targetField] = strVal;
        }
      });

      // Check for duplicate phone number
      final normalizedPhone = normalizePhone(phone);
      if (normalizedPhone.isNotEmpty && existingPhones.contains(normalizedPhone)) {
        skippedCount++;
        continue; // Skip duplicate
      }

      // Add phone to existing set to avoid duplicates within same sheet batch
      if (normalizedPhone.isNotEmpty) {
        existingPhones.add(normalizedPhone);
      }

      newProspects.add(ProspectModel(
        id: '',
        fullName: name,
        phoneNumber: phone,
        secondaryPhoneNumber: secondaryPhone,
        nationalId: nationalId,
        companyName: company,
        jobTitle: job,
        governorate: gov,
        salaryAmount: salary,
        notes: notes,
        rawData: rawData,
        status: status ?? 'pending',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    if (newProspects.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text('لم تتم إضافة بيانات جديدة - تم تخطي $skippedCount عميل مكرر (رقم الهاتف موجود مسبقاً).')),
      );
      return;
    }

    await ref.read(prospectsProvider.notifier).addProspectsList(newProspects);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'تمت المزامنة: ✅ ${newProspects.length} عميل جديد${skippedCount > 0 ? ' | ⏭️ تم تخطي $skippedCount مكرر' : ''}',
          textAlign: TextAlign.right,
        ),
        backgroundColor: const Color(0xFF0F3824),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Add / Edit Dialog
  void _showAddOrEditProspectDialog(BuildContext context, {ProspectModel? prospect}) {
    final isEdit = prospect != null;
    final employeesState = ref.read(employeesProvider);
    final authState = ref.read(authProvider);
    final isAdmin = authState.role == 'admin';

    // Controllers
    final nameCtrl = TextEditingController(text: prospect?.fullName ?? '');
    final phoneCtrl = TextEditingController(text: prospect?.phoneNumber ?? '');
    final phone2Ctrl = TextEditingController(text: prospect?.secondaryPhoneNumber ?? '');
    final nationalIdCtrl = TextEditingController(text: prospect?.nationalId ?? '');
    final companyCtrl = TextEditingController(text: prospect?.companyName ?? '');
    final jobCtrl = TextEditingController(text: prospect?.jobTitle ?? '');
    final govCtrl = TextEditingController(text: prospect?.governorate ?? '');
    final salaryCtrl = TextEditingController(text: prospect?.salaryAmount?.toString() ?? '');
    final notesCtrl = TextEditingController(text: prospect?.notes ?? '');

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // State
    String status = prospect?.status ?? 'pending';
    String? assignedEmployeeId = prospect?.assignedToId;
    String? assignedEmployeeName = prospect?.assignedToName;

    // Auto-assign to current user if company_employee and not editing
    if (!isEdit && authState.role == 'company_employee') {
      assignedEmployeeId = authState.user?.id;
      assignedEmployeeName = authState.fullName;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2430),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_outlined : Icons.person_add_alt_1,
                color: TfcColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                isEdit ? 'تعديل بيانات العميل المحتمل' : 'إضافة عميل محتمل جديد',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── البيانات الإلزامية ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: TfcColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: TfcColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.star, color: TfcColors.primary, size: 14),
                          SizedBox(width: 6),
                          Text('البيانات الإلزامية', style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),

                    // الاسم الكامل (إلزامي)
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.right,
                      validator: (val) => val == null || val.trim().isEmpty ? '⚠️ الاسم الكامل مطلوب' : null,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.person, color: TfcColors.primary, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // رقم الهاتف (إلزامي)
                    TextFormField(
                      controller: phoneCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.right,
                      validator: (val) => val == null || val.trim().isEmpty ? '⚠️ رقم الهاتف مطلوب' : null,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف *',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.phone, color: TfcColors.primary, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── البيانات الاختيارية ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.tune, color: Colors.white54, size: 14),
                          SizedBox(width: 6),
                          Text('البيانات الاختيارية (يمكن إكمالها لاحقاً)', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),

                    // رقم الهاتف الثاني
                    TextField(
                      controller: phone2Ctrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.phone,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف البديل',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.phone_android, color: Colors.white38, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // الرقم القومي
                    TextField(
                      controller: nationalIdCtrl,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'الرقم القومي',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white38, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // جهة العمل والمسمى الوظيفي جنبًا إلى جنب
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: companyCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'جهة العمل',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              prefixIcon: const Icon(Icons.business_outlined, color: Colors.white38, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: jobCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'المسمى الوظيفي',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              prefixIcon: const Icon(Icons.work_outline, color: Colors.white38, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // المحافظة والدخل جنبًا إلى جنب
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: govCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'المحافظة',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              prefixIcon: const Icon(Icons.location_on_outlined, color: Colors.white38, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: salaryCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.right,
                            decoration: InputDecoration(
                              labelText: 'الدخل الشهري (جـ.م)',
                              labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                              prefixIcon: const Icon(Icons.attach_money, color: Colors.white38, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // الموظف المسند إليه (Admin فقط)
                    if (isAdmin)
                      DropdownButtonFormField<String>(
                        value: (assignedEmployeeId != null && assignedEmployeeId!.isNotEmpty) ? assignedEmployeeId : null,
                        dropdownColor: const Color(0xFF1E2430),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'الموظف المسند إليه',
                          labelStyle: const TextStyle(color: Colors.white70),
                          prefixIcon: const Icon(Icons.person_pin_outlined, color: Colors.white38, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('غير مسند', style: TextStyle(color: Colors.white54))),
                          ...employeesState.employees
                              .where((emp) => emp.role != 'bank_employee')
                              .map((emp) => DropdownMenuItem(
                                    value: emp.id,
                                    child: Text(emp.fullName),
                                  )),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            assignedEmployeeId = val;
                            if (val != null) {
                              final emp = employeesState.employees.firstWhere((e) => e.id == val);
                              assignedEmployeeName = emp.fullName;
                            } else {
                              assignedEmployeeName = null;
                            }
                          });
                        },
                      ),
                    if (isAdmin) const SizedBox(height: 10),

                    // الحالة
                    DropdownButtonFormField<String>(
                      value: status,
                      dropdownColor: const Color(0xFF1E2430),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'الحالة',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.flag_outlined, color: Colors.white38, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'pending', child: Text('قيد الانتظار')),
                        DropdownMenuItem(value: 'contacted', child: Text('تم التواصل')),
                        DropdownMenuItem(value: 'rejected', child: Text('مرفوض / غير مهتم')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => status = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // ملاحظات
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: const Icon(Icons.notes, color: Colors.white38, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: Colors.white54))),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                navigator.pop();

                // Build the rawData map
                final rawData = <String, dynamic>{
                  if (nationalIdCtrl.text.trim().isNotEmpty) 'national_id': nationalIdCtrl.text.trim(),
                  if (phone2Ctrl.text.trim().isNotEmpty) 'secondary_phone_number': phone2Ctrl.text.trim(),
                  if (companyCtrl.text.trim().isNotEmpty) 'company_name': companyCtrl.text.trim(),
                  if (jobCtrl.text.trim().isNotEmpty) 'job_title': jobCtrl.text.trim(),
                  if (govCtrl.text.trim().isNotEmpty) 'governorate': govCtrl.text.trim(),
                  if (salaryCtrl.text.trim().isNotEmpty) 'salary_amount': salaryCtrl.text.trim(),
                  if (notesCtrl.text.trim().isNotEmpty) 'notes': notesCtrl.text.trim(),
                };

                if (isEdit) {
                  final updated = prospect.copyWith(
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    secondaryPhoneNumber: phone2Ctrl.text.trim().isNotEmpty ? phone2Ctrl.text.trim() : null,
                    nationalId: nationalIdCtrl.text.trim().isNotEmpty ? nationalIdCtrl.text.trim() : null,
                    companyName: companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : null,
                    jobTitle: jobCtrl.text.trim().isNotEmpty ? jobCtrl.text.trim() : null,
                    governorate: govCtrl.text.trim().isNotEmpty ? govCtrl.text.trim() : null,
                    salaryAmount: double.tryParse(salaryCtrl.text.trim()),
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    assignedToId: assignedEmployeeId ?? prospect.assignedToId,
                    assignedToName: assignedEmployeeName ?? prospect.assignedToName,
                    status: status,
                    rawData: {...prospect.rawData, ...rawData},
                  );
                  await ref.read(prospectsProvider.notifier).updateProspect(updated);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('✅ تم تحديث بيانات العميل المحتمل بنجاح!'), backgroundColor: Color(0xFF0F3824)),
                  );
                } else {
                  final newP = ProspectModel(
                    id: '',
                    fullName: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    secondaryPhoneNumber: phone2Ctrl.text.trim().isNotEmpty ? phone2Ctrl.text.trim() : null,
                    nationalId: nationalIdCtrl.text.trim().isNotEmpty ? nationalIdCtrl.text.trim() : null,
                    companyName: companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : null,
                    jobTitle: jobCtrl.text.trim().isNotEmpty ? jobCtrl.text.trim() : null,
                    governorate: govCtrl.text.trim().isNotEmpty ? govCtrl.text.trim() : null,
                    salaryAmount: double.tryParse(salaryCtrl.text.trim()),
                    notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                    assignedToId: assignedEmployeeId,
                    assignedToName: assignedEmployeeName,
                    status: status,
                    rawData: rawData,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  await ref.read(prospectsProvider.notifier).addSingleProspect(newP);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('✅ تم إضافة العميل المحتمل بنجاح وحفظه في قاعدة البيانات!'),
                      backgroundColor: Color(0xFF0F3824),
                    ),
                  );
                }
              },
              icon: Icon(isEdit ? Icons.save : Icons.person_add_alt_1, size: 18),
              label: Text(isEdit ? 'حفظ التعديلات' : 'إضافة العميل', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TfcColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
