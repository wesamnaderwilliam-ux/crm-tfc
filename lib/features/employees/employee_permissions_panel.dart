// lib/features/employees/employee_permissions_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/employees_provider.dart';

/// Full permissions management panel opened from the employee profile card.
/// Admin-only — allows toggling any app section or field per employee.
class EmployeePermissionsPanel extends ConsumerStatefulWidget {
  final Profile employee;

  const EmployeePermissionsPanel({
    super.key,
    required this.employee,
  });

  @override
  ConsumerState<EmployeePermissionsPanel> createState() =>
      _EmployeePermissionsPanelState();
}

class _EmployeePermissionsPanelState
    extends ConsumerState<EmployeePermissionsPanel> {
  late Map<String, bool> _localPerms;
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    // Start from resolved permissions (role defaults + existing custom overrides)
    _localPerms = EmployeePermissionKeys.resolve(
      widget.employee.role,
      widget.employee.customPermissions,
    );
  }

  void _toggle(String key, bool value) {
    setState(() {
      _localPerms[key] = value;
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    // Only save the keys that DIFFER from role defaults
    final defaults = EmployeePermissionKeys.defaultsForRole(widget.employee.role);
    final Map<String, bool> customOverrides = {};
    _localPerms.forEach((k, v) {
      if (defaults[k] != v) customOverrides[k] = v;
    });

    final success = await ref
        .read(employeesProvider.notifier)
        .updateCustomPermissions(widget.employee.id, customOverrides);

    // Also update in-memory custom permissions provider
    if (success) {
      ref.read(employeeCustomPermissionsProvider.notifier).loadForEmployee(
            widget.employee.id,
            customOverrides,
          );
    }

    setState(() {
      _isSaving = false;
      _hasChanges = false;
    });

    if (mounted) {
      Navigator.of(context).pop(success);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'تم حفظ صلاحيات ${widget.employee.fullName} ✅'
                : 'فشل حفظ الصلاحيات ❌',
            textAlign: TextAlign.right,
          ),
          backgroundColor: success ? TfcColors.primary : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'إعادة تعيين الصلاحيات',
          textAlign: TextAlign.right,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'سيتم مسح جميع الصلاحيات المخصصة لـ ${widget.employee.fullName} وإعادتها لقيم الدور الافتراضية. هل أنت متأكد؟',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء', style: TextStyle(color: TfcColors.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);
      await ref
          .read(employeesProvider.notifier)
          .updateCustomPermissions(widget.employee.id, {});
      ref.read(employeeCustomPermissionsProvider.notifier).loadForEmployee(
            widget.employee.id,
            {},
          );
      setState(() {
        _localPerms = EmployeePermissionKeys.defaultsForRole(widget.employee.role);
        _isSaving = false;
        _hasChanges = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إعادة تعيين صلاحيات ${widget.employee.fullName} للافتراضية ✅',
              textAlign: TextAlign.right,
            ),
            backgroundColor: TfcColors.primary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.employee.role == 'admin';
    final defaults = EmployeePermissionKeys.defaultsForRole(widget.employee.role);
    final groups = EmployeePermissionKeys.uiGroups;

    // Count how many custom overrides exist
    final customCount = widget.employee.customPermissions.length;

    return Dialog(
      backgroundColor: TfcColors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 600,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(isAdmin, customCount),

            // ── Admin locked message ──
            if (isAdmin)
              _buildAdminLockedBanner()
            else ...[
              // ── Groups of Permissions ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: groups.length,
                  itemBuilder: (ctx, gi) {
                    final group = groups[gi];
                    return _buildGroup(group, defaults);
                  },
                ),
              ),
              // ── Action Buttons ──
              _buildActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAdmin, int customCount) {
    final roleColor = _getRoleColor(widget.employee.role);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: roleColor.withValues(alpha: 0.15),
            child: Icon(
              _getRoleIcon(widget.employee.role),
              size: 26,
              color: roleColor,
            ),
          ),
          const SizedBox(width: 14),
          // Name & role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  widget.employee.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _roleBadge(widget.employee.role),
                    if (customCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$customCount تخصيص',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Close
          IconButton(
            icon: const Icon(Icons.close, color: TfcColors.outline),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminLockedBanner() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_rounded, size: 48, color: Colors.amber),
              ),
              const SizedBox(height: 20),
              const Text(
                'صلاحيات الأدمن محمية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'لا يمكن تعديل صلاحيات حساب الأدمن. الأدمن يملك كامل الصلاحيات تلقائياً.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TfcColors.outline, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroup(PermissionGroup group, Map<String, bool> defaults) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Group title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(
                  _getIconData(group.icon),
                  size: 18,
                  color: TfcColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  group.title,
                  style: const TextStyle(
                    color: TfcColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          // Items
          ...group.items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final currentValue = _localPerms[item.key] ?? defaults[item.key] ?? true;
            final isDefault = !widget.employee.customPermissions.containsKey(item.key) &&
                (_localPerms[item.key] == (defaults[item.key] ?? true));
            final isCustomized = _localPerms[item.key] != (defaults[item.key] ?? true);

            return _buildPermissionTile(
              item: item,
              value: currentValue,
              isCustomized: isCustomized,
              isLast: idx == group.items.length - 1,
              isDefault: isDefault,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required PermissionItem item,
    required bool value,
    required bool isCustomized,
    required bool isLast,
    required bool isDefault,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isCustomized
            ? (value
                ? Colors.greenAccent.withValues(alpha: 0.04)
                : Colors.redAccent.withValues(alpha: 0.04))
            : Colors.transparent,
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : BorderRadius.zero,
      ),
      child: InkWell(
        borderRadius: isLast
            ? const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : BorderRadius.zero,
        onTap: () => _toggle(item.key, !value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: value
                      ? TfcColors.primary.withValues(alpha: 0.1)
                      : Colors.redAccent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconData(item.icon),
                  size: 16,
                  color: value ? TfcColors.primary : Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value ? Colors.white : TfcColors.outline,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    if (isCustomized)
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 10,
                            color: Colors.orangeAccent.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'مخصص',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orangeAccent.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Toggle Switch
              Switch(
                value: value,
                activeColor: TfcColors.primary,
                inactiveThumbColor: Colors.redAccent,
                inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.2),
                onChanged: (v) => _toggle(item.key, v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Save button
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: _hasChanges
                      ? [TfcColors.primary, const Color(0xFF00C9B7)]
                      : [TfcColors.outline.withValues(alpha: 0.3), TfcColors.outline.withValues(alpha: 0.3)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _hasChanges && !_isSaving ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ الصلاحيات',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Reset button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isSaving ? null : _resetToDefaults,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    final color = _getRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getRoleLabel(role),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
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

  IconData _getIconData(String name) {
    switch (name) {
      case 'dashboard':
      case 'analytics':
        return Icons.analytics_rounded;
      case 'people':
        return Icons.people_rounded;
      case 'person_add':
        return Icons.person_add_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'edit':
        return Icons.edit_rounded;
      case 'delete':
        return Icons.delete_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'note_add':
        return Icons.note_add_rounded;
      case 'phone':
        return Icons.phone_rounded;
      case 'badge':
        return Icons.badge_rounded;
      case 'cake':
        return Icons.cake_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'score':
        return Icons.bar_chart_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'folder':
        return Icons.folder_rounded;
      case 'manage_accounts':
        return Icons.manage_accounts_rounded;
      case 'assignment':
        return Icons.assignment_rounded;
      default:
        return Icons.toggle_on_rounded;
    }
  }
}
