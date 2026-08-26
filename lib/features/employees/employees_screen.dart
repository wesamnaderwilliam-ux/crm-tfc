import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/employees_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../models/profile.dart';
import '../../providers/banks_provider.dart';
import 'employee_permissions_panel.dart';
import 'employee_targets_panel.dart';
import '../../core/widgets/phone_action_widget.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  int _activeTab = 0; // 0 = employees list, 1 = targets panel

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeesProvider);
    final employees = empState.filteredEmployees;
    final authState = ref.watch(authProvider);
    final isCurrentUserAdmin = authState.role == 'admin' || authState.user?.email == 'wezonader@gmail.com';
    
    // Resolve per-employee effective permissions for the logged-in user
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);
    final userId = authState.user?.id ?? '';
    final role = authState.role;
    final effectivePerms = (role == 'admin')
        ? EmployeePermissionKeys.defaultsForRole('admin')
        : EmployeePermissionKeys.resolve(role, customPermsState[userId] ?? {});
    final canManageEmployees = effectivePerms[EmployeePermissionKeys.manageEmployees] ?? false;
    final canViewEmployeePhone = effectivePerms[EmployeePermissionKeys.viewEmployeePhone] ?? false;
    final canViewEmployeeNationalId = effectivePerms[EmployeePermissionKeys.viewEmployeeNationalId] ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.groups_rounded, color: TfcColors.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  _activeTab == 0 ? 'موظفي الشركة' : 'متابعة أهداف المبيعات (التارجت)',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_activeTab == 0) ...[
                  // Filter chips
                  _FilterChip(
                    label: 'الكل',
                    isSelected: empState.filterStatus == 'all',
                    onTap: () => ref.read(employeesProvider.notifier).setFilter('all'),
                    count: empState.employees.length,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'مؤكد',
                    isSelected: empState.filterStatus == 'confirmed',
                    onTap: () => ref.read(employeesProvider.notifier).setFilter('confirmed'),
                    count: empState.employees.where((e) => e.isConfirmed).length,
                    color: TfcColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'غير مؤكد',
                    isSelected: empState.filterStatus == 'unconfirmed',
                    onTap: () => ref.read(employeesProvider.notifier).setFilter('unconfirmed'),
                    count: empState.employees.where((e) => !e.isConfirmed).length,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 16),
                ],
                // Refresh button
                IconButton(
                  onPressed: () => ref.read(employeesProvider.notifier).fetchEmployees(),
                  icon: const Icon(Icons.refresh_rounded, color: TfcColors.primary),
                  tooltip: 'تحديث القائمة',
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Tab Switcher
            Row(
              textDirection: TextDirection.rtl,
              children: [
                ElevatedButton.icon(
                  onPressed: () => setState(() => _activeTab = 0),
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text("قائمة الموظفين"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeTab == 0 ? TfcColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                    foregroundColor: _activeTab == 0 ? TfcColors.primary : TfcColors.outline,
                    elevation: 0,
                    side: BorderSide(
                      color: _activeTab == 0 ? TfcColors.primary.withValues(alpha: 0.4) : Colors.white10,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _activeTab = 1),
                  icon: const Icon(Icons.track_changes, size: 16),
                  label: const Text("أهداف المبيعات (التارجت)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeTab == 1 ? TfcColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                    foregroundColor: _activeTab == 1 ? TfcColors.primary : TfcColors.outline,
                    elevation: 0,
                    side: BorderSide(
                      color: _activeTab == 1 ? TfcColors.primary.withValues(alpha: 0.4) : Colors.white10,
                      width: 1,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Error banner
            if (empState.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        empState.errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),

            // Loading or Table or Targets
            if (_activeTab == 1)
              const Expanded(
                child: SingleChildScrollView(
                  child: EmployeeTargetsPanel(),
                ),
              )
            else ...[
              if (empState.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: TfcColors.primary),
                  ),
                )
              else if (employees.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_rounded, color: TfcColors.outline.withValues(alpha: 0.5), size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          'لا يوجد موظفين في هذا التصنيف',
                          style: TextStyle(color: TfcColors.outline, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Grid of profile cards
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      // Determine grid columns
                      final crossAxisCount = width > 1200
                          ? 4
                          : width > 900
                              ? 3
                              : width > 600
                                  ? 2
                                  : 1;
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 290,
                        ),
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          final emp = employees[index];
                          return _buildEmployeeProfileCard(
                            emp,
                            context,
                            isCurrentUserAdmin,
                            canManageEmployees: canManageEmployees,
                            canViewPhone: canViewEmployeePhone,
                            canViewNationalId: canViewEmployeeNationalId,
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeProfileCard(
    Profile emp,
    BuildContext context,
    bool isAdmin, {
    bool canManageEmployees = false,
    bool canViewPhone = true,
    bool canViewNationalId = true,
  }) {
    final roleColor = _getRoleColor(emp.role);
    final hiringDateStr = emp.hiringDate != null
        ? '${emp.hiringDate!.year}-${emp.hiringDate!.month.toString().padLeft(2, '0')}-${emp.hiringDate!.day.toString().padLeft(2, '0')}'
        : '—';
    final bool isBankEmp = emp.role == 'bank_employee';
    final bool effectiveCanViewPhone = canViewPhone && (!isBankEmp || isAdmin);

    return GlassCard(
      borderRadius: 16,
      borderColor: Colors.white.withValues(alpha: 0.06),
      fillColor: TfcColors.surfaceDim.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Avatar, Name & Role Badge
          Row(
            textDirection: TextDirection.rtl,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: roleColor.withValues(alpha: 0.15),
                child: Icon(
                  _getRoleIcon(emp.role),
                  size: 24,
                  color: roleColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      emp.fullName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 4),
                    _buildRoleBadge(emp.role),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Details List (Phone, Email, National ID, Hiring Date)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProfileDetailRow(Icons.email_outlined, emp.email ?? '—'),
                const SizedBox(height: 6),
                if (isBankEmp) ...[
                  _buildProfileDetailRow(Icons.account_balance_outlined, emp.bankName ?? 'لم يحدد بنك'),
                  const SizedBox(height: 6),
                  if (emp.bankEmployeeId != null && emp.bankEmployeeId!.isNotEmpty) ...[
                    _buildProfileDetailRow(Icons.numbers_outlined, 'معرف المسئول: ${emp.bankEmployeeId}'),
                    const SizedBox(height: 6),
                  ],
                ],
                effectiveCanViewPhone
                    ? (emp.phoneNumber != null && emp.phoneNumber!.isNotEmpty
                        ? PhoneActionWidget(label: 'رقم الهاتف', phoneNumber: emp.phoneNumber!)
                        : _buildProfileDetailRow(Icons.phone_iphone_outlined, '—'))
                    : _buildProfileDetailRow(Icons.phone_iphone_outlined, 'مخفي 🔒', isHidden: true),
                const SizedBox(height: 6),
                canViewNationalId
                    ? _buildProfileDetailRow(Icons.badge_outlined, emp.nationalId ?? '—')
                    : _buildProfileDetailRow(Icons.badge_outlined, 'مخفي 🔒', isHidden: true),
                const SizedBox(height: 6),
                _buildProfileDetailRow(Icons.calendar_today_outlined, hiringDateStr),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Status & Confirmation Badges + Action Buttons
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  _buildStatusBadge(emp.employeeStatus),
                  const SizedBox(width: 6),
                  _buildConfirmationBadge(emp.isConfirmed),
                ],
              ),
              Row(
                children: [
                  // ── Permissions button (admin only, not for self-admin) ──
                  if (isAdmin && emp.role != 'admin')
                    Tooltip(
                      message: 'إدارة الصلاحيات',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showPermissionsPanel(context, emp),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.purpleAccent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                size: 14,
                                color: Colors.purpleAccent,
                              ),
                              if (emp.customPermissions.isNotEmpty) ...[  
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orangeAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${emp.customPermissions.length}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (isAdmin && emp.role != 'admin') const SizedBox(width: 6),
                  if (!emp.isConfirmed && (isAdmin || canManageEmployees))
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, size: 20, color: Colors.greenAccent),
                      tooltip: 'تأكيد الحساب',
                      onPressed: () => _confirmEmployee(emp),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  if (!emp.isConfirmed && (isAdmin || canManageEmployees)) const SizedBox(width: 8),
                  if (isAdmin || canManageEmployees)
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 20, color: TfcColors.primary),
                      tooltip: 'تعديل',
                      onPressed: () => _showEditDialog(context, emp),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String text, {bool isHidden = false}) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 14, color: isHidden ? Colors.orangeAccent.withValues(alpha: 0.5) : TfcColors.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isHidden ? Colors.orangeAccent.withValues(alpha: 0.5) : TfcColors.onSurface,
              fontStyle: isHidden ? FontStyle.italic : FontStyle.normal,
            ),
            textDirection: TextDirection.rtl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    final label = _getRoleLabel(role);
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = TfcColors.primary;
        label = 'نشط';
        break;
      case 'on_leave':
        color = Colors.orangeAccent;
        label = 'إجازة';
        break;
      case 'terminated':
        color = Colors.redAccent;
        label = 'لا يعمل';
        break;
      default:
        color = TfcColors.outline;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildConfirmationBadge(bool isConfirmed) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: (isConfirmed ? TfcColors.primary : Colors.orangeAccent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConfirmed ? Icons.verified : Icons.pending_outlined,
            size: 14,
            color: isConfirmed ? TfcColors.primary : Colors.orangeAccent,
          ),
          const SizedBox(width: 4),
          Text(
            isConfirmed ? 'مؤكد' : 'غير مؤكد',
            style: TextStyle(
              color: isConfirmed ? TfcColors.primary : Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the permissions panel for an employee (admin only)
  Future<void> _showPermissionsPanel(BuildContext context, Profile emp) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EmployeePermissionsPanel(employee: emp),
    );
    // Refresh employee list to reflect any permission changes
    ref.read(employeesProvider.notifier).fetchEmployees();
  }

  Future<void> _confirmEmployee(Profile emp) async {
    final success = await ref.read(employeesProvider.notifier).updateEmployee(
      profileId: emp.id,
      isConfirmed: true,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تأكيد حساب ${emp.fullName} بنجاح ✅', textAlign: TextAlign.right),
          backgroundColor: TfcColors.primary,
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, Profile emp) {
    final currentUser = ref.read(authProvider);
    final isUserAdmin = currentUser.role == 'admin';
    final isBankEmployee = emp.role == 'bank_employee';
    final showPhoneField = !isBankEmployee || isUserAdmin;
    final nameCtrl = TextEditingController(text: emp.fullName);
    final phoneCtrl = TextEditingController(text: emp.phoneNumber ?? '');
    final nationalIdCtrl = TextEditingController(text: emp.nationalId ?? '');
    final hiringDateCtrl = TextEditingController(
      text: emp.hiringDate != null
          ? '${emp.hiringDate!.year}-${emp.hiringDate!.month.toString().padLeft(2, '0')}-${emp.hiringDate!.day.toString().padLeft(2, '0')}'
          : '',
    );

    String selectedRole = emp.role;
    String selectedStatus = emp.employeeStatus;
    bool isConfirmed = emp.isConfirmed;
    String? selectedManagerId = emp.managerId;
    String? selectedBankName = emp.bankName;
    String? selectedBankEmployeeId = emp.bankEmployeeId;

    final allEmployees = ref.read(employeesProvider).employees;
    // Potential managers = admins and managers (excluding self)
    final potentialManagers = allEmployees
        .where((e) => (e.role == 'admin' || e.role == 'manager') && e.id != emp.id)
        .toList();

    final banksAsync = ref.watch(allBanksProvider);
    final bankList = banksAsync.value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: TfcColors.surfaceContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 520,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(Icons.edit_note_rounded, color: TfcColors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'تعديل بيانات الموظف',
                          style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: TfcColors.outline),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),

                    // Full Name
                    _dialogFieldLabel('الاسم الكامل'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      decoration: const InputDecoration(
                        hintText: 'اسم الموظف',
                        prefixIcon: Icon(Icons.person, color: TfcColors.outline),
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (showPhoneField) ...[
                      // Phone
                      _dialogFieldLabel('رقم الهاتف'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneCtrl,
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(
                          hintText: '05xxxxxxxx',
                          prefixIcon: Icon(Icons.phone, color: TfcColors.outline),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // National ID
                    _dialogFieldLabel('الرقم القومي'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nationalIdCtrl,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        hintText: 'الرقم القومي',
                        prefixIcon: Icon(Icons.badge, color: TfcColors.outline),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Hiring date
                    _dialogFieldLabel('تاريخ التعيين'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: hiringDateCtrl,
                      textAlign: TextAlign.right,
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: 'YYYY-MM-DD',
                        prefixIcon: Icon(Icons.calendar_today, color: TfcColors.outline),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: emp.hiringDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          hiringDateCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Role dropdown
                    _dialogFieldLabel('الوظيفة (الدور)'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        dropdownColor: TfcColors.surfaceContainer,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: Icon(Icons.admin_panel_settings, color: TfcColors.outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('أدمن', textDirection: TextDirection.rtl)),
                          DropdownMenuItem(value: 'manager', child: Text('مدير', textDirection: TextDirection.rtl)),
                          DropdownMenuItem(value: 'company_employee', child: Text('موظف شركة', textDirection: TextDirection.rtl)),
                          DropdownMenuItem(value: 'bank_employee', child: Text('موظف بنك', textDirection: TextDirection.rtl)),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedRole = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (selectedRole == 'bank_employee') ...[
                      // Bank dropdown
                      _dialogFieldLabel('البنك التابع له'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: bankList.any((b) => b['bank_name'] == selectedBankName) ? selectedBankName : null,
                          dropdownColor: TfcColors.surfaceContainer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.account_balance, color: TfcColors.outline),
                          ),
                          hint: const Text('اختر البنك التابع له الموظف', textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline)),
                          items: bankList.map((b) {
                            final name = b['bank_name'] as String;
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(name, textDirection: TextDirection.rtl),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setDialogState(() {
                              selectedBankName = v;
                              selectedBankEmployeeId = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bank Officer Selection (المسؤول الائتماني في البنك)
                      if (selectedBankName != null) ...[
                        _dialogFieldLabel('اسم الموظف المسؤول في البنك'),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            final matchingBank = bankList.firstWhere(
                              (b) => b['bank_name'] == selectedBankName,
                              orElse: () => <String, dynamic>{},
                            );
                            final bankEmployees = matchingBank['bank_employees'] as List<dynamic>? ?? [];

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: DropdownButtonFormField<String>(
                                initialValue: bankEmployees.any((e) => e['id'].toString() == selectedBankEmployeeId)
                                    ? selectedBankEmployeeId
                                    : null,
                                dropdownColor: TfcColors.surfaceContainer,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  prefixIcon: Icon(Icons.badge, color: TfcColors.primary),
                                ),
                                hint: const Text('اختر اسم المسؤول الائتماني بالبنك للربط', textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline)),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('إنشاء سجل مسؤول جديد تلقائياً باسم الموظف', textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline)),
                                  ),
                                  ...bankEmployees.map((e) {
                                    final id = e['id'].toString();
                                    final name = e['employee_name']?.toString() ?? 'بدون اسم';
                                    final phone = e['phone_1']?.toString() ?? '';
                                    return DropdownMenuItem<String>(
                                      value: id,
                                      child: Text(
                                        phone.isNotEmpty ? '$name ($phone)' : name,
                                        textDirection: TextDirection.rtl,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (v) {
                                  setDialogState(() {
                                    selectedBankEmployeeId = (v != null && v.isNotEmpty) ? v : null;
                                    if (v != null && v.isNotEmpty) {
                                      final matched = bankEmployees.firstWhere((e) => e['id'].toString() == v, orElse: () => null);
                                      if (matched != null && (matched['employee_name']?.toString().isNotEmpty ?? false)) {
                                        nameCtrl.text = matched['employee_name'].toString();
                                      }
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],

                    if (selectedRole == 'company_employee') ...[
                      // Manager dropdown
                      _dialogFieldLabel('المدير التابع له'),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: potentialManagers.any((m) => m.id == selectedManagerId) ? selectedManagerId : null,
                          dropdownColor: TfcColors.surfaceContainer,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            prefixIcon: Icon(Icons.supervisor_account, color: TfcColors.outline),
                          ),
                          hint: const Text('بدون مدير', textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline)),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('بدون مدير', textDirection: TextDirection.rtl),
                            ),
                            ...potentialManagers.map((m) => DropdownMenuItem(
                                  value: m.id,
                                  child: Text('${m.fullName} (${_getRoleLabel(m.role)})', textDirection: TextDirection.rtl),
                                )),
                          ],
                          onChanged: (v) {
                            setDialogState(() => selectedManagerId = v);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Status dropdown
                    _dialogFieldLabel('حالة الموظف'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        dropdownColor: TfcColors.surfaceContainer,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          prefixIcon: Icon(Icons.toggle_on, color: TfcColors.outline),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('نشط', textDirection: TextDirection.rtl)),
                          DropdownMenuItem(value: 'on_leave', child: Text('إجازة', textDirection: TextDirection.rtl)),
                          DropdownMenuItem(value: 'terminated', child: Text('لا يعمل', textDirection: TextDirection.rtl)),
                        ],
                        onChanged: (v) {
                          if (v != null) setDialogState(() => selectedStatus = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirmation toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(Icons.verified_user, color: TfcColors.primary, size: 20),
                          const SizedBox(width: 10),
                          const Text(
                            'تأكيد الحساب',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Switch(
                            value: isConfirmed,
                            activeThumbColor: TfcColors.primary,
                            onChanged: (v) => setDialogState(() => isConfirmed = v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Save button
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [TfcColors.primary, Color(0xFF00C9B7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: TfcColors.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final success = await ref.read(employeesProvider.notifier).updateEmployee(
                            profileId: emp.id,
                            fullName: nameCtrl.text.trim(),
                            phoneNumber: (!showPhoneField || selectedRole == 'bank_employee') ? null : phoneCtrl.text.trim(),
                            nationalId: nationalIdCtrl.text.trim(),
                            hiringDate: hiringDateCtrl.text.trim().isNotEmpty ? hiringDateCtrl.text.trim() : null,
                            role: selectedRole,
                            managerId: selectedManagerId,
                            employeeStatus: selectedStatus,
                            isConfirmed: isConfirmed,
                            bankName: selectedRole == 'bank_employee' ? selectedBankName : null,
                            bankEmployeeId: selectedRole == 'bank_employee' ? selectedBankEmployeeId : null,
                          );
                          if (success && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم تحديث بيانات ${nameCtrl.text.trim()} ✅', textAlign: TextAlign.right),
                                backgroundColor: TfcColors.primary,
                              ),
                            );
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(Icons.save_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'حفظ التعديلات',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dialogFieldLabel(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          label,
          style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'أدمن';
      case 'manager':
        return 'مدير';
      case 'company_employee':
        return 'موظف شركة';
      case 'bank_employee':
        return 'موظف بنك';
      default:
        return 'موظف';
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'manager':
        return Icons.manage_accounts;
      case 'company_employee':
        return Icons.business_center;
      case 'bank_employee':
        return Icons.account_balance;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFF6B6B);
      case 'manager':
        return TfcColors.secondary;
      case 'company_employee':
        return TfcColors.primary;
      case 'bank_employee':
        return Colors.blueAccent;
      default:
        return TfcColors.onSurface;
    }
  }
}

const _headerStyle = TextStyle(
  fontWeight: FontWeight.bold,
  color: TfcColors.primary,
  fontSize: 13,
);

/// Small filter chip widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int count;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.count,
    this.color = TfcColors.onSurface,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : TfcColors.outline,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? color : TfcColors.outline,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
