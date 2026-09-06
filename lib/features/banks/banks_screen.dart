import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/banks_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/employees_provider.dart';

class BanksScreen extends ConsumerWidget {
  const BanksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banksAsync = ref.watch(allBanksProvider);
    final selectedBankId = ref.watch(selectedBankIdProvider);
    final searchQuery = ref.watch(banksSearchQueryProvider);
    final authState = ref.watch(authProvider);
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);
    final userId = authState.user?.id ?? '';
    final role = authState.role;
    // Resolve effective permissions for this user
    final effectivePerms = (role == 'admin' || role == 'manager')
        ? EmployeePermissionKeys.defaultsForRole('admin')
        : EmployeePermissionKeys.resolve(role, customPermsState[userId] ?? {});
    final isUserStrictAdmin = (role == 'admin' || authState.user?.email?.toLowerCase() == 'wezonader@gmail.com');
    final isAdmin = isUserStrictAdmin || (effectivePerms[EmployeePermissionKeys.manageBanks] ?? false);
    // Strict requirement: Only system Admin can view bank employee phones and contacts
    final canViewBankPhones = isUserStrictAdmin;
    final isBankEmployee = role == 'bank_employee';
    final userBankName = authState.bankName;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: banksAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: TfcColors.primary),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                "حدث خطأ أثناء تحميل البيانات: $err",
                style: const TextStyle(color: TfcColors.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (banks) {
          // If user is a bank employee, filter to only their bank
          final visibleBanks = isBankEmployee && userBankName != null
              ? banks.where((b) => (b['bank_name'] ?? '').toString() == userBankName).toList()
              : banks;

          // Filter banks list based on search query with Arabic normalization
          final filteredBanks = visibleBanks.where((bank) {
            if (searchQuery.isEmpty) return true;
            
            final query = _normalizeArabic(searchQuery.trim().toLowerCase());
            if (query.isEmpty) return true;
            
            // Match bank name
            final bankName = _normalizeArabic((bank['bank_name'] ?? '').toString().toLowerCase());
            if (bankName.contains(query)) return true;
            
            // Match nested programs
            final programs = bank['bank_programs_details'] as List<dynamic>? ?? [];
            for (var prog in programs) {
              final desc = _normalizeArabic((prog['description'] ?? '').toString().toLowerCase());
              final coreProg = prog['core_programs'] as Map<String, dynamic>?;
              final progName = _normalizeArabic((coreProg?['program_name'] ?? '').toString().toLowerCase());
              if (desc.contains(query) || progName.contains(query)) return true;
            }
            
            // Match nested employees
            final employees = bank['bank_employees'] as List<dynamic>? ?? [];
            for (var emp in employees) {
              final name = _normalizeArabic((emp['employee_name'] ?? '').toString().toLowerCase());
              final phone1 = _normalizeArabic((emp['phone_1'] ?? '').toString().toLowerCase());
              final phone2 = _normalizeArabic((emp['phone_2'] ?? '').toString().toLowerCase());
              final title = _normalizeArabic((emp['job_title'] ?? '').toString().toLowerCase());
              final email = _normalizeArabic((emp['email'] ?? '').toString().toLowerCase());
              final notes = _normalizeArabic((emp['notes'] ?? '').toString().toLowerCase());
              
              if (name.contains(query) || title.contains(query)) {
                return true;
              }
              if (canViewBankPhones) {
                if (phone1.contains(query) ||
                    phone2.contains(query) ||
                    email.contains(query) ||
                    notes.contains(query)) {
                  return true;
                }
              }
            }
            
            return false;
          }).toList();

          // Auto-select first bank of filtered list if none selected
          if (selectedBankId == null && filteredBanks.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedBankIdProvider.notifier).state = filteredBanks[0]['id'];
            });
          }

          // Ensure selected bank still exists in visible bank list
          final hasSelectedBank = visibleBanks.any((b) => b['id'] == selectedBankId);
          if (!hasSelectedBank && visibleBanks.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedBankIdProvider.notifier).state = visibleBanks[0]['id'];
            });
          }

          final selectedBankData = visibleBanks.firstWhere(
            (b) => b['id'] == selectedBankId,
            orElse: () => <String, dynamic>{},
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;

              if (isDesktop) {
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Sidebar on the right (Bank List & Search)
                      SizedBox(
                        width: 320,
                        child: GlassCard(
                          padding: const EdgeInsets.all(16),
                          borderColor: Colors.white.withValues(alpha: 0.04),
                          fillColor: TfcColors.surfaceDim.withValues(alpha: 0.4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "البنوك المعتمدة",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: TfcColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSearchField(ref),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white10),
                              const SizedBox(height: 8),
                              Expanded(
                                child: filteredBanks.isEmpty
                                    ? const Center(
                                        child: Text(
                                          "لا توجد نتائج مطابقة لبحثك.",
                                          style: TextStyle(color: TfcColors.outline, fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredBanks.length,
                                        itemBuilder: (context, index) {
                                          final bank = filteredBanks[index];
                                          final isSelected = selectedBankId == bank['id'];
                                          return _buildBankListTile(
                                            context,
                                            ref,
                                            bank: bank,
                                            isSelected: isSelected,
                                            isAdmin: isAdmin,
                                            onTap: () {
                                              ref.read(selectedBankIdProvider.notifier).state = bank['id'];
                                            },
                                          );
                                        },
                                      ),
                                ),
                              isAdmin
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                                          foregroundColor: TfcColors.primary,
                                          side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.2)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: const Icon(Icons.add_circle, size: 16),
                                        label: const Text("إضافة بنك جديد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        onPressed: () => _showBankFormDialog(context, ref),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 2. Details view on the left
                      Expanded(
                        child: selectedBankId != null && selectedBankData.isNotEmpty
                            ? _BankDetailsPanel(
                                bankData: selectedBankData,
                                isAdmin: isAdmin,
                                isBankEmployee: isBankEmployee,
                                canViewBankPhones: canViewBankPhones,
                              )
                            : const Center(
                                child: Text(
                                  "يرجى اختيار أو إضافة بنك لعرض التفاصيل",
                                  style: TextStyle(color: TfcColors.outline),
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile Layout: Simple List of banks, pushes to details view
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, left: 14, right: 14),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "دليل البنوك والبرامج",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: TfcColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: _buildSearchField(ref),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredBanks.isEmpty
                        ? const Center(
                            child: Text(
                              "لا توجد نتائج مطابقة لبحثك.",
                              style: TextStyle(color: TfcColors.outline),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredBanks.length,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            itemBuilder: (context, index) {
                              final bank = filteredBanks[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: _buildBankListTile(
                                  context,
                                  ref,
                                  bank: bank,
                                  isSelected: false,
                                  isAdmin: isAdmin,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => _MobileBankDetailsScreen(
                                          bankId: bank['id'],
                                          isAdmin: isAdmin,
                                          canViewBankPhones: canViewBankPhones,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  if (isAdmin)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                          foregroundColor: TfcColors.primary,
                          side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text("إضافة بنك جديد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        onPressed: () => _showBankFormDialog(context, ref),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSearchField(WidgetRef ref) {
    return const BankSearchField();
  }

  Widget _buildBankListTile(
    BuildContext context,
    WidgetRef ref, {
    required Map<String, dynamic> bank,
    required bool isSelected,
    required bool isAdmin,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          backgroundColor: isSelected
              ? TfcColors.primary.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.02),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? TfcColors.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        onPressed: onTap,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? TfcColors.primary.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.account_balance,
                color: isSelected ? TfcColors.primary : TfcColors.outline,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    bank['bank_name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : TfcColors.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "عدد البرامج: ${(bank['bank_programs_details'] as List?)?.length ?? 0}",
                    style: const TextStyle(color: TfcColors.outline, fontSize: 10),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            if (isAdmin) ...[
              IconButton(
                icon: const Icon(Icons.edit, size: 16, color: TfcColors.primary),
                onPressed: () => _showBankFormDialog(context, ref, bank: bank),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "تعديل اسم البنك",
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                onPressed: () => _confirmDeleteBank(context, ref, bank),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: "حذف البنك",
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_left,
              color: isSelected ? TfcColors.primary : TfcColors.outline,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG: Add/Edit Bank
  void _showBankFormDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? bank}) {
    final nameController = TextEditingController(text: bank?['bank_name'] ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: Text(
              bank == null ? "إضافة بنك جديد" : "تعديل اسم البنك",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: "اسم البنك",
                  labelStyle: TextStyle(color: TfcColors.outline),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "الرجاء إدخال اسم البنك";
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TfcColors.primary,
                  foregroundColor: TfcColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    final repo = ref.read(banksRepositoryProvider);
                    if (bank == null) {
                      final newBank = await repo.createBank(nameController.text.trim());
                      ref.read(selectedBankIdProvider.notifier).state = newBank['id'];
                    } else {
                      await repo.updateBank(bank['id'], nameController.text.trim());
                    }
                    ref.invalidate(allBanksProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(bank == null ? "تم إضافة البنك بنجاح" : "تم تعديل اسم البنك بنجاح", style: const TextStyle(fontWeight: FontWeight.bold)),
                          backgroundColor: TfcColors.primary,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: Text(bank == null ? "إضافة" : "حفظ"),
              ),
            ],
          ),
        );
      },
    );
  }

  // DIALOG: Confirm Delete Bank
  void _confirmDeleteBank(BuildContext context, WidgetRef ref, Map<String, dynamic> bank) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Text(
              "هل أنت متأكد من حذف البنك \"${bank['bank_name']}\"؟ سيؤدي ذلك لحذف كافة البرامج والموظفين التابعين له نهائياً.",
              style: const TextStyle(color: TfcColors.outline, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  try {
                    final repo = ref.read(banksRepositoryProvider);
                    await repo.deleteBank(bank['id']);
                    ref.invalidate(allBanksProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم حذف البنك وكافة بياناته بنجاح"), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: const Text("حذف"),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// WIDGET: BANK DETAILS PANEL (DESKTOP SPLIT VIEW / TABBED CARD)
// =========================================================================

class _BankDetailsPanel extends ConsumerStatefulWidget {
  final Map<String, dynamic> bankData;
  final bool isAdmin;
  final bool isBankEmployee;
  final bool canViewBankPhones;

  const _BankDetailsPanel({
    required this.bankData,
    required this.isAdmin,
    this.isBankEmployee = false,
    this.canViewBankPhones = true,
  });

  @override
  ConsumerState<_BankDetailsPanel> createState() => _BankDetailsPanelState();
}

class _BankDetailsPanelState extends ConsumerState<_BankDetailsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _BankDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bankData['id'] != widget.bankData['id']) {
      _tabController.index = 0;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bankName = widget.bankData['bank_name'] ?? '';
    final programs = widget.bankData['bank_programs_details'] as List? ?? [];
    final employees = widget.bankData['bank_employees'] as List? ?? [];

    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: Colors.white.withValues(alpha: 0.05),
      fillColor: TfcColors.surfaceDim.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bank Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TfcColors.primary.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
              border: const Border(
                bottom: BorderSide(color: Colors.white10),
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TfcColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: TfcColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.account_balance,
                    color: TfcColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        bankName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "تفاصيل البرامج الائتمانية المعتمدة ومسؤولي التنسيق المباشرين",
                        style: TextStyle(color: TfcColors.outline, fontSize: 12),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (widget.isAdmin) ...[
            TabBar(
              controller: _tabController,
              indicatorColor: TfcColors.primary,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: TfcColors.primary,
              unselectedLabelColor: TfcColors.outline,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_turned_in, size: 18),
                  text: "البرامج الائتمانية والفوائد",
                ),
                Tab(
                  icon: Icon(Icons.badge, size: 18),
                  text: "مسؤولو قنوات الاتصال",
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProgramsTab(programs),
                  _buildEmployeesTab(employees),
                ],
              ),
            ),
          ] else ...[
            Expanded(
              child: _buildProgramsTab(programs),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgramsTab(List programs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: programs.isEmpty
              ? const Center(
                  child: Text(
                    "لا توجد برامج مسجلة لهذا البنك حالياً.",
                    style: TextStyle(color: TfcColors.outline),
                  ),
                )
              : ListView.builder(
                  itemCount: programs.length,
                  padding: const EdgeInsets.all(20),
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    final coreProgram = program['core_programs'] as Map<String, dynamic>?;
                    final programName = coreProgram != null ? coreProgram['program_name'] : 'برنامج ائتماني عام';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderColor: Colors.white10,
                        fillColor: Colors.white.withValues(alpha: 0.01),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    programName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (widget.isAdmin || widget.isBankEmployee) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16, color: TfcColors.primary),
                                        onPressed: () => _showProgramFormDialog(context, ref, program: program),
                                        tooltip: "تعديل تفاصيل البرنامج",
                                      ),
                                      if (widget.isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                          onPressed: () => _confirmDeleteProgram(context, ref, program),
                                          tooltip: "حذف البرنامج",
                                        ),
                                      const SizedBox(width: 8),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: TfcColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: TfcColors.primary.withValues(alpha: 0.2),
                                        ),
                                      ),
                                      child: Text(
                                        "فائدة ${program['interest_rate']}%",
                                        style: const TextStyle(
                                          color: TfcColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 12),
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                const Icon(Icons.arrow_circle_left_outlined, color: TfcColors.secondary, size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  "الحد الأقصى للتمويل: ",
                                  style: TextStyle(color: TfcColors.outline, fontSize: 13),
                                  textDirection: TextDirection.rtl,
                                ),
                                Text(
                                  "${_formatMoney(program['max_loan_amount'])} ج.م",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              program['description'] ?? 'لا يوجد تفاصيل أو مميزات مسجلة لهذا البرنامج.',
                              style: const TextStyle(color: TfcColors.outline, fontSize: 12, height: 1.5),
                              textDirection: TextDirection.rtl,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (widget.isAdmin || widget.isBankEmployee)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                foregroundColor: TfcColors.primary,
                side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text("إضافة برنامج ائتماني جديد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => _showProgramFormDialog(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeesTab(List employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: employees.isEmpty
              ? const Center(
                  child: Text(
                    "لا يوجد موظفون مسجلون لجهات اتصال هذا البنك.",
                    style: TextStyle(color: TfcColors.outline),
                  ),
                )
              : ListView.builder(
                  itemCount: employees.length,
                  padding: const EdgeInsets.all(20),
                  itemBuilder: (context, index) {
                    final emp = employees[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderColor: Colors.white10,
                        fillColor: Colors.white.withValues(alpha: 0.01),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                CircleAvatar(
                                  backgroundColor: TfcColors.secondary.withValues(alpha: 0.1),
                                  radius: 20,
                                  child: Text(
                                    emp['employee_name'].substring(0, 1),
                                    style: const TextStyle(
                                      color: TfcColors.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        emp['employee_name'],
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                      Text(
                                        emp['job_title'] ?? "مسؤول ائتماني",
                                        style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 16, color: TfcColors.primary),
                                    onPressed: () => _showEmployeeFormDialog(context, ref, employee: emp),
                                    tooltip: "تعديل بيانات الموظف",
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteEmployee(context, ref, emp),
                                    tooltip: "حذف الموظف",
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 8),

                            // Contact Rows
                            if (emp['phone_1'] != null && widget.canViewBankPhones)
                              _buildContactRow(
                                label: "هاتف التواصل المباشر",
                                value: emp['phone_1'],
                                icon: Icons.phone,
                                onAction: () => _copyToClipboard(context, emp['phone_1'], "رقم الهاتف"),
                              ),
                            if (emp['phone_2'] != null && widget.canViewBankPhones)
                              _buildContactRow(
                                label: "هاتف أرضي/آخر",
                                value: emp['phone_2'],
                                icon: Icons.phone_android,
                                onAction: () => _copyToClipboard(context, emp['phone_2'], "الرقم الإضافي"),
                              ),
                            if (emp['email'] != null && widget.canViewBankPhones)
                              _buildContactRow(
                                label: "البريد الإلكتروني",
                                value: emp['email'],
                                icon: Icons.email,
                                onAction: () => _copyToClipboard(context, emp['email'], "البريد الإلكتروني"),
                              ),

                            if (widget.canViewBankPhones && emp['notes'] != null && emp['notes'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                                ),
                                child: Text(
                                  "ملاحظات التنسيق:\n${emp['notes']}",
                                  style: const TextStyle(color: TfcColors.outline, fontSize: 11, height: 1.4),
                                  textDirection: TextDirection.rtl,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (widget.isAdmin)
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TfcColors.secondary.withValues(alpha: 0.1),
                foregroundColor: TfcColors.secondary,
                side: BorderSide(color: TfcColors.secondary.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.person_add, size: 16),
              label: const Text("إضافة جهة اتصال جديدة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => _showEmployeeFormDialog(context, ref),
            ),
          ),
      ],
    );
  }

  Widget _buildContactRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, color: TfcColors.primary, size: 14),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(color: TfcColors.outline, fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SelectableText(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: TfcColors.primary, size: 14),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onAction,
            tooltip: "نسخ للذاكرة",
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "تم نسخ $label بنجاح: $text",
          textAlign: TextAlign.right,
          style: const TextStyle(color: TfcColors.onPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: TfcColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return "0.00";
    final double value = double.tryParse(amount.toString()) ?? 0.0;
    
    // Simple custom money formatter
    final List<String> parts = value.toStringAsFixed(0).split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String matchFunc(Match match) => '${match[1]},';
    final String formatted = parts[0].replaceAllMapped(reg, matchFunc);
    return formatted;
  }

  // =========================================================================
  // PROGRAM CRUD DIALOGS & MUTATIONS
  // =========================================================================

  void _showProgramFormDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? program}) {
    final coreProgramsAsync = ref.read(coreProgramsProvider);
    final rateController = TextEditingController(text: program?['interest_rate']?.toString() ?? '');
    final maxAmountController = TextEditingController(text: program?['max_loan_amount']?.toString() ?? '');
    final descController = TextEditingController(text: program?['description'] ?? '');
    
    String? selectedCoreProgramId = program?['program_id'];
    final formKey = GlobalKey<FormState>();
    bool isAddingNewCoreProgram = false;
    final newCoreProgramController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: TfcColors.surfaceDim,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                title: Text(
                  program == null ? "إضافة برنامج ائتماني للبنك" : "تعديل تفاصيل البرنامج الائتماني",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Program Selector / Creator (only when adding a new link)
                        if (program == null) ...[
                          if (!isAddingNewCoreProgram) ...[
                            coreProgramsAsync.when(
                              loading: () => const CircularProgressIndicator(),
                              error: (e, s) => Text("خطأ في جلب البرامج: $e", style: const TextStyle(color: Colors.redAccent)),
                              data: (coreList) {
                                return DropdownButtonFormField<String>(
                                  dropdownColor: TfcColors.surfaceDim,
                                  initialValue: selectedCoreProgramId,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: const InputDecoration(
                                    labelText: "نوع البرنامج الائتماني الأساسي",
                                    labelStyle: TextStyle(color: TfcColors.outline),
                                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                  ),
                                  items: coreList.map((cp) {
                                    return DropdownMenuItem<String>(
                                      value: cp['id'],
                                      child: Text(cp['program_name'] ?? ''),
                                    );
                                  }).toList(),
                                  validator: (val) {
                                    if (val == null) return "الرجاء اختيار نوع البرنامج الائتماني";
                                    return null;
                                  },
                                  onChanged: (val) {
                                    setState(() {
                                      selectedCoreProgramId = val;
                                    });
                                  },
                                );
                              },
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  isAddingNewCoreProgram = true;
                                });
                              },
                              icon: const Icon(Icons.add, size: 14, color: TfcColors.secondary),
                              label: const Text("إنشاء نوع برنامج أساسي جديد", style: TextStyle(color: TfcColors.secondary, fontSize: 12)),
                            ),
                          ] else ...[
                            TextFormField(
                              controller: newCoreProgramController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: "اسم نوع البرنامج الأساسي الجديد (مثال: تمويل بطاقات)",
                                labelStyle: const TextStyle(color: TfcColors.outline),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.cancel, color: TfcColors.outline),
                                  onPressed: () {
                                    setState(() {
                                      isAddingNewCoreProgram = false;
                                    });
                                  },
                                ),
                                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                              ),
                              validator: (val) {
                                if (isAddingNewCoreProgram && (val == null || val.trim().isEmpty)) {
                                  return "الرجاء كتابة اسم نوع البرنامج";
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                        ] else ...[
                          // Display existing program name as read-only
                          TextFormField(
                            initialValue: program['core_programs']?['program_name'] ?? '',
                            readOnly: true,
                            enabled: false,
                            style: const TextStyle(color: TfcColors.outline, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: "نوع البرنامج الائتماني",
                              labelStyle: TextStyle(color: TfcColors.outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        TextFormField(
                          controller: rateController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "نسبة الفائدة السنوية (%)",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "الرجاء إدخال نسبة الفائدة";
                            if (double.tryParse(val) == null) return "الرجاء إدخال رقم صحيح";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: maxAmountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "الحد الأقصى للتمويل (ج.م)",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "الرجاء إدخال الحد الأقصى";
                            if (double.tryParse(val) == null) return "الرجاء إدخال رقم صحيح";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: descController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "وصف البرنامج ومميزاته",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "الرجاء إدخال وصف البرنامج";
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TfcColors.primary,
                      foregroundColor: TfcColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final repo = ref.read(banksRepositoryProvider);
                        final double interestRate = double.parse(rateController.text.trim());
                        final double maxLoanAmount = double.parse(maxAmountController.text.trim());
                        final String description = descController.text.trim();

                        if (program == null) {
                          String coreId = selectedCoreProgramId ?? '';
                          // If user selected to create a new program template
                          if (isAddingNewCoreProgram) {
                            final newCore = await repo.createCoreProgram(newCoreProgramController.text.trim());
                            coreId = newCore['id'];
                            ref.invalidate(coreProgramsProvider);
                          }

                          await repo.addProgramToBank(
                            bankId: widget.bankData['id'],
                            coreProgramId: coreId,
                            description: description,
                            interestRate: interestRate,
                            maxLoanAmount: maxLoanAmount,
                          );
                        } else {
                          await repo.updateBankProgram(
                            id: program['id'],
                            description: description,
                            interestRate: interestRate,
                            maxLoanAmount: maxLoanAmount,
                          );
                        }

                        ref.invalidate(allBanksProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(program == null ? "تم ربط البرنامج بالبنك بنجاح" : "تم تعديل تفاصيل البرنامج بنجاح", style: const TextStyle(fontWeight: FontWeight.bold)),
                              backgroundColor: TfcColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    child: Text(program == null ? "إضافة" : "حفظ"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProgram(BuildContext context, WidgetRef ref, Map<String, dynamic> program) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Text(
              "هل أنت متأكد من حذف البرنامج الائتماني \"${program['core_programs']?['program_name'] ?? ''}\" من هذا البنك؟",
              style: const TextStyle(color: TfcColors.outline, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  try {
                    final repo = ref.read(banksRepositoryProvider);
                    await repo.deleteBankProgram(program['id']);
                    ref.invalidate(allBanksProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم حذف البرنامج بنجاح"), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: const Text("حذف"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEmployeeFormDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? employee}) {
    final nameController = TextEditingController(text: employee?['employee_name'] ?? '');
    final phone1Controller = TextEditingController(text: employee?['phone_1'] ?? '');
    final phone2Controller = TextEditingController(text: employee?['phone_2'] ?? '');
    final emailController = TextEditingController(text: employee?['email'] ?? '');
    final notesController = TextEditingController(text: employee?['notes'] ?? '');
    
    final formKey = GlobalKey<FormState>();
    final banks = ref.read(allBanksProvider).value ?? [];
    
    final jobTitles = [
      'مدير ائتمان',
      'مسؤول ائتمان أول',
      'مسؤول ائتمان',
      'منسق علاقات',
      'ممثّل خدمة عملاء',
    ];

    final registeredBankUsers = ref.read(employeesProvider).employees
        .where((e) => e.role == 'bank_employee')
        .toList();

    showDialog(
      context: context,
      builder: (context) {
        String selectedBankId = employee?['bank_id']?.toString() ?? widget.bankData['id'].toString();
        String selectedTitle = employee?['job_title']?.toString() ?? 'مسؤول ائتمان';
        String? selectedProfileId = employee?['profile_id']?.toString();
        if (selectedTitle.isNotEmpty && !jobTitles.contains(selectedTitle)) {
          jobTitles.add(selectedTitle);
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                backgroundColor: TfcColors.surfaceDim,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white10),
                ),
                title: Text(
                  employee == null ? "إضافة مسؤول ائتماني جديد" : "تعديل بيانات المسؤول الائتماني",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                content: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Link Registered System Account
                        if (registeredBankUsers.isNotEmpty) ...[
                          DropdownButtonFormField<String>(
                            initialValue: registeredBankUsers.any((u) => u.id == selectedProfileId)
                                ? selectedProfileId
                                : null,
                            dropdownColor: TfcColors.surfaceContainer,
                            decoration: const InputDecoration(
                              labelText: "ربط بحساب مستخدم مسجل في النظام (اختياري)",
                              labelStyle: TextStyle(color: TfcColors.primary),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary, width: 2)),
                              prefixIcon: Icon(Icons.link, color: TfcColors.primary),
                            ),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            hint: const Text("اختر حساب الموظف المسجل لربطه", textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline, fontSize: 12)),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('بدون ربط بحساب مستخدم', textDirection: TextDirection.rtl, style: TextStyle(color: TfcColors.outline)),
                              ),
                              ...registeredBankUsers.map((u) {
                                return DropdownMenuItem<String>(
                                  value: u.id,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text("${u.fullName} (${u.email ?? 'بدون إيميل'})", textDirection: TextDirection.rtl),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setStateDialog(() {
                                selectedProfileId = (val != null && val.isNotEmpty) ? val : null;
                                if (val != null && val.isNotEmpty) {
                                  final u = registeredBankUsers.firstWhere((usr) => usr.id == val);
                                  if (nameController.text.trim().isEmpty || employee == null) {
                                    nameController.text = u.fullName;
                                  }
                                  if (phone1Controller.text.trim().isEmpty && (u.phoneNumber?.isNotEmpty ?? false)) {
                                    phone1Controller.text = u.phoneNumber!;
                                  }
                                  if (emailController.text.trim().isEmpty && (u.email?.isNotEmpty ?? false)) {
                                    emailController.text = u.email!;
                                  }
                                }
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Bank selection dropdown
                        DropdownButtonFormField<String>(
                          initialValue: selectedBankId,
                          dropdownColor: TfcColors.surfaceContainer,
                          decoration: const InputDecoration(
                            labelText: "اسم البنك التابع له",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: banks.map<DropdownMenuItem<String>>((b) {
                            return DropdownMenuItem<String>(
                              value: b['id'].toString(),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(b['bank_name'] ?? '', textDirection: TextDirection.rtl),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                selectedBankId = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "اسم الموظف المسؤول",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "الرجاء إدخال اسم الموظف";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Job Title dropdown
                        DropdownButtonFormField<String>(
                          initialValue: selectedTitle,
                          dropdownColor: TfcColors.surfaceContainer,
                          decoration: const InputDecoration(
                            labelText: "المسمى الوظيفي",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          items: jobTitles.map<DropdownMenuItem<String>>((title) {
                            return DropdownMenuItem<String>(
                              value: title,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(title, textDirection: TextDirection.rtl),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                selectedTitle = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: phone1Controller,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "هاتف التواصل المباشر الرئيسي",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "الرجاء إدخال رقم الهاتف";
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: phone2Controller,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "هاتف أرضي/آخر (اختياري)",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "البريد الإلكتروني (اختياري)",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: notesController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: const InputDecoration(
                            labelText: "ملاحظات التنسيق والتواصل",
                            labelStyle: TextStyle(color: TfcColors.outline),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: TfcColors.primary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TfcColors.primary,
                      foregroundColor: TfcColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      try {
                        final repo = ref.read(banksRepositoryProvider);
                        String? employeeRecordId;
                        final oldBankId = widget.bankData['id']?.toString();
                        final isBankChanged = selectedBankId != oldBankId;

                        if (employee == null) {
                          final res = await repo.addEmployee(
                            bankId: selectedBankId,
                            name: nameController.text.trim(),
                            phone1: phone1Controller.text.trim(),
                            phone2: phone2Controller.text.trim(),
                            jobTitle: selectedTitle,
                            email: emailController.text.trim(),
                            notes: notesController.text.trim(),
                            profileId: selectedProfileId,
                          );
                          employeeRecordId = res['id']?.toString();
                        } else {
                          await repo.updateEmployee(
                            id: employee['id'],
                            bankId: selectedBankId,
                            name: nameController.text.trim(),
                            phone1: phone1Controller.text.trim(),
                            phone2: phone2Controller.text.trim(),
                            jobTitle: selectedTitle,
                            email: emailController.text.trim(),
                            notes: notesController.text.trim(),
                            profileId: selectedProfileId,
                          );
                          employeeRecordId = employee['id']?.toString();
                        }

                        // Also update the linked user's profile with bank_employee_id & bank_name directly
                        if (selectedProfileId != null && selectedProfileId!.isNotEmpty && employeeRecordId != null) {
                          final selectedBankName = banks.firstWhere(
                            (b) => b['id'].toString() == selectedBankId,
                            orElse: () => {'bank_name': ''},
                          )['bank_name'];

                          await ref.read(employeesProvider.notifier).updateEmployee(
                            profileId: selectedProfileId!,
                            bankName: selectedBankName,
                            bankEmployeeId: employeeRecordId,
                          );
                        }

                        // Invalidate providers so all screens update immediately
                        ref.invalidate(allBanksProvider);
                        ref.invalidate(bankEmployeesProvider(selectedBankId));
                        if (oldBankId != null && oldBankId != selectedBankId) {
                          ref.invalidate(bankEmployeesProvider(oldBankId));
                        }

                        // If the employee's bank changed, switch active view to the new bank
                        if (isBankChanged) {
                          ref.read(selectedBankIdProvider.notifier).state = selectedBankId;
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                employee == null
                                    ? "تم إضافة الموظف بنجاح"
                                    : (isBankChanged ? "تم نقل الموظف إلى البنك الجديد بنجاح" : "تم تعديل بيانات الموظف بنجاح"),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              backgroundColor: TfcColors.primary,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                    child: Text(employee == null ? "إضافة" : "حفظ"),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _confirmDeleteEmployee(BuildContext context, WidgetRef ref, Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white10),
            ),
            title: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            content: Text(
              "هل أنت متأكد من حذف المسؤول الائتماني \"${employee['employee_name']}\"؟",
              style: const TextStyle(color: TfcColors.outline, fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: TfcColors.outline)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  try {
                    final repo = ref.read(banksRepositoryProvider);
                    await repo.deleteEmployee(employee['id']);
                    ref.invalidate(allBanksProvider);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("تم حذف الموظف بنجاح"), backgroundColor: Colors.redAccent),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("حدث خطأ: $e"), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                },
                child: const Text("حذف"),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =========================================================================
// SCREEN: MOBILE BANK DETAILS SCREEN (PUSHED ON MOBILE)
// =========================================================================

class _MobileBankDetailsScreen extends ConsumerWidget {
  final String bankId;
  final bool isAdmin;
  final bool canViewBankPhones;

  const _MobileBankDetailsScreen({
    required this.bankId,
    required this.isAdmin,
    this.canViewBankPhones = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banksAsync = ref.watch(allBanksProvider);
    final authState = ref.watch(authProvider);
    final isBankEmployee = authState.role == 'bank_employee';

    return Scaffold(
      appBar: AppBar(
        title: banksAsync.when(
          loading: () => const Text("جاري التحميل..."),
          error: (e, s) => const Text("خطأ"),
          data: (banks) {
            final bank = banks.firstWhere(
              (b) => b['id'] == bankId,
              orElse: () => <String, dynamic>{'bank_name': 'تفاصيل البنك'},
            );
            return Text(bank['bank_name'] ?? 'تفاصيل البنك', style: const TextStyle(fontWeight: FontWeight.bold));
          },
        ),
        centerTitle: true,
        backgroundColor: TfcColors.surfaceDim.withValues(alpha: 0.6),
        elevation: 0,
      ),
      body: banksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: TfcColors.primary)),
        error: (e, s) => Center(child: Text("خطأ: $e", style: const TextStyle(color: TfcColors.outline))),
        data: (banks) {
          final bank = banks.firstWhere(
            (b) => b['id'] == bankId,
            orElse: () => <String, dynamic>{},
          );
          if (bank.isEmpty) {
            return const Center(child: Text("لم يتم العثور على البنك", style: TextStyle(color: TfcColors.outline)));
          }
          return _BankDetailsPanel(
            bankData: bank,
            isAdmin: isAdmin,
            isBankEmployee: isBankEmployee,
            canViewBankPhones: canViewBankPhones,
          );
        },
      ),
    );
  }
}

// Helper to normalize Arabic text to improve search accuracy
String _normalizeArabic(String text) {
  return text
      .replaceAll(RegExp(r'[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[\u064B-\u0652]'), ''); // remove diacritics
}

class BankSearchField extends ConsumerStatefulWidget {
  const BankSearchField({super.key});

  @override
  ConsumerState<BankSearchField> createState() => _BankSearchFieldState();
}

class _BankSearchFieldState extends ConsumerState<BankSearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(banksSearchQueryProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(banksSearchQueryProvider.notifier).state = query;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: TextField(
        controller: _controller,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: "بحث باسم البنك، البرنامج، الموظف، الهاتف...",
          hintStyle: const TextStyle(color: TfcColors.outline, fontSize: 12),
          prefixIcon: const Icon(Icons.search, color: TfcColors.outline, size: 18),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              return value.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: TfcColors.outline, size: 16),
                      onPressed: () {
                        _controller.clear();
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        ref.read(banksSearchQueryProvider.notifier).state = "";
                      },
                    )
                  : const SizedBox.shrink();
            },
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: TfcColors.primary.withValues(alpha: 0.4)),
          ),
        ),
      ),
    );
  }
}
