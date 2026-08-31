import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/ai_provider.dart';
import '../../providers/prospects_provider.dart';
import '../../models/google_sheet_config_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final allPermissions = ref.watch(permissionsProvider);

    // Safe access with fallback defaults
    final companyPerms =
        allPermissions['company_employee'] ?? RolePermissions.fromDefaults('company_employee');
    final bankPerms =
        allPermissions['bank_employee'] ?? RolePermissions.fromDefaults('bank_employee');
    final hostPerms =
        allPermissions['host'] ?? RolePermissions.fromDefaults('host');
    final managerPerms =
        allPermissions['manager'] ?? RolePermissions.fromDefaults('manager');

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            const Text(
              "لوحة التحكم بالإعدادات والصلاحيات",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: TfcColors.primary),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 8),
            const Text(
              "تحكم في صلاحيات الفئات الوظيفية ومستويات الوصول إلى بيانات العملاء وحالات القروض",
              style: TextStyle(color: TfcColors.outline),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────
            // 0. User Profile & Password Security Card
            // ─────────────────────────────────────────────
            const _UserProfileSecurityCard(),
            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // 1. Simulator Switcher Card
            // ─────────────────────────────────────────────
            GlassCard(
              borderColor: TfcColors.secondary.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.psychology, color: TfcColors.secondary),
                      SizedBox(width: 12),
                      Text(
                        "محاكي تبديل الأدوار (للمعاينة السريعة)",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "اضغط على أي دور وظيفي أدناه لتقمص هويته واختبار كيف تتغير الواجهات والصلاحيات ديناميكياً في التطبيق:",
                    style: TextStyle(color: TfcColors.outline, fontSize: 13),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 20),

                  // Buttons Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      return GridView.count(
                        crossAxisCount: isMobile ? 2 : 5,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: isMobile ? 2.5 : 2.2,
                        children: [
                          _buildRoleSimButton(
                            ref: ref,
                            roleKey: 'admin',
                            label: "المدير (Admin)",
                            desc: "الصلاحيات الكاملة",
                            isActive: authState.role == 'admin',
                            color: Colors.redAccent,
                          ),
                          _buildRoleSimButton(
                            ref: ref,
                            roleKey: 'manager',
                            label: "المدير المسؤول",
                            desc: "كامل الصلاحيات والإعدادات",
                            isActive: authState.role == 'manager',
                            color: TfcColors.secondary,
                          ),
                          _buildRoleSimButton(
                            ref: ref,
                            roleKey: 'company_employee',
                            label: "موظف الشركة (المندوب)",
                            desc: "إدخال وتعديل البيانات الأساسية",
                            isActive: authState.role == 'company_employee',
                            color: TfcColors.primary,
                          ),
                          _buildRoleSimButton(
                            ref: ref,
                            roleKey: 'bank_employee',
                            label: "موظف البنك (المراجع)",
                            desc: "اعتماد القروض ومراجعة التقارير",
                            isActive: authState.role == 'bank_employee',
                            color: Colors.blueAccent,
                          ),
                          _buildRoleSimButton(
                            ref: ref,
                            roleKey: 'host',
                            label: "المضيف (Host)",
                            desc: "عرض البيانات فقط",
                            isActive: authState.role == 'host',
                            color: Colors.tealAccent,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────
            // 2. Permissions Matrix Table Card
            // ─────────────────────────────────────────────
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.security, color: TfcColors.primary, size: 22),
                const SizedBox(width: 8),
                const Text(
                  "جدول الصلاحيات النشط (Dynamic RBAC)",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                // Sync indicator
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: TfcColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: TfcColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, color: TfcColors.primary, size: 14),
                      SizedBox(width: 4),
                      Text("متصل بـ Supabase",
                          style: TextStyle(
                              color: TfcColors.primary, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.03)),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 64,
                  columnSpacing: 32,
                  columns: const [
                    DataColumn(
                        label: Text("اسم الصلاحية",
                            style: TextStyle(
                                color: TfcColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    DataColumn(
                        label: Text("موظف الشركة",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                    DataColumn(
                        label: Text("موظف البنك",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                    DataColumn(
                        label: Text("المضيف",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                    DataColumn(
                        label: Text("المدير المسؤول",
                            style: TextStyle(
                                color: TfcColors.secondary, fontSize: 13))),
                  ],
                  rows: [
                    _buildPermissionRow(
                      ref: ref,
                      label: "عرض بيانات العملاء",
                      icon: Icons.visibility,
                      permissionKey: "canViewClients",
                      companyVal: companyPerms.canViewClients,
                      bankVal: bankPerms.canViewClients,
                      hostVal: hostPerms.canViewClients,
                      managerVal: managerPerms.canViewClients,
                    ),
                    _buildPermissionRow(
                      ref: ref,
                      label: "إضافة وتعديل العملاء",
                      icon: Icons.edit,
                      permissionKey: "canEditClients",
                      companyVal: companyPerms.canEditClients,
                      bankVal: bankPerms.canEditClients,
                      hostVal: hostPerms.canEditClients,
                      managerVal: managerPerms.canEditClients,
                    ),
                    _buildPermissionRow(
                      ref: ref,
                      label: "حذف ملف العميل",
                      icon: Icons.delete_forever,
                      permissionKey: "canDeleteClients",
                      companyVal: companyPerms.canDeleteClients,
                      bankVal: bankPerms.canDeleteClients,
                      hostVal: hostPerms.canDeleteClients,
                      managerVal: managerPerms.canDeleteClients,
                    ),
                    _buildPermissionRow(
                      ref: ref,
                      label: "اعتماد حالة القروض",
                      icon: Icons.gavel,
                      permissionKey: "canApproveLoans",
                      companyVal: companyPerms.canApproveLoans,
                      bankVal: bankPerms.canApproveLoans,
                      hostVal: hostPerms.canApproveLoans,
                      managerVal: managerPerms.canApproveLoans,
                    ),
                    _buildPermissionRow(
                      ref: ref,
                      label: "عرض الإحصائيات",
                      icon: Icons.analytics,
                      permissionKey: "canViewAnalytics",
                      companyVal: companyPerms.canViewAnalytics,
                      bankVal: bankPerms.canViewAnalytics,
                      hostVal: hostPerms.canViewAnalytics,
                      managerVal: managerPerms.canViewAnalytics,
                    ),
                    _buildPermissionRow(
                      ref: ref,
                      label: "إدارة الأدوار",
                      icon: Icons.admin_panel_settings,
                      permissionKey: "canManageRoles",
                      companyVal: companyPerms.canManageRoles,
                      bankVal: bankPerms.canManageRoles,
                      hostVal: hostPerms.canManageRoles,
                      managerVal: managerPerms.canManageRoles,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "* ملاحظة: صلاحيات المدير المسؤول ثابتة ولا يمكن تعديلها لحماية أمان النظام الرئيسي.",
              style: TextStyle(color: TfcColors.outline, fontSize: 11),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 32),

            // ─────────────────────────────────────────────
            // 3. Field Visibility Section
            // ─────────────────────────────────────────────
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.visibility_off, color: TfcColors.secondary, size: 22),
                SizedBox(width: 8),
                Text(
                  "التحكم في رؤية حقول بيانات العملاء",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "حدد أي الحقول تظهر لكل دور وظيفي. التغييرات تُحفظ تلقائياً في قاعدة البيانات.",
              style: TextStyle(color: TfcColors.outline, fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.03)),
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  columnSpacing: 28,
                  columns: const [
                    DataColumn(
                        label: Text("الحقل",
                            style: TextStyle(
                                color: TfcColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                    DataColumn(
                        label: Text("موظف الشركة",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                    DataColumn(
                        label: Text("موظف البنك",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                    DataColumn(
                        label: Text("المضيف",
                            style: TextStyle(
                                color: TfcColors.primary, fontSize: 13))),
                  ],
                  rows: _buildFieldVisibilityRows(ref, companyPerms, bankPerms, hostPerms),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _AiSettingsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // Role Simulation Button
  // ───────────────────────────────────────────────
  Widget _buildRoleSimButton({
    required WidgetRef ref,
    required String roleKey,
    required String label,
    required String desc,
    required bool isActive,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        ref.read(authProvider.notifier).simulationChangeRole(roleKey);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.5 : 1,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive) ...[
                  Icon(Icons.check_circle, color: color, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isActive ? Colors.white : TfcColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(color: TfcColors.outline, fontSize: 10),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────
  // Permission Row (with icon + manager column)
  // ───────────────────────────────────────────────
  DataRow _buildPermissionRow({
    required WidgetRef ref,
    required String label,
    required IconData icon,
    required String permissionKey,
    required bool companyVal,
    required bool bankVal,
    required bool hostVal,
    required bool managerVal,
  }) {
    final notifier = ref.read(permissionsProvider.notifier);

    return DataRow(
      cells: [
        // Label with icon
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: TfcColors.outline),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
        // Company Checkbox
        DataCell(
          Center(
            child: Checkbox(
              value: companyVal,
              activeColor: TfcColors.primary,
              onChanged: (val) {
                if (val != null) {
                  notifier.togglePermission(
                      'company_employee', permissionKey, val);
                }
              },
            ),
          ),
        ),
        // Bank Checkbox
        DataCell(
          Center(
            child: Checkbox(
              value: bankVal,
              activeColor: TfcColors.primary,
              onChanged: (val) {
                if (val != null) {
                  notifier.togglePermission(
                      'bank_employee', permissionKey, val);
                }
              },
            ),
          ),
        ),
        // Host Checkbox
        DataCell(
          Center(
            child: Checkbox(
              value: hostVal,
              activeColor: TfcColors.primary,
              onChanged: (val) {
                if (val != null) {
                  notifier.togglePermission(
                      'host', permissionKey, val);
                }
              },
            ),
          ),
        ),
        // Manager fixed checkbox (read-only)
        DataCell(
          Center(
            child: Checkbox(
              value: managerVal,
              activeColor: TfcColors.secondary,
              onChanged: null, // Read-only
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────
  // Field Visibility Rows
  // ───────────────────────────────────────────────
  static const Map<String, String> _fieldLabels = {
    'phone': 'رقم الهاتف',
    'nationalId': 'الرقم الوطني',
    'birthDate': 'تاريخ الميلاد',
    'employment': 'بيانات التوظيف',
    'salary': 'بيانات الراتب',
    'creditScore': 'درجة الائتمان',
    'loans': 'القروض القائمة',
    'cards': 'البطاقات الائتمانية',
    'documents': 'المستندات',
  };

  static const Map<String, IconData> _fieldIcons = {
    'phone': Icons.phone,
    'nationalId': Icons.badge,
    'birthDate': Icons.cake,
    'employment': Icons.work,
    'salary': Icons.attach_money,
    'creditScore': Icons.score,
    'loans': Icons.account_balance,
    'cards': Icons.credit_card,
    'documents': Icons.folder,
  };

  List<DataRow> _buildFieldVisibilityRows(
      WidgetRef ref, RolePermissions companyPerms, RolePermissions bankPerms, RolePermissions hostPerms) {
    final notifier = ref.read(permissionsProvider.notifier);

    return _fieldLabels.entries.map((entry) {
      final key = entry.key;
      final label = entry.value;
      final icon = _fieldIcons[key] ?? Icons.info;

      final companyVisible = companyPerms.fieldVisibility[key] ?? true;
      final bankVisible = bankPerms.fieldVisibility[key] ?? true;
      final hostVisible = hostPerms.fieldVisibility[key] ?? true;

      return DataRow(
        cells: [
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: TfcColors.outline),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12)),
              ],
            ),
          ),
          DataCell(
            Center(
              child: Switch(
                value: companyVisible,
                activeThumbColor: TfcColors.primary,
                onChanged: (val) {
                  notifier.toggleFieldVisibility(
                      'company_employee', key, val);
                },
              ),
            ),
          ),
          DataCell(
            Center(
              child: Switch(
                value: bankVisible,
                activeThumbColor: TfcColors.primary,
                onChanged: (val) {
                  notifier.toggleFieldVisibility('bank_employee', key, val);
                },
              ),
            ),
          ),
          DataCell(
            Center(
              child: Switch(
                value: hostVisible,
                activeThumbColor: TfcColors.primary,
                onChanged: (val) {
                  notifier.toggleFieldVisibility('host', key, val);
                },
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

class _AiSettingsCard extends ConsumerStatefulWidget {
  const _AiSettingsCard();

  @override
  ConsumerState<_AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends ConsumerState<_AiSettingsCard> {
  late TextEditingController _apiKeyController;
  late TextEditingController _rulesController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
    _rulesController = TextEditingController(text: settings.matchingRules);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        borderColor: TfcColors.primary.withValues(alpha: 0.15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: TfcColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  "تهيئة إعدادات المساعد الذكي (AI)",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "قم بضبط حقول مفاتيح الوصول وقواعد الموازنة الائتمانية ليقوم الذكاء الاصطناعي باتباعها أثناء تقييم طلبات التمويل.",
              style: TextStyle(color: TfcColors.outline, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Model Selector Dropdown
            const Text("الموديل المستخدم لـ Gemini API", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.model,
                  isExpanded: true,
                  dropdownColor: TfcColors.surfaceDim,
                  items: const [
                    DropdownMenuItem(value: 'gemini-1.5-flash', child: Text("Gemini 1.5 Flash (سريع واقتصادي)")),
                    DropdownMenuItem(value: 'gemini-1.5-pro', child: Text("Gemini 1.5 Pro (ذكي ودقيق للتحليلات الكبرى)")),
                    DropdownMenuItem(value: 'gemini-2.0-flash', child: Text("Gemini 2.0 Flash")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(aiSettingsProvider.notifier).setModel(val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // API Key
            const Text("Gemini API Key", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: "أدخل مفتاح Gemini API هنا...",
                prefixIcon: const Icon(Icons.key, size: 18, color: TfcColors.outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility, size: 18),
                  onPressed: () {
                    setState(() {
                      _obscureKey = !_obscureKey;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Matching Rules Textfield
            const Text("قواعد التوزيع ومطابقة البرامج (System Prompt Instructions)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _rulesController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: "أدخل شروط البنوك وقواعد الـ DTI والمعايير المعتمدة في مكتبك هنا...",
              ),
            ),
            const SizedBox(height: 24),

            // Save Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final key = _apiKeyController.text.trim();
                    final rules = _rulesController.text.trim();
                    
                    await ref.read(aiSettingsProvider.notifier).saveAllSettings(
                      apiKey: key,
                      model: settings.model,
                      matchingRules: rules,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ تم حفظ وتفعيل إعدادات المساعد الائتماني لكل مستخدمي النظام بنجاح", textAlign: TextAlign.right),
                          backgroundColor: TfcColors.success,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text("حفظ الإعدادات"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 12),
                if (settings.apiKey.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      "⚠️ يعمل المساعد حالياً في وضع المحاكاة الذاتية لعدم إدخال مفتاح الـ API",
                      style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            // ─────────────────────────────────────────────
            // 7. Google Sheets Settings Card (Admin Only)
            // ─────────────────────────────────────────────
            if (ref.watch(authProvider).role == 'admin') ...[
              const SizedBox(height: 24),
              const _GoogleSheetsSettingsCard(),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Google Sheets Integration Settings Card (Admin Only)
// ─────────────────────────────────────────────
class _GoogleSheetsSettingsCard extends ConsumerStatefulWidget {
  const _GoogleSheetsSettingsCard();

  @override
  ConsumerState<_GoogleSheetsSettingsCard> createState() => __GoogleSheetsSettingsCardState();
}

class __GoogleSheetsSettingsCardState extends ConsumerState<_GoogleSheetsSettingsCard>
    with SingleTickerProviderStateMixin {
  late TextEditingController _urlController;
  late TextEditingController _prospectUrlController;
  List<String> _detectedHeaders = [];
  List<String> _detectedProspectHeaders = [];
  Map<String, String> _mappings = {};
  Map<String, String> _prospectMappings = {};
  bool _isLoadingHeaders = false;
  bool _isLoadingProspectHeaders = false;
  late TabController _tabController;

  // ─── حقول العملاء العاديين ───
  final Map<String, String> _targetClientFields = {
    'full_name': '👤 [بيانات شخصية] الاسم الكامل للعميل',
    'phone_number': '📞 [بيانات شخصية] رقم الهاتف الرئيسي',
    'secondary_phone_number': '📱 [بيانات شخصية] رقم الهاتف الإضافي',
    'national_id': '🪪 [بيانات شخصية] الرقم القومي (14 رقم)',
    'birth_date': '📅 [بيانات شخصية] تاريخ الميلاد',
    'governorate': '📍 [بيانات شخصية] المحافظة والمنطقة',
    'employment_type': '💼 [بيانات وظيفية] نوع وطبيعة العمل',
    'company_name': '🏢 [بيانات وظيفية] جهة العمل / الشركة',
    'job_title': '👔 [بيانات وظيفية] المسمى الوظيفي',
    'is_insured': '🛡️ [بيانات وظيفية] مؤمن عليه (نعم / لا)',
    'salary_transfer_method': '🏦 [بيانات وظيفية] طريقة تحويل الراتب',
    'cash_salary_amount': '💵 [بيانات وظيفية] مفصل الراتب / الدخل المالي',
    'salary_bank_name': '🏦 [تفاصيل بنك الراتب] اسم البنك',
    'salary_bank_amount': '💰 [تفاصيل بنك الراتب] قيمة المبلغ المحول',
    'business_legal_entity': '⚖️ [أعمال خاصة] الكيان القانوني',
    'business_activity_type': '🏭 [أعمال خاصة] نوع النشاط التجاري',
    'company_start_date': '📅 [أعمال خاصة] تاريخ تأسيس النشاط',
    'commercial_register_age': '📑 [أعمال خاصة] عمر السجل التجاري',
    'has_tax_card': '💳 [أعمال خاصة] وجود بطاقة ضريبية',
    'credit_score': '📊 [بيانات ائتمانية] التقييم الائتماني (I-Score)',
    'requested_amount': '💰 [بيانات ائتمانية] مبلغ التمويل المطلوب',
    'representative_name': '👨‍💼 [بيانات ائتمانية] المندوب المسؤول',
    'status': '📌 [حالة العميل] حالة الطلب الحالية',
    'loan_bank_name': '🏦 [قرض قائم] اسم البنك',
    'loan_original_amount': '💰 [قرض قائم] إجمالي مبلغ القرض',
    'loan_monthly_installment': '💵 [قرض قائم] القسط الشهري',
    'loan_remaining_balance': '📉 [قرض قائم] الرصيد المتبقي',
    'card_bank_name': '💳 [بطاقة ائتمان] اسم البنك المصدر',
    'card_limit': '💎 [بطاقة ائتمان] الحد الائتماني',
    'card_monthly_installment': '💵 [بطاقة ائتمان] القسط الشهري',
    'notes': '📝 [ملاحظات] التفاصيل والملاحظات الإضافية',
  };

  // ─── حقول العملاء المحتملين ───
  final Map<String, String> _targetProspectFields = {
    'full_name': '👤 الاسم الكامل للعميل المحتمل',
    'phone_number': '📞 رقم الهاتف الرئيسي',
    'secondary_phone_number': '📱 رقم الهاتف الإضافي',
    'national_id': '🪪 الرقم القومي',
    'governorate': '📍 المحافظة',
    'job_title': '👔 المسمى الوظيفي',
    'company_name': '🏢 جهة العمل / الشركة',
    'salary_amount': '💰 الراتب / الدخل الشهري',
    'notes': '📝 ملاحظات',
    'assigned_to_name': '👨‍💼 اسم الموظف المسند إليه',
    'status': '📌 الحالة (pending / contacted / converted)',
  };

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _prospectUrlController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _prospectUrlController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(googleSheetConfigProvider);
    final config = configState.value;

    if (config != null) {
      if (_urlController.text.isEmpty && config.sheetUrl.isNotEmpty) {
        _urlController.text = config.sheetUrl;
        _mappings = Map.from(config.fieldMappings);
      }
      if (_prospectUrlController.text.isEmpty && config.prospectSheetUrl.isNotEmpty) {
        _prospectUrlController.text = config.prospectSheetUrl;
        _prospectMappings = Map.from(config.prospectFieldMappings);
      }
    }

    return GlassCard(
      borderColor: TfcColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.table_chart, color: TfcColors.primary),
              SizedBox(width: 12),
              Text(
                "ربط وتعيين حقول Google Sheet (خاص بالمسؤول)",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "ضع رابط شيت جوجل وقم بربط كل عمود بالحقل المناسب له:",
            style: TextStyle(color: TfcColors.outline, fontSize: 13),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: TfcColors.outline,
              indicator: BoxDecoration(
                color: TfcColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorPadding: const EdgeInsets.all(4),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 16),
                      SizedBox(width: 6),
                      Text("العملاء"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search, size: 16),
                      SizedBox(width: 6),
                      Text("العملاء المحتملين"),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Views
          SizedBox(
            height: 600,
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── Tab 1: العملاء ──
                _buildSheetTab(
                  urlController: _urlController,
                  detectedHeaders: _detectedHeaders,
                  mappings: _mappings,
                  targetFields: _targetClientFields,
                  isLoading: _isLoadingHeaders,
                  onFetch: _fetchHeaders,
                  onMappingChanged: (header, val) {
                    setState(() {
                      if (val == null) {
                        _mappings.remove(header);
                      } else {
                        _mappings[header] = val;
                      }
                    });
                  },
                ),
                // ── Tab 2: العملاء المحتملين ──
                _buildSheetTab(
                  urlController: _prospectUrlController,
                  detectedHeaders: _detectedProspectHeaders,
                  mappings: _prospectMappings,
                  targetFields: _targetProspectFields,
                  isLoading: _isLoadingProspectHeaders,
                  onFetch: _fetchProspectHeaders,
                  onMappingChanged: (header, val) {
                    setState(() {
                      if (val == null) {
                        _prospectMappings.remove(header);
                      } else {
                        _prospectMappings[header] = val;
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Save Button
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saveGoogleSheetConfig,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text("حفظ جميع إعدادات Google Sheet"),
              style: ElevatedButton.styleFrom(
                backgroundColor: TfcColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetTab({
    required TextEditingController urlController,
    required List<String> detectedHeaders,
    required Map<String, String> mappings,
    required Map<String, String> targetFields,
    required bool isLoading,
    required VoidCallback onFetch,
    required void Function(String header, String? val) onMappingChanged,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // URL Input & Fetch Button
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "رابط Google Sheet (أو رابط النشر كـ CSV)",
                    hintText: "https://docs.google.com/spreadsheets/d/...",
                    prefixIcon: Icon(Icons.link, size: 18, color: TfcColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: isLoading ? null : onFetch,
                icon: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download, size: 18),
                label: const Text("جلب الحقول"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TfcColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Field Mappings
          if (detectedHeaders.isNotEmpty || mappings.isNotEmpty) ...[
            const Text(
              "تعيين حقول الشيت بأعمدة الجدول المناسبة:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: TfcColors.primary),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: (detectedHeaders.isNotEmpty ? detectedHeaders : mappings.keys.toList()).map((header) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            header,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.arrow_forward, color: TfcColors.primary, size: 16),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: mappings[header],
                            dropdownColor: const Color(0xFF1E2430),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('-- عدم الربط --', style: TextStyle(color: Colors.white38)),
                              ),
                              ...targetFields.entries.map((e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (val) => onMappingChanged(header, val),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.table_chart_outlined, color: TfcColors.outline, size: 36),
                  SizedBox(height: 8),
                  Text(
                    "أدخل رابط الشيت واضغط \"جلب الحقول\" لعرض أعمدة الشيت وربطها",
                    style: TextStyle(color: TfcColors.outline, fontSize: 13),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<void> _fetchHeaders() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال رابط Google Sheet أولاً")),
      );
      return;
    }
    setState(() => _isLoadingHeaders = true);
    final headers = await ref.read(googleSheetConfigProvider.notifier).fetchSheetHeaders(url);
    setState(() {
      _isLoadingHeaders = false;
      _detectedHeaders = headers;
      for (final h in headers) {
        final lower = h.toLowerCase();
        if (lower.contains('اسم') || lower.contains('name')) _mappings[h] = 'full_name';
        if (lower.contains('هاتف') || lower.contains('موبايل') || lower.contains('phone')) _mappings[h] = 'phone_number';
        if (lower.contains('شركة') || lower.contains('جهة') || lower.contains('company')) _mappings[h] = 'company_name';
        if (lower.contains('وظيفة') || lower.contains('job') || lower.contains('title')) _mappings[h] = 'job_title';
        if (lower.contains('محافظة') || lower.contains('gov')) _mappings[h] = 'governorate';
        if (lower.contains('مرتب') || lower.contains('دخل') || lower.contains('salary')) _mappings[h] = 'cash_salary_amount';
      }
    });
    if (headers.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لم نتمكن من قراءة الحقول. تأكد أن الشيت منشور ومتاح للعموم")),
      );
    }
  }

  Future<void> _fetchProspectHeaders() async {
    final url = _prospectUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال رابط Google Sheet أولاً")),
      );
      return;
    }
    setState(() => _isLoadingProspectHeaders = true);
    final headers = await ref.read(googleSheetConfigProvider.notifier).fetchSheetHeaders(url);
    setState(() {
      _isLoadingProspectHeaders = false;
      _detectedProspectHeaders = headers;
      for (final h in headers) {
        final lower = h.toLowerCase();
        if (lower.contains('اسم') || lower.contains('name')) _prospectMappings[h] = 'full_name';
        if (lower.contains('هاتف') || lower.contains('موبايل') || lower.contains('phone')) _prospectMappings[h] = 'phone_number';
        if (lower.contains('شركة') || lower.contains('جهة') || lower.contains('company')) _prospectMappings[h] = 'company_name';
        if (lower.contains('وظيفة') || lower.contains('job') || lower.contains('title')) _prospectMappings[h] = 'job_title';
        if (lower.contains('محافظة') || lower.contains('gov')) _prospectMappings[h] = 'governorate';
        if (lower.contains('مرتب') || lower.contains('دخل') || lower.contains('salary')) _prospectMappings[h] = 'salary_amount';
        if (lower.contains('ملاحظة') || lower.contains('note')) _prospectMappings[h] = 'notes';
      }
    });
    if (headers.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لم نتمكن من قراءة الحقول. تأكد أن الشيت منشور ومتاح للعموم")),
      );
    }
  }

  Future<void> _saveGoogleSheetConfig() async {
    final url = _urlController.text.trim();
    final prospectUrl = _prospectUrlController.text.trim();
    if (url.isEmpty && prospectUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("يرجى إدخال رابط Google Sheet على الأقل في أحد التبويبين")),
      );
      return;
    }

    final config = GoogleSheetConfigModel(
      sheetUrl: url,
      fieldMappings: _mappings,
      prospectSheetUrl: prospectUrl,
      prospectFieldMappings: _prospectMappings,
      lastSyncedAt: DateTime.now(),
    );

    final success = await ref.read(googleSheetConfigProvider.notifier).saveConfig(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "✅ تم حفظ إعدادات ربط Google Sheet بنجاح" : "حدث خطأ أثناء الحفظ"),
          backgroundColor: success ? TfcColors.success : Colors.red,
        ),
      );
    }
  }
}



// ─────────────────────────────────────────────────────────────────────────────
// USER PROFILE & PASSWORD MANAGEMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _UserProfileSecurityCard extends ConsumerStatefulWidget {
  const _UserProfileSecurityCard();

  @override
  ConsumerState<_UserProfileSecurityCard> createState() => _UserProfileSecurityCardState();
}

class _UserProfileSecurityCardState extends ConsumerState<_UserProfileSecurityCard> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).updatePassword(
      _passwordController.text.trim(),
    );

    if (mounted) {
      if (success) {
        _passwordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تم تحديث وحفظ كلمة المرور بنجاح! 🔒✅", textAlign: TextAlign.right),
            backgroundColor: TfcColors.primary,
          ),
        );
      } else {
        final error = ref.read(authProvider).errorMessage ?? "فشل حفظ كلمة المرور";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error, textAlign: TextAlign.right),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final isGoogleUser = user?.appMetadata['provider'] == 'google' ||
        (user?.identities?.any((id) => id.provider == 'google') ?? false);

    return GlassCard(
      borderColor: TfcColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.manage_accounts, color: TfcColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "الملف الشخصي وأمان الحساب",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "إدارة بيانات الحساب وتعيين كلمة المرور الحاصة بك",
                    style: TextStyle(color: TfcColors.outline, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // User Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: TfcColors.primary.withValues(alpha: 0.2),
                  child: Text(
                    authState.fullName.isNotEmpty ? authState.fullName[0] : 'U',
                    style: const TextStyle(
                      color: TfcColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isGoogleUser)
                            Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("G ", style: TextStyle(color: Color(0xFF4285F4), fontWeight: FontWeight.bold, fontSize: 11)),
                                  Text("حساب Google", style: TextStyle(color: Color(0xFF4285F4), fontSize: 11)),
                                ],
                              ),
                            ),
                          Text(
                            authState.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? 'لا يوجد بريد إلكتروني مسجل',
                        style: const TextStyle(color: TfcColors.outline, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Password Update Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      isGoogleUser
                          ? "تعيين/تغيير كلمة مرور للحساب"
                          : "تعديل كلمة المرور",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: TfcColors.primary),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.lock_outline, color: TfcColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isGoogleUser
                      ? "يمكنك إنشاء كلمة مرور خاصة بحسابك حتى تتمكن من تسجيل الدخول سواء بـ Google أو بالبريد الإلكتروني مباشرة"
                      : "أدخل كلمة المرور الجديدة لحفظها وتحديث حماية حسابك",
                  style: const TextStyle(color: TfcColors.outline, fontSize: 12),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 16),

                // New Password Input
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: "كلمة المرور الجديدة",
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.key, color: TfcColors.outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: TfcColors.outline,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "يرجى إدخال كلمة المرور الجديدة";
                    }
                    if (value.trim().length < 6) {
                      return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password Input
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: "تأكيد كلمة المرور الجديدة",
                    hintText: "••••••••",
                    prefixIcon: const Icon(Icons.lock_reset, color: TfcColors.outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        color: TfcColors.outline,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "يرجى تأكيد كلمة المرور";
                    }
                    if (value.trim() != _passwordController.text.trim()) {
                      return "كلمتا المرور غير متطابقتين";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Save Password Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TfcColors.primary,
                      foregroundColor: TfcColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: authState.isLoading ? null : _handleUpdatePassword,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TfcColors.onPrimary),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "حفظ وتحديث كلمة المرور",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.save_outlined, size: 18),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


