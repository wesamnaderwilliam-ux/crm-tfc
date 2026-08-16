import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../models/client_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import 'distribution_widget.dart';
import 'operations_widget.dart';
import 'document_upload_helper.dart';
import '../../core/utils/client_pdf_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/web_helper.dart';
import '../../core/widgets/interactive_hover_card.dart';
import '../../core/widgets/toggleable_filter_panel.dart';
import '../../core/widgets/phone_action_widget.dart';
import '../../core/utils/client_visibility_helper.dart';


class ClientDetailsScreen extends ConsumerStatefulWidget {
  final String? clientId;
  final VoidCallback onBack;
  final Function(String)? onClientSelected;
  final Function(String)? onViewAiAnalysis;
  final VoidCallback? onOpenNewClientForm;
  final bool bankEmployeeMode;

  const ClientDetailsScreen({
    super.key,
    this.clientId,
    required this.onBack,
    this.onClientSelected,
    this.onViewAiAnalysis,
    this.onOpenNewClientForm,
    this.bankEmployeeMode = false,
  });

  @override
  ConsumerState<ClientDetailsScreen> createState() =>
      _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  final TextEditingController _logController = TextEditingController();
  final _logFormKey = GlobalKey<FormState>();
  int _selectedHistoryTab = 0;

  final TextEditingController _clientSearchController = TextEditingController();
  String _clientSearchQuery = "";
  String _selectedStatusFilter = 'all';
  String _selectedRepFilter = 'all';

  // Helper map for Arabic status names
  final Map<String, String> _statusNames = {
    'all': 'الكل',
    'pending': 'قيد الانتظار',
    'iscore_inquiry': 'استعلام أي سكور',
    'preparing_documents': 'تجهيز أوراق',
    'under_review': 'قيد المراجعة',
    'at_bank': 'بالبنك',
    'approved': 'موافق عليه',
    'rejected': 'مرفوض',
  };

  @override
  void dispose() {
    _logController.dispose();
    _clientSearchController.dispose();
    super.dispose();
  }

  final Map<String, bool> _expandedSections = {
    'personal': true,
    'credit': false,
    'loans': false,
    'documents': false,
    'distribution': false,
    'operations': false,
    'logs': false,
  };

  Widget _buildCollapsibleSection({
    required String key,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isExpanded = _expandedSections[key] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          InteractiveHoverCard(
            onTap: () {
              setState(() {
                _expandedSections[key] = !isExpanded;
              });
            },
            glowColor: isExpanded ? const Color(0xFF6C5CE7) : Colors.cyan,
            backgroundColor: const Color(0xFF1E1E38).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(icon, color: isExpanded ? const Color(0xFF00CEC9) : TfcColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isExpanded ? Colors.white : Colors.white70,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
                Icon(
                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: isExpanded ? const Color(0xFF00CEC9) : Colors.white70,
                  size: 24,
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: child,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Future<void> _submitLog({
    required String staffName,
    required String logType,
    required String actionName,
    DateTime? followUpDate,
    String? followUpStatus,
  }) async {
    if (!_logFormKey.currentState!.validate()) return;

    await ref.read(clientProvider.notifier).addInteractionLog(
          widget.clientId ?? '',
          actionName,
          _logController.text.trim(),
          staffName,
          logType: logType,
          followUpDate: followUpDate,
          followUpStatus: followUpStatus,
        );

    _logController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم إضافة الملاحظة بنجاح",
              textAlign: TextAlign.right),
          backgroundColor: TfcColors.primary,
        ),
      );
    }
  }

  Future<void> _selectFollowUpDate(BuildContext context, String staffName) async {
    if (!_logFormKey.currentState!.validate()) return;
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      _submitLog(
        staffName: staffName,
        logType: 'follow_up',
        actionName: "متابعة مجدولة",
        followUpDate: picked,
        followUpStatus: 'pending',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    // Legacy role permissions (for backward compatibility)
    final rolePermissions = ref.watch(permissionsProvider)[authState.role] ??
        RolePermissions.fromDefaults(authState.role);

    // Per-employee resolved permissions
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);
    final userId = authState.user?.id ?? '';
    final effectivePerms = authState.role == 'admin'
        ? EmployeePermissionKeys.defaultsForRole('admin')
        : EmployeePermissionKeys.resolve(
            authState.role,
            customPermsState[userId] ?? {},
          );

    // Convenience helpers from effective permissions
    final canEditClients = effectivePerms[EmployeePermissionKeys.editClient] ?? rolePermissions.canEditClients;
    final canDeleteClients = effectivePerms[EmployeePermissionKeys.deleteClient] ?? rolePermissions.canDeleteClients;
    final canAddNote = effectivePerms[EmployeePermissionKeys.addNote] ?? true;
    final canApproveLoans = effectivePerms[EmployeePermissionKeys.approveLoans] ?? rolePermissions.canApproveLoans;
    final isBankEmp = authState.role == 'bank_employee' || widget.bankEmployeeMode;
    final showPhone = isBankEmp
        ? false
        : (effectivePerms[EmployeePermissionKeys.fieldPhone] ?? true);
    final showNationalId = effectivePerms[EmployeePermissionKeys.fieldNationalId] ?? true;
    final showSalary = effectivePerms[EmployeePermissionKeys.fieldSalary] ?? true;
    final showCreditScore = effectivePerms[EmployeePermissionKeys.fieldCreditScore] ?? true;
    final showLoans = effectivePerms[EmployeePermissionKeys.fieldLoans] ?? true;
    final showCards = effectivePerms[EmployeePermissionKeys.fieldCards] ?? true;
    final showDocuments = effectivePerms[EmployeePermissionKeys.fieldDocuments] ?? true;

    // Expose via a local alias for backward compat usage in the file
    final permissions = rolePermissions;

    final clientState = ref.watch(clientProvider);
    final employeesState = ref.watch(employeesProvider);

    // 1. Role & Manager-hierarchy based visibility filtering
    final visibleClients = ClientVisibilityHelper.filterClients(
      clients: clientState.clients,
      authState: authState,
      allEmployees: employeesState.employees,
    );

    // 2. Local search query, status, & representative filtering
    final reps = visibleClients
        .map((c) => c.representativeName)
        .where((name) => name != null && name.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    reps.sort();

    final filteredClients = visibleClients.where((client) {
      if (_selectedStatusFilter != 'all' && client.status != _selectedStatusFilter) {
        return false;
      }
      if (_selectedRepFilter != 'all' && client.representativeName != _selectedRepFilter) {
        return false;
      }
      if (_clientSearchQuery.isEmpty) return true;
      final q = _clientSearchQuery.toLowerCase();
      return client.fullName.toLowerCase().contains(q) ||
             client.nationalId.contains(q) ||
             client.phoneNumber.contains(q);
    }).toList();

    // Find active client
    final clientIndex = widget.clientId != null
        ? clientState.clients.indexWhere((c) => c.id == widget.clientId)
        : -1;
    final client = clientIndex != -1 ? clientState.clients[clientIndex] : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;

        if (isDesktop) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: TfcColors.primary),
                onPressed: widget.onBack,
              ),
              title: Text(
                client != null
                    ? "ملف العميل: ${client.fullName}"
                    : "دليل تفاصيل العملاء",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              centerTitle: false,
              actions: [
                if (client != null) ...[
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.greenAccent),
                    tooltip: "مشاركة ملف العميل PDF (واتساب / ماسنجر...)",
                    onPressed: () => ClientPdfGenerator.shareClientPdf(client),
                  ),
                  IconButton(
                    icon: const Icon(Icons.print, color: TfcColors.primary),
                    tooltip: "طباعة ملف العميل PDF",
                    onPressed: () => _printClientProfile(client),
                  ),
                  if (canEditClients)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: TfcColors.primary),
                        tooltip: "تعديل بيانات العميل",
                        onPressed: () =>
                            _showEditClientDialog(context, client, authState.fullName),
                      ),
                    ),
                  if (canDeleteClients)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        tooltip: "حذف العميل نهائياً",
                        onPressed: () => _confirmDeleteClient(context, client),
                      ),
                    ),
                ]
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Sidebar on the right (Client List & Search)
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
                            children: [
                              const Icon(Icons.people_alt, color: TfcColors.primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                "دليل العملاء",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: TfcColors.primary,
                                ),
                              ),
                              const Spacer(),
                              if (widget.onOpenNewClientForm != null)
                                InteractiveHoverCard(
                                  onTap: widget.onOpenNewClientForm,
                                  glowColor: Colors.greenAccent,
                                  backgroundColor: Colors.green.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        "طلب تمويل جديد",
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Search field
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextField(
                              controller: _clientSearchController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              onChanged: (val) {
                                setState(() {
                                  _clientSearchQuery = val;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "بحث بالاسم، الهاتف، الرقم القومي...",
                                hintStyle: const TextStyle(color: TfcColors.outline, fontSize: 11),
                                prefixIcon: const Icon(Icons.search, color: TfcColors.outline, size: 18),
                                suffixIcon: _clientSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, color: TfcColors.outline, size: 16),
                                        onPressed: () {
                                          _clientSearchController.clear();
                                          setState(() {
                                            _clientSearchQuery = "";
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.03),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                          ),
                          const SizedBox(height: 12),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: DropdownButtonFormField<String>(
                              value: _selectedStatusFilter,
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
                              items: _statusNames.entries.map((e) {
                                return DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value, textDirection: TextDirection.rtl),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedStatusFilter = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: DropdownButtonFormField<String>(
                              value: reps.contains(_selectedRepFilter) ? _selectedRepFilter : 'all',
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
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('كل المناديب', textDirection: TextDirection.rtl),
                                ),
                                ...reps.map((name) {
                                  return DropdownMenuItem(
                                    value: name,
                                    child: Text(name, textDirection: TextDirection.rtl),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRepFilter = val;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 8),
                          Expanded(
                            child: filteredClients.isEmpty
                                ? const Center(
                                    child: Text(
                                      "لا توجد نتائج مطابقة لبحثك.",
                                      style: TextStyle(color: TfcColors.outline, fontSize: 13),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: filteredClients.length,
                                    itemBuilder: (context, index) {
                                      final item = filteredClients[index];
                                      final isSelected = widget.clientId == item.id;
                                      return _buildClientListTile(item, isSelected);
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // 2. Details view on the left
                  Expanded(
                    child: client != null
                        ? SingleChildScrollView(
                            child: _buildDetailsPanel(
                              client,
                              permissions,
                              authState,
                              effectivePerms,
                              canEditClients,
                              canDeleteClients,
                              canAddNote,
                              canApproveLoans,
                              showPhone,
                              showNationalId,
                              showSalary,
                              showCreditScore,
                              showLoans,
                              showCards,
                              showDocuments,
                            ),
                          )
                        : _buildClientsTable(filteredClients, showNationalId, showCreditScore),
                  ),
                ],
              ),
            ),
          );
        }

        // Mobile Layout:
        if (client == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: TfcColors.primary),
                onPressed: widget.onBack,
              ),
              title: const Text("دليل تفاصيل العملاء", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              actions: [
                if (widget.onOpenNewClientForm != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: InteractiveHoverCard(
                      onTap: widget.onOpenNewClientForm,
                      glowColor: Colors.greenAccent,
                      backgroundColor: Colors.green.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 16),
                          SizedBox(width: 4),
                          Text(
                            "طلب تمويل جديد",
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: _clientSearchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (val) {
                        setState(() {
                          _clientSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "بحث بالاسم، الهاتف، الرقم القومي...",
                        hintStyle: const TextStyle(color: TfcColors.outline, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: TfcColors.outline, size: 18),
                        suffixIcon: _clientSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: TfcColors.outline, size: 16),
                                onPressed: () {
                                  _clientSearchController.clear();
                                  setState(() {
                                    _clientSearchQuery = "";
                                  });
                                },
                              )
                            : null,
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
                   ),
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatusFilter,
                      dropdownColor: TfcColors.surfaceDim,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.filter_list, color: TfcColors.outline, size: 18),
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
                      items: _statusNames.entries.map((e) {
                        return DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value, textDirection: TextDirection.rtl),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatusFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: DropdownButtonFormField<String>(
                      value: reps.contains(_selectedRepFilter) ? _selectedRepFilter : 'all',
                      dropdownColor: TfcColors.surfaceDim,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_outline, color: TfcColors.outline, size: 18),
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
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('كل المناديب', textDirection: TextDirection.rtl),
                        ),
                        ...reps.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name, textDirection: TextDirection.rtl),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRepFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredClients.isEmpty
                        ? const Center(
                            child: Text(
                              "لا توجد نتائج مطابقة لبحثك.",
                              style: TextStyle(color: TfcColors.outline),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredClients.length,
                            itemBuilder: (context, index) {
                              final item = filteredClients[index];
                              return _buildClientListTile(item, false);
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        }

        // Mobile Details Panel view
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: TfcColors.primary),
              onPressed: () {
                widget.onClientSelected?.call("");
              },
            ),
            title: Text(
              "ملف العميل: ${client.fullName}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            actions: [
              if (widget.onOpenNewClientForm != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                  child: InteractiveHoverCard(
                    onTap: widget.onOpenNewClientForm,
                    glowColor: Colors.greenAccent,
                    backgroundColor: Colors.green.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_outline, color: Colors.greenAccent, size: 14),
                        SizedBox(width: 2),
                        Text(
                          "طلب تمويل",
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.greenAccent),
                tooltip: "مشاركة ملف العميل PDF (واتساب / ماسنجر...)",
                onPressed: () => ClientPdfGenerator.shareClientPdf(client),
              ),
              IconButton(
                icon: const Icon(Icons.print, color: TfcColors.primary),
                tooltip: "طباعة ملف العميل PDF",
                onPressed: () => _printClientProfile(client),
              ),
              if (permissions.canEditClients)
                IconButton(
                  icon: const Icon(Icons.edit, color: TfcColors.primary),
                  onPressed: () => _showEditClientDialog(context, client, authState.fullName),
                ),
              if (authState.role == 'admin')
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteClient(context, client),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildDetailsPanel(
              client,
              permissions,
              authState,
              effectivePerms,
              canEditClients,
              canDeleteClients,
              canAddNote,
              canApproveLoans,
              showPhone,
              showNationalId,
              showSalary,
              showCreditScore,
              showLoans,
              showCards,
              showDocuments,
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientListTile(ClientModel item, bool isSelected) {
    return InteractiveHoverCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => widget.onClientSelected?.call(item.id),
      glowColor: isSelected ? const Color(0xFF6C5CE7) : Colors.cyan,
      backgroundColor: isSelected
          ? TfcColors.primary.withValues(alpha: 0.15)
          : Colors.white.withValues(alpha: 0.02),
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                Icons.person,
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
                    item.fullName,
                    style: TextStyle(
                      color: () {
                        switch (item.status) {
                          case 'approved':
                            return TfcColors.success;
                          case 'under_review':
                            return Colors.blueAccent;
                          case 'iscore_inquiry':
                            return Colors.orangeAccent;
                          case 'preparing_documents':
                            return Colors.cyan;
                          case 'at_bank':
                            return Colors.deepPurpleAccent;
                          case 'rejected':
                            return Colors.redAccent;
                          default:
                            return Colors.amber;
                        }
                      }(),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    textDirection: TextDirection.rtl,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.phoneNumber,
                    style: const TextStyle(color: TfcColors.outline, fontSize: 10),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left,
              color: isSelected ? TfcColors.primary : TfcColors.outline,
              size: 16,
            ),
          ],
        ),
    );
  }

  Widget _buildDetailsPanel(
    ClientModel client,
    RolePermissions permissions,
    dynamic authState,
    Map<String, bool> effectivePerms,
    bool canEditClients,
    bool canDeleteClients,
    bool canAddNote,
    bool canApproveLoans,
    bool showPhone,
    bool showNationalId,
    bool showSalary,
    bool showCreditScore,
    bool showLoans,
    bool showCards,
    bool showDocuments,
  ) {
    return Column(
      children: [
        _buildCollapsibleSection(
          key: 'personal',
          title: 'البيانات الشخصية والمالية للعميل',
          icon: Icons.person_outline,
          child: _buildPersonalDetailsBento(
            client,
            permissions,
            authState.fullName,
            effectivePerms,
            showPhone,
            showNationalId,
            showSalary,
          ),
        ),
        _buildCollapsibleSection(
          key: 'credit',
          title: 'التقييم الائتماني والتحليل المالي',
          icon: Icons.analytics_outlined,
          child: Column(
            children: [
              _buildCreditScoreBento(
                client,
                permissions,
                authState.fullName,
                authState.role == 'admin',
                showCreditScore,
              ),
            ],
          ),
        ),
        _buildCollapsibleSection(
          key: 'loans',
          title: 'القروض والبطاقات المصرفية',
          icon: Icons.credit_card_outlined,
          child: _buildLoansCardsBento(
            client,
            permissions,
            authState.fullName,
            showLoans,
            showCards,
            canEditClients,
          ),
        ),
        _buildCollapsibleSection(
          key: 'documents',
          title: 'مراجعة المستندات المرفقة والرفع',
          icon: Icons.file_present_outlined,
          child: _buildDocumentsBento(
            client,
            authState.role == 'admin' || authState.role == 'manager',
            showDocuments,
          ),
        ),
        _buildCollapsibleSection(
          key: 'distribution',
          title: 'توزيع أرباح العملاء',
          icon: Icons.pie_chart_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.onViewAiAnalysis != null) ...[
                ElevatedButton.icon(
                  onPressed: () => widget.onViewAiAnalysis!(client.id),
                  icon: const Icon(Icons.psychology, size: 16),
                  label: const Text("تحليل ذكي ومطابقة بالذكاء الاصطناعي (AI)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.primary.withValues(alpha: 0.15),
                    foregroundColor: TfcColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: TfcColors.primary, width: 0.5),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DistributionWidget(
                clientId: client.id,
                requestedAmount: client.requestedAmount,
              ),
            ],
          ),
        ),
        _buildCollapsibleSection(
          key: 'operations',
          title: 'العمليات',
          icon: Icons.settings_suggest_outlined,
          child: OperationsWidget(clientId: client.id),
        ),
        _buildCollapsibleSection(
          key: 'total_fees',
          title: 'إجمالى الأتعاب',
          icon: Icons.account_balance_wallet_outlined,
          child: _TotalFeesWidget(clientId: client.id),
        ),
        _buildCollapsibleSection(
          key: 'logs',
          title: 'سجل النشاط والتعليقات التفاعلية',
          icon: Icons.history_toggle_off_outlined,
          child: Column(
            children: [
              _buildAddLogBento(authState.fullName),
              const SizedBox(height: 16),
              _buildLogsHistoryBento(client),
            ],
          ),
        ),
      ],
    );
  }

  // Bento Box 1: Personal Details
  Widget _buildPersonalDetailsBento(
    ClientModel client,
    RolePermissions permissions,
    String staffName,
    Map<String, bool> effectivePerms,
    bool showPhone,
    bool showNationalId,
    bool showSalary,
  ) {
    // Compute salary display values
    final double totalSalary = _extractSalary(client);
    final bool hasBankDetails =
        client.salaryTransferMethod == 'bank_transfer' &&
            client.salaryBankDetails.isNotEmpty;
    final bool hasCashSalary = client.salaryTransferMethod == 'cash' &&
        client.cashSalaryAmount != null &&
        client.cashSalaryAmount! > 0;

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: TfcColors.primary.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            textDirection: TextDirection.rtl,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.badge, color: TfcColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text("المعلومات الأساسية والوظيفية",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: TextDirection.rtl,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, size: 18, color: Colors.greenAccent),
                    tooltip: "مشاركة ملف العميل PDF عبر التطبيقات",
                    onPressed: () => ClientPdfGenerator.shareClientPdf(client),
                  ),
                  if (permissions.canEditClients)
                    IconButton(
                      icon: const Icon(Icons.edit,
                          size: 18, color: TfcColors.primary),
                      onPressed: () =>
                          _showEditClientDialog(context, client, staffName),
                    ),
                  _buildSimpleStatusChip(client.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          _buildInfoRow("الاسم الكامل", client.fullName),
          if (showPhone) ...[
            PhoneActionWidget(label: "الهاتف المحمول", phoneNumber: client.phoneNumber),
            if (client.secondaryPhoneNumber != null &&
                client.secondaryPhoneNumber!.isNotEmpty)
              PhoneActionWidget(label: "هاتف إضافي", phoneNumber: client.secondaryPhoneNumber!),
          ] else ...[
            _buildInfoRow("الهاتف المحمول", "مخفي (يتطلب موافقة الأدمن/المدير لإظهاره)"),
          ],
          if (showNationalId)
            _buildInfoRow("الرقم القومي",
                client.nationalId.isEmpty ? "غير مسجل" : client.nationalId),
          // birthDate
          if (effectivePerms[EmployeePermissionKeys.fieldBirthDate] ?? true)
            _buildInfoRow("تاريخ الميلاد", client.birthDate),
          // employment
          if (effectivePerms[EmployeePermissionKeys.fieldEmployment] ?? true) ...[
            _buildInfoRow("جهة العمل", client.companyName ?? "-"),
            _buildInfoRow("المسمى الوظيفي", client.jobTitle ?? "-"),
          ],
          _buildInfoRow(
              "طريقة الاستلام",
              client.salaryTransferMethod == 'bank_transfer'
                  ? "تحويل راتب بنكي"
                  : "نقدي / كاش"),
          // Salary bank details breakdown
          if (showSalary) ...[
            if (hasBankDetails) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "الحسابات البنكية:",
                      style: TextStyle(
                          fontSize: 12,
                          color: TfcColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: client.salaryBankDetails.map((e) {
                          final bank = e['bank'] ?? '';
                          final amount =
                              double.tryParse(e['amount'] ?? '') ?? 0.0;
                          return Text(
                            "$bank: ${_formatLargeNumber(amount)} ج.م",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                            textAlign: TextAlign.right,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Total salary row
            if (hasBankDetails || hasCashSalary)
              _buildInfoRow(
                "إجمالي الراتب الشهري",
                "${_formatLargeNumber(totalSalary)} ج.م",
                highlight: true,
              ),
          ],
          _buildInfoRow("التأمين الاجتماعي",
              client.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"),
          _buildInfoRow("المحافظة", client.governorate),
          _buildInfoRow("المندوب المسؤول", client.representativeName ?? "-"),

          if (client.employmentType == 'business_owner') ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  "تفاصيل الأنشطة التجارية",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TfcColors.secondary),
                ),
                if (permissions.canEditClients)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                    onPressed: () => _showManageBusinessDialog(context, client, staffName),
                    icon: const Icon(Icons.settings, size: 14),
                    label: const Text("إدارة الأنشطة", style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: UniqueKey(),
              child: Builder(
                builder: (context) {
                try {
                  final bizData = client.businessData.isNotEmpty
                      ? client.businessData
                      : _parseBusinesses(client.companyName ?? "[]");

                  if (bizData.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "لا توجد أنشطة مسجلة حالياً",
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    );
                  }

                  return Column(
                    children: bizData.asMap().entries.map((ent) {
                      final idx = ent.key;
                      final biz = ent.value;
                      final activity = biz['activity']?.toString() ?? '-';
                      final startDate = biz['startDate']?.toString() ?? '-';
                      final place = biz['place']?.toString() ?? '-';
                      
                      String docsDisplay = 'لا يوجد';
                      final docsMap = biz['documents'];
                      if (docsMap is Map) {
                        docsDisplay = docsMap.entries
                            .where((e) => e.value == true)
                            .map((e) => e.key.toString())
                            .join('، ');
                      } else if (docsMap is List) {
                        docsDisplay = docsMap.map((e) => e.toString()).join('، ');
                      }
                      if (docsDisplay.isEmpty) docsDisplay = 'لا يوجد';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text("نشاط #${idx + 1}: $activity",
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: TfcColors.primary)),
                            const SizedBox(height: 6),
                            _buildSubInfoRow("تاريخ البدء", startDate),
                            _buildSubInfoRow("مكان النشاط", place),
                            _buildSubInfoRow("الأوراق المتاحة", docsDisplay),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                } catch (e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "خطأ في عرض البيانات: \$e",
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  );
                }
              },
            ),
            ),
      ],
          if (['doctor_clinic', 'doctor_hospital', 'pharmacist_owner'].contains(client.employmentType)) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  "تفاصيل النشاط الطبي",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: TfcColors.secondary),
                ),
                if (permissions.canEditClients)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                    onPressed: () => _showManageMedicalDialog(context, client, staffName),
                    icon: const Icon(Icons.settings, size: 14),
                    label: const Text("تعديل النشاط", style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            KeyedSubtree(
              key: UniqueKey(),
              child: Builder(
                builder: (context) {
                try {
                  final bizDataList = client.businessData;
                  if (bizDataList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "لا توجد تفاصيل نشاط طبي مسجلة حالياً",
                        textDirection: TextDirection.rtl,
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      ),
                    );
                  }

                  return Column(
                    children: bizDataList.asMap().entries.map((ent) {
                      final idx = ent.key;
                      final biz = ent.value;
                      final specialization = biz['specialization']?.toString() ?? '-';
                      final practiceStartDate = biz['practiceStartDate']?.toString() ?? '-';
                      final licenseDate = biz['licenseDate']?.toString() ?? '-';
                      
                      String docsDisplay = 'لا يوجد';
                      final docsMap = biz['documents'];
                      if (docsMap is Map) {
                        docsDisplay = docsMap.entries
                            .where((e) => e.value == true)
                            .map((e) => e.key.toString())
                            .join('، ');
                      } else if (docsMap is List) {
                        docsDisplay = docsMap.map((e) => e.toString()).join('، ');
                      }
                      if (docsDisplay.isEmpty) docsDisplay = 'لا يوجد';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text("نشاط طبي #${idx + 1}",
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: TfcColors.primary)),
                            const SizedBox(height: 6),
                            if (['doctor_clinic', 'doctor_hospital'].contains(client.employmentType))
                              _buildSubInfoRow("التخصص", specialization),
                            _buildSubInfoRow("تاريخ مزاولة المهنة", practiceStartDate),
                            if (['doctor_clinic', 'pharmacist_owner'].contains(client.employmentType))
                              _buildSubInfoRow("تاريخ الترخيص", licenseDate),
                            _buildSubInfoRow("الأوراق المتاحة", docsDisplay),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                } catch (e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      "خطأ في عرض البيانات: $e",
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  );
                }
              },
            ),
            ),
          ],
    ],
  ),

);
  }

  // Bento Box 2: Credit Score and Bank Approval controller
  Widget _buildCreditScoreBento(
    ClientModel client,
    RolePermissions permissions,
    String staffName,
    bool isAdmin,
    bool showCreditScore,
  ) {
    final score = client.creditScore;
    Color scoreColor = Colors.redAccent;
    String scoreGrade = "سيء (High Risk)";
    if (score >= 720) {
      scoreColor = TfcColors.success;
      scoreGrade = "ممتاز (Excellent)";
    } else if (score >= 620) {
      scoreColor = Colors.amber;
      scoreGrade = "متوسط (Fair)";
    }

    // If iScore/creditScore field is hidden, show a locked view
    if (!showCreditScore) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, color: TfcColors.outline),
              SizedBox(height: 12),
              Text(
                "تم حجب صلاحية عرض التقييم الائتماني",
                style: TextStyle(color: TfcColors.outline, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: scoreColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.donut_large, color: TfcColors.secondary, size: 20),
              SizedBox(width: 8),
              Text("التقييم الائتماني وقرار التمويل",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),

          // Score circular preview
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: score / 850,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      color: scoreColor,
                      strokeWidth: 8,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        score.toString(),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: scoreColor),
                      ),
                      const Text("I-SCORE",
                          style:
                              TextStyle(fontSize: 9, color: TfcColors.outline)),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("مبلغ التمويل المطلوب",
                        style:
                            TextStyle(color: TfcColors.outline, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      "${_formatLargeNumber(client.requestedAmount)} ج.م",
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: TfcColors.primary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "درجة العميل: $scoreGrade",
                      style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // Transaction Status Stepper
          _buildTransactionStatusStepper(client, isAdmin, staffName),
        ],
      ),
    );
  }

  // Bento Box 3: Existing Loans & Credit Cards
  Widget _buildLoansCardsBento(
    ClientModel client,
    RolePermissions permissions,
    String staffName,
    bool showLoans,
    bool showCards,
    bool canEditClients,
  ) {
    if (!showLoans && !showCards) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, color: TfcColors.outline),
              SizedBox(height: 8),
              Text("بيانات الالتزامات الائتمانية مخفية لعدم توفر الصلاحيات",
                  style: TextStyle(color: TfcColors.outline),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: Colors.white.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.credit_card, color: TfcColors.primary, size: 20),
              SizedBox(width: 8),
              Text("التزامات القروض والبطاقات القائمة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),

          // 1. Existing Loans list
          if (showLoans) ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Text("القروض القائمة والتسهيلات:",
                    style: TextStyle(fontSize: 13, color: TfcColors.outline)),
              ],
            ),
            const SizedBox(height: 8),
            if (client.existingLoans.isEmpty)
              const Text("لا توجد قروض قائمة مسجلة للعميل",
                  style: TextStyle(color: TfcColors.outline, fontSize: 12),
                  textDirection: TextDirection.rtl)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: client.existingLoans.length,
                itemBuilder: (context, idx) {
                  final l = client.existingLoans[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Text(l.bankName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Text(
                                "القسط: ${_formatLargeNumber(l.installmentValue)} ج.م",
                                style: const TextStyle(
                                    color: TfcColors.secondary, fontSize: 13),
                              ),
                              if (l.notes != null && l.notes!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "(${l.notes})",
                                    style: const TextStyle(
                                        color: TfcColors.outline, fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        if (canEditClients)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blueAccent, size: 16),
                                onPressed: () => _showAddEditLoanDialog(
                                    context, client, staffName,
                                    loan: l),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 16),
                                onPressed: () => _confirmDeleteLoanOrCard(
                                    context,
                                    clientId: client.id,
                                    loanId: l.id,
                                    staffName: staffName),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            if (canEditClients) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAddEditLoanDialog(context, client, staffName),
                  icon: const Icon(Icons.add_circle_outline, color: TfcColors.primary, size: 18),
                  label: const Text("إضافة قرض قائم", style: TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.3)),
                    ),
                    backgroundColor: TfcColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          ] else ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.lock_outline, size: 14, color: TfcColors.outline),
                SizedBox(width: 6),
                Text("القروض القائمة مخفية من قِبل الإدارة",
                    style: TextStyle(color: TfcColors.outline, fontSize: 12)),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // 2. Credit Cards list
          if (showCards) ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Text("البطاقات والطلبات (مع حساب الـ 5% عبء الدين):",
                    style: TextStyle(fontSize: 13, color: TfcColors.outline)),
              ],
            ),
            const SizedBox(height: 8),
            if (client.creditCardsRequests.isEmpty)
              const Text("لا توجد بطاقات ائتمانية مدرجة",
                  style: TextStyle(color: TfcColors.outline, fontSize: 12),
                  textDirection: TextDirection.rtl)
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: client.creditCardsRequests.length,
                itemBuilder: (context, idx) {
                  final c = client.creditCardsRequests[idx];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                textDirection: TextDirection.rtl,
                                children: [
                                  Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Text(c.bankName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c.type == 'card'
                                              ? Colors.teal
                                                  .withValues(alpha: 0.2)
                                              : Colors.blue
                                                  .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          c.type == 'card'
                                              ? "بطاقة"
                                              : "أبلكيشن",
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: c.type == 'card'
                                                  ? TfcColors.primary
                                                  : Colors.blueAccent),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                textDirection: TextDirection.rtl,
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    "الليمت: ${_formatLargeNumber(c.value)} ج.م",
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                  if (c.highestValue > 0)
                                    Text(
                                      "أعلى قيمة: ${_formatLargeNumber(c.highestValue)} ج.م",
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  if (c.installment > 0)
                                    Text(
                                      "القسط: ${_formatLargeNumber(c.installment)} ج.م",
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  if (c.duration.isNotEmpty)
                                    Text(
                                      "المدة: ${c.duration}",
                                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                                    ),
                                  Text(
                                    "عبء الدين (5%): ${_formatLargeNumber(c.fivePercentCalc)} ج.م",
                                    style: const TextStyle(
                                        color: TfcColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                              if (c.notes != null && c.notes!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  "ملاحظات: ${c.notes}",
                                  style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (canEditClients) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blueAccent, size: 16),
                                onPressed: () => _showAddEditCardDialog(
                                    context, client, staffName,
                                    card: c),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.redAccent, size: 16),
                                onPressed: () => _confirmDeleteLoanOrCard(
                                    context,
                                    clientId: client.id,
                                    cardId: c.id,
                                    staffName: staffName),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            if (canEditClients) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAddEditCardDialog(context, client, staffName),
                  icon: const Icon(Icons.add_circle_outline, color: TfcColors.primary, size: 18),
                  label: const Text("إضافة بطاقة / طلب", style: TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.3)),
                    ),
                    backgroundColor: TfcColors.primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          ] else ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.lock_outline, size: 14, color: TfcColors.outline),
                SizedBox(width: 6),
                Text("البطاقات الائتمانية مخفية من قِبل الإدارة",
                    style: TextStyle(color: TfcColors.outline, fontSize: 12)),
              ],
            ),
          ],

          // ----------------------------------------------------
          // Credit Obligations Summary & Virtual Income
          // ----------------------------------------------------
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          _buildCreditSummaryBento(client, permissions),
          const SizedBox(height: 16),
          VirtualIncomeBento(
            client: client,
            staffName: staffName,
            permissions: permissions,
          ),

          // ----------------------------------------------------
          // Compound units section
          // ----------------------------------------------------
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.home_work, color: TfcColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "وحدات في كمبوند",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TfcColors.secondary),
                  ),
                ],
              ),
              if (canEditClients)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                  onPressed: () => _showManageCompoundUnitsDialog(context, client, staffName),
                  icon: const Icon(Icons.settings, size: 14),
                  label: const Text("إدارة الوحدات", style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (client.hasCompoundUnit && client.compoundUnitsData.isNotEmpty) ...[
            ...client.compoundUnitsData.asMap().entries.map((ent) {
              final idx = ent.key;
              final unit = ent.value;
              final name = unit['compoundName']?.toString() ?? '-';
              final dev = unit['developerName']?.toString() ?? '-';
              final date = unit['contractDate']?.toString() ?? '-';
              final value = double.tryParse(unit['unitValue']?.toString() ?? '0') ?? 0.0;
              final down = double.tryParse(unit['downPayment']?.toString() ?? '0') ?? 0.0;
              final pct = value > 0 ? (down / value) * 100 : 0.0;
              final count = int.tryParse(unit['paidInstallmentsCount']?.toString() ?? '0') ?? 0;
              final paid = double.tryParse(unit['paidAmount']?.toString() ?? '0') ?? 0.0;
              
              final List<dynamic> rawFiles = unit['unitContractFiles'] ?? [];
              final files = rawFiles.map((e) => ClientDocumentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text("الوحدة #${idx + 1}",
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TfcColors.primary)),
                        if (canEditClients)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                                tooltip: "تعديل بيانات الوحدة",
                                onPressed: () => _showManageCompoundUnitsDialog(context, client, staffName),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                tooltip: "حذف هذه الوحدة",
                                onPressed: () => _confirmDeleteCompoundUnit(context, client, idx, staffName),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSubInfoRow("اسم الكمبوند", name),
                    _buildSubInfoRow("اسم المطور", dev),
                    _buildSubInfoRow("تاريخ التعاقد", date),
                    _buildSubInfoRow("قيمة الوحدة", "${_formatLargeNumber(value)} ج.م"),
                    _buildSubInfoRow("المقدم المدفوع", "${_formatLargeNumber(down)} ج.م (${pct.toStringAsFixed(1)}%)"),
                    _buildSubInfoRow("عدد الأقساط المدفوعة", "$count قسط"),
                    _buildSubInfoRow("قيمة ما تم دفعه", "${_formatLargeNumber(paid)} ج.م"),
                    if (files.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text("مستندات عقد الوحدة:", textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: TfcColors.secondary)),
                      const SizedBox(height: 4),
                      ...files.map((file) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                file.documentName.replaceAll("عقد وحدة: ", ""),
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download, size: 14, color: TfcColors.primary),
                              onPressed: () {
                                // Downloader or URL Opener
                              },
                            )
                          ],
                        ),
                      )),
                    ],
                  ],
                ),
              );
            }),
          ] else ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Text("لا توجد وحدات مسجلة للعميل",
                    style: TextStyle(color: TfcColors.outline, fontSize: 12),
                    textDirection: TextDirection.rtl),
              ],
            ),
          ],

          // ----------------------------------------------------
          // Modern Cars section
          // ----------------------------------------------------
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.directions_car, color: TfcColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "سيارة حديثة",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TfcColors.secondary),
                  ),
                ],
              ),
              if (canEditClients)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                  onPressed: () => _showManageModernCarsDialog(context, client, staffName),
                  icon: const Icon(Icons.settings, size: 14),
                  label: const Text("إدارة السيارات", style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (client.hasModernCar && client.modernCarsData.isNotEmpty) ...[
            ...client.modernCarsData.asMap().entries.map((ent) {
              final idx = ent.key;
              final car = ent.value;
              final type = car['carType']?.toString() ?? '-';
              final model = car['carModel']?.toString() ?? '-';
              final value = double.tryParse(car['carTodayValue']?.toString() ?? '0') ?? 0.0;
              final license = car['licenseStatus']?.toString() ?? '-';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Text("السيارة #${idx + 1}",
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TfcColors.primary)),
                        if (canEditClients)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 16),
                                tooltip: "تعديل بيانات السيارة",
                                onPressed: () => _showManageModernCarsDialog(context, client, staffName),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
                                tooltip: "حذف هذه السيارة",
                                onPressed: () => _confirmDeleteModernCar(context, client, idx, staffName),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildSubInfoRow("نوع السيارة", type),
                    _buildSubInfoRow("الموديل", model),
                    _buildSubInfoRow("القيمة الحالية للسيارة اليوم", "${_formatLargeNumber(value)} ج.م"),
                    _buildSubInfoRow("حالة الرخصة", license),
                  ],
                ),
              );
            }),
          ] else ...[
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Text("لا توجد سيارات مسجلة للعميل",
                    style: TextStyle(color: TfcColors.outline, fontSize: 12),
                    textDirection: TextDirection.rtl),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Confirm delete individual modern car
  void _confirmDeleteModernCar(BuildContext context, ClientModel client, int index, String staffName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("حذف السيارة", textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white)),
        content: Text("هل أنت تأكد من حذف هذه السيارة (#${index + 1}) من حساب العميل؟", textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final list = List<Map<String, dynamic>>.from(client.modernCarsData);
              if (index >= 0 && index < list.length) {
                list.removeAt(index);
                final updated = client.copyWith(hasModernCar: list.isNotEmpty, modernCarsData: list);
                final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? "تم حذف السيارة بنجاح"), backgroundColor: error == null ? Colors.green : Colors.redAccent),
                  );
                }
              }
            },
            child: const Text("حذف النهائي", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Bento Box 4: Documents Upload Status list with CRUD
  Widget _buildDocumentsBento(ClientModel client, bool isAdmin, bool showDocuments) {
    if (!showDocuments) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, color: TfcColors.outline),
              SizedBox(height: 12),
              Text(
                "تم حجب صلاحية عرض المستندات",
                style: TextStyle(color: TfcColors.outline, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: Colors.white.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.file_present, color: TfcColors.primary, size: 20),
              SizedBox(width: 8),
              Text("مراجعة المستندات المرفقة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          if (client.documents.isEmpty)
            const Text("لا توجد مستندات مرفوعة لهذا العميل",
                style: TextStyle(color: TfcColors.outline, fontSize: 12),
                textDirection: TextDirection.rtl)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: client.documents.length,
              itemBuilder: (context, idx) {
                final d = client.documents[idx];
                Color statusColor = Colors.amber;
                String statusLabel = "تحت التدقيق";
                if (d.status == 'verified') {
                  statusColor = TfcColors.success;
                  statusLabel = "مقبول";
                } else if (d.status == 'rejected') {
                  statusColor = Colors.redAccent;
                  statusLabel = "مرفوض";
                }

                final urlLower = d.documentUrl.toLowerCase();
                final nameLower = d.documentName.toLowerCase();
                final bool isImage = urlLower.contains('.jpg') ||
                    urlLower.contains('.jpeg') ||
                    urlLower.contains('.png') ||
                    urlLower.contains('.webp') ||
                    nameLower.contains('.jpg') ||
                    nameLower.contains('.jpeg') ||
                    nameLower.contains('.png') ||
                    nameLower.contains('.webp') ||
                    urlLower.contains('supabase.co/storage');

                return Container(
                  margin: const EdgeInsets.only(bottom: 14.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: Document Name + Status + Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Icon(
                                  isImage ? Icons.image : Icons.picture_as_pdf,
                                  color: isImage ? Colors.blueAccent : Colors.redAccent,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    d.documentName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              if (isAdmin && d.status == 'pending') ...[
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: TfcColors.success, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: "موافقة",
                                  onPressed: () => _updateDocumentStatus(client, d, 'verified'),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: "رفض",
                                  onPressed: () => _updateDocumentStatus(client, d, 'rejected'),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  statusLabel,
                                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit, color: TfcColors.secondary, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "تعديل",
                                onPressed: () => _editDocument(client, d),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: "حذف",
                                onPressed: () => _deleteDocument(client, d),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Image / File Content Display Area
                      if (isImage && d.documentUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _showDocumentPreview(d),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 280),
                              width: double.infinity,
                              color: Colors.black26,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Image.network(
                                    d.documentUrl,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Padding(
                                        padding: EdgeInsets.all(24.0),
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.white10,
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.broken_image, color: Colors.amber),
                                            SizedBox(width: 8),
                                            Text("تعذر تحميل المعاينة المباشرة للمستند", style: TextStyle(fontSize: 12, color: Colors.white70)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.fullscreen, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text("عرض بالكامل", style: TextStyle(color: Colors.white, fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: () => _showDocumentPreview(d),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 22),
                                SizedBox(width: 8),
                                Text("اضغط هنا للفتح والتنزيل والمعاينة الحية", style: TextStyle(fontSize: 12, color: Colors.blueAccent, decoration: TextDecoration.underline)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _addDocument(client),
              icon: const Icon(Icons.add_circle_outline, color: TfcColors.primary, size: 18),
              label: const Text("إضافة مستند جديد", style: TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: TfcColors.primary.withValues(alpha: 0.3)),
                ),
                backgroundColor: TfcColors.primary.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDocumentPreview(ClientDocumentModel doc) {
    Color statusColor = Colors.amber;
    String statusLabel = "تحت التدقيق";
    IconData statusIcon = Icons.hourglass_top;
    if (doc.status == 'verified') {
      statusColor = TfcColors.success;
      statusLabel = "مقبول ✓";
      statusIcon = Icons.check_circle;
    } else if (doc.status == 'rejected') {
      statusColor = Colors.redAccent;
      statusLabel = "مرفوض ✗";
      statusIcon = Icons.cancel;
    }

    final bool hasUrl = doc.documentUrl.isNotEmpty && 
        (doc.documentUrl.startsWith('http') || doc.documentUrl.startsWith('blob') || doc.documentUrl.startsWith('data:'));

    final bool isImage = doc.documentName.toLowerCase().contains('.jpg') ||
        doc.documentName.toLowerCase().contains('.png') ||
        doc.documentName.toLowerCase().contains('.jpeg') ||
        doc.documentName.toLowerCase().contains('.gif') ||
        doc.documentUrl.startsWith('data:image/');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: TfcColors.primary.withValues(alpha: 0.1),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [TfcColors.primary.withValues(alpha: 0.2), TfcColors.secondary.withValues(alpha: 0.1)],
                  ),
                ),
                child: Icon(
                  doc.documentName.toLowerCase().contains('.pdf') ? Icons.picture_as_pdf :
                  isImage ? Icons.image :
                  Icons.insert_drive_file,
                  size: 32,
                  color: TfcColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              // Document name
              Text(
                doc.documentName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 6),
                    Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              
              // Image visual preview
              if (isImage && hasUrl) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    width: double.infinity,
                    color: Colors.black26,
                    child: Image.network(
                      doc.documentUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: Colors.white30, size: 36),
                                SizedBox(height: 8),
                                Text("تعذر تحميل معاينة الصورة", style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              // Info section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white54, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          hasUrl ? "المستند جاهز للمعاينة والفتح" : "المستند مرفوع - في انتظار الربط بالخادم",
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    if (doc.documentUrl.isNotEmpty && !hasUrl) ...[
                      const SizedBox(height: 6),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          const Icon(Icons.folder, color: Colors.white38, size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              doc.documentUrl,
                              style: const TextStyle(color: Colors.white38, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.ltr,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  if (hasUrl)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final url = Uri.tryParse(doc.documentUrl);
                          if (url != null) {
                            await launchUrl(url);
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text("فتح المستند"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TfcColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  if (hasUrl) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("إغلاق"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateDocumentStatus(ClientModel client, ClientDocumentModel doc, String newStatus) async {
    final staffName = ref.read(authProvider).fullName;
    final updatedDocs = client.documents.map((d) {
      if (d.id == doc.id) {
        return d.copyWith(status: newStatus);
      }
      return d;
    }).toList();
    await ref.read(clientProvider.notifier).updateClientDocuments(client.id, updatedDocs, staffName: staffName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(newStatus == 'verified' ? "تم الموافقة على المستند" : "تم رفض المستند", textAlign: TextAlign.right)),
      );
    }
  }

  void _addDocument(ClientModel client) {
    final staffName = ref.read(authProvider).fullName;
    DocumentUploadHelper.showUploadDialog(
      context,
      onUploadComplete: (name, url) async {
        final newDoc = ClientDocumentModel(
          id: "doc-${DateTime.now().millisecondsSinceEpoch}",
          documentName: name,
          documentUrl: url,
          status: 'pending',
        );
        final updatedDocs = [...client.documents, newDoc];
        await ref.read(clientProvider.notifier).updateClientDocuments(client.id, updatedDocs, staffName: staffName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إضافة المستند بنجاح", textAlign: TextAlign.right)),
          );
        }
      },
    );
  }

  void _editDocument(ClientModel client, ClientDocumentModel doc) {
    final staffName = ref.read(authProvider).fullName;
    DocumentUploadHelper.showUploadDialog(
      context,
      initialName: doc.documentName,
      onUploadComplete: (name, url) async {
        final updatedDocs = client.documents.map((d) {
          if (d.id == doc.id) {
            return ClientDocumentModel(
              id: d.id,
              documentName: name,
              documentUrl: url.isNotEmpty ? url : d.documentUrl,
              status: d.status,
            );
          }
          return d;
        }).toList();
        await ref.read(clientProvider.notifier).updateClientDocuments(client.id, updatedDocs, staffName: staffName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم تعديل المستند بنجاح", textAlign: TextAlign.right)),
          );
        }
      },
    );
  }

  void _deleteDocument(ClientModel client, ClientDocumentModel doc) {
    final staffName = ref.read(authProvider).fullName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: Text("هل أنت متأكد من حذف مستند \"${doc.documentName}\"؟", textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final updatedDocs = client.documents.where((d) => d.id != doc.id).toList();
              await ref.read(clientProvider.notifier).updateClientDocuments(client.id, updatedDocs, staffName: staffName);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم حذف المستند بنجاح", textAlign: TextAlign.right)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("حذف"),
          ),
        ],
      ),
    );
  }

  // Bento Box 5: Add Follow-up log form
  Widget _buildAddLogBento(String staffName) {
    final role = ref.read(authProvider).role;
    // Only admin can create bank follow-ups (مراسلة البنك)
    final canCreateBankFollowUp = role == 'admin';

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: TfcColors.secondary.withValues(alpha: 0.1),
      child: Form(
        key: _logFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(Icons.edit_note, color: TfcColors.secondary, size: 20),
                SizedBox(width: 8),
                Text("إضافة ملاحظة متابعة جديدة",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _logController,
              textAlign: TextAlign.right,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText:
                    "اكتب هنا تفاصيل الاتصال، طلب أوراق، أو تحديث من البنك...",
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "الرجاء كتابة الملاحظة"
                  : null,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              textDirection: TextDirection.rtl,
              children: [
                // Button 1: Save as Note / File Interaction
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.secondary,
                    foregroundColor: TfcColors.onSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _submitLog(
                    staffName: staffName,
                    logType: 'file_interaction',
                    actionName: "تحديث يدوي - متابعة الملف",
                  ),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text("ملاحظة ملف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                // Button 2: Save as Follow-up (scheduling follow-up date)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _selectFollowUpDate(context, staffName),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text("متابعة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),

                if (canCreateBankFollowUp)
                  // Button 3: Bank Follow-up (Admin Only)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F5D4),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _submitLog(
                      staffName: staffName,
                      logType: 'bank_follow_up',
                      actionName: "مراسلة البنك",
                    ),
                    icon: const Icon(Icons.contact_mail_outlined, size: 16),
                    label: const Text("مراسلة البنك", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Bento Box 6: Logs History Timeline
  Widget _buildLogsHistoryBento(ClientModel client) {
    // All users can view bank follow-up tab
    const showBankFollowUpTab = true;

    // 1. Sort from newest to oldest
    final sortedLogs = List<InteractionLogModel>.from(client.history)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 2. Filter based on selected tab (0: الكل, 1: تفاعلات الملف, 2: المتابعات, 3: مراسلات البنك)
    final filteredLogs = sortedLogs.where((log) {
      if (_selectedHistoryTab == 0) return true; // الكل
      if (_selectedHistoryTab == 1) return log.logType == 'file_interaction';
      if (_selectedHistoryTab == 2) return log.logType == 'follow_up';
      if (_selectedHistoryTab == 3) return log.logType == 'bank_follow_up';
      return true;
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: Colors.white.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.history, color: TfcColors.primary, size: 20),
              SizedBox(width: 8),
              Text("سجل التفاعلات والنشاطات (الجدول الزمني)",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),

          // Tab selectors
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _buildTabButton(0, "الكل", Icons.view_list_outlined),
                const SizedBox(width: 8),
                _buildTabButton(1, "تفاعلات الملف", Icons.description_outlined),
                const SizedBox(width: 8),
                _buildTabButton(2, "المتابعات", Icons.calendar_month_outlined),
                if (showBankFollowUpTab) ...[
                  const SizedBox(width: 8),
                  _buildTabButton(3, "مراسلات البنك", Icons.contact_mail_outlined),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (filteredLogs.isEmpty)
            const Text("لا توجد نشاطات مسجلة في هذا القسم حالياً",
                style: TextStyle(color: TfcColors.outline, fontSize: 12),
                textDirection: TextDirection.rtl)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLogs.length,
              itemBuilder: (context, idx) {
                final log = filteredLogs[idx];
                final logColor = log.logType == 'file_interaction'
                    ? TfcColors.primary
                    : log.logType == 'follow_up'
                        ? const Color(0xFF7B61FF)
                        : const Color(0xFF00F5D4);

                return IntrinsicHeight(
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      // Timeline dot and line with distinct logType colors
                      Column(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: logColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 1,
                              color: idx == filteredLogs.length - 1
                                  ? Colors.transparent
                                  : Colors.white10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Content Card
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: logColor.withValues(alpha: 0.15)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                textDirection: TextDirection.rtl,
                                children: [
                                  Text(
                                    log.actionType,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: logColor,
                                        fontSize: 13),
                                  ),
                                  Text(
                                    "${log.createdAt.hour}:${log.createdAt.minute.toString().padLeft(2, '0')} - ${log.createdAt.day}/${log.createdAt.month}",
                                    style: const TextStyle(
                                        color: TfcColors.outline, fontSize: 10),
                                  ),
                                ],
                              ),
            const SizedBox(height: 6),

                              // If follow up date is defined, show it
                              if (log.logType == 'follow_up' && log.followUpDate != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7B61FF).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF7B61FF).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      const Icon(Icons.alarm, color: Color(0xFF7B61FF), size: 12),
                                      const SizedBox(width: 4),
                                      Text(
                                        "تاريخ المتابعة المطلوب: ${log.followUpDate!.day}/${log.followUpDate!.month}/${log.followUpDate!.year}",
                                        style: const TextStyle(color: Color(0xFF7B61FF), fontSize: 11, fontWeight: FontWeight.bold),
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Follow-up status chip - shown for ALL follow_up logs
                              if (log.logType == 'follow_up') ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  textDirection: TextDirection.rtl,
                                  children: [
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
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: (log.followUpStatus == 'completed')
                                              ? TfcColors.success.withValues(alpha: 0.15)
                                              : Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: (log.followUpStatus == 'completed')
                                                ? TfcColors.success
                                                : Colors.amber,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          textDirection: TextDirection.rtl,
                                          children: [
                                            Icon(
                                              (log.followUpStatus == 'completed')
                                                  ? Icons.check_circle_outline
                                                  : Icons.hourglass_top_outlined,
                                              size: 11,
                                              color: (log.followUpStatus == 'completed')
                                                  ? TfcColors.success
                                                  : Colors.amber,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              (log.followUpStatus == 'completed') ? "تمت المتابعة" : "قيد المتابعة",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: (log.followUpStatus == 'completed')
                                                    ? TfcColors.success
                                                    : Colors.amber,
                                              ),
                                            ),
                                            const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white60),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              Text(
                                log.notes,
                                style: const TextStyle(
                                    fontSize: 12, color: TfcColors.onSurface),
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "بواسطة: ${log.createdBy}",
                                style: const TextStyle(
                                    color: TfcColors.outline,
                                    fontSize: 10,
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _printClientProfile(ClientModel client) {
    // 1. Gather Calculations & commitment totals
    final double totalSalary = _extractSalary(client);
    
    // Existing loans list
    double totalLoansInstallments = 0.0;
    String loansHtml = '';
    if (client.existingLoans.isEmpty) {
      loansHtml = '<tr><td colspan="3" class="empty">لا توجد قروض قائمة مسجلة</td></tr>';
    } else {
      for (var l in client.existingLoans) {
        totalLoansInstallments += l.installmentValue;
        loansHtml += '''
          <tr>
            <td>${l.bankName}</td>
            <td>${_formatLargeNumber(l.installmentValue)} ج.م</td>
            <td>${l.notes ?? '-'}</td>
          </tr>
        ''';
      }
    }

    // Credit cards list
    double totalCardsFivePercent = 0.0;
    String cardsHtml = '';
    if (client.creditCardsRequests.isEmpty) {
      cardsHtml = '<tr><td colspan="7" class="empty">لا توجد بطاقات ائتمانية مدرجة</td></tr>';
    } else {
      for (var c in client.creditCardsRequests) {
        totalCardsFivePercent += c.fivePercentCalc;
        cardsHtml += '''
          <tr>
            <td>${c.bankName}</td>
            <td>${c.type == 'card' ? 'بطاقة' : 'أبلكيشن'}</td>
            <td>${_formatLargeNumber(c.value)} ج.م</td>
            <td>${c.highestValue > 0 ? _formatLargeNumber(c.highestValue) + ' ج.م' : '-'}</td>
            <td>${c.installment > 0 ? _formatLargeNumber(c.installment) + ' ج.م' : '-'}</td>
            <td>${c.duration.isNotEmpty ? c.duration : '-'}</td>
            <td class="highlight-val">${_formatLargeNumber(c.fivePercentCalc)} ج.م</td>
          </tr>
        ''';
      }
    }

    // Commitments calculations & percentages
    final double totalInstallments = totalLoansInstallments + totalCardsFivePercent;
    final double dbrPercentage = totalSalary > 0 ? (totalInstallments / totalSalary) * 100 : 0.0;
    final double availableSalaryFortyFive = totalSalary * 0.45;
    final double netLimit = availableSalaryFortyFive - totalInstallments;
    final double maxLoanValue = netLimit > 0 ? netLimit * 45 : 0.0;

    // 2. Find ID card images (front & back) from client documents
    final idKeywords = ['بطاقة', 'هوية', 'وجه', 'ظهر', 'front', 'back', 'national', 'id', 'قومي'];
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    
    // Find documents that look like ID card images
    final idDocs = client.documents.where((doc) {
      final nameLower = doc.documentName.toLowerCase();
      final urlLower = doc.documentUrl.toLowerCase();
      final isImage = imageExtensions.any((ext) => nameLower.contains(ext) || urlLower.contains(ext)) ||
          doc.documentUrl.startsWith('blob:') ||
          doc.documentUrl.startsWith('data:image');
      final isIdCard = idKeywords.any((kw) => nameLower.contains(kw));
      return isImage && isIdCard;
    }).toList();

    // If no specific ID-keyword documents, take the first 2 image documents as fallback
    final allImageDocs = client.documents.where((doc) {
      final nameLower = doc.documentName.toLowerCase();
      final urlLower = doc.documentUrl.toLowerCase();
      return imageExtensions.any((ext) => nameLower.contains(ext) || urlLower.contains(ext)) ||
          doc.documentUrl.startsWith('blob:') ||
          doc.documentUrl.startsWith('data:image');
    }).toList();

    final docsToShow = idDocs.isNotEmpty ? idDocs : allImageDocs.take(2).toList();

    // Build the ID images HTML section
    String idImagesHtml = '';
    if (docsToShow.isNotEmpty) {
      String imagesInnerHtml = '';
      for (var doc in docsToShow) {
        final hasValidUrl = doc.documentUrl.isNotEmpty &&
            (doc.documentUrl.startsWith('http') ||
                doc.documentUrl.startsWith('blob:') ||
                doc.documentUrl.startsWith('data:'));
        if (hasValidUrl) {
          imagesInnerHtml += '''
            <div class="id-card-item">
              <img src="${doc.documentUrl}" alt="${doc.documentName}" />
              <div class="id-card-label">${doc.documentName}</div>
            </div>
          ''';
        }
      }
      if (imagesInnerHtml.isNotEmpty) {
        idImagesHtml = '''
          <div class="section-title" style="page-break-before: auto;">صورة البطاقة الشخصية (وجه وظهر)</div>
          <div class="id-cards-grid">
            $imagesInnerHtml
          </div>
        ''';
      }
    }

    // 3. Draft full printable clean HTML with custom premium print stylesheet
    final String printHtml = '''
    <!DOCTYPE html>
    <html lang="ar" dir="rtl">
    <head>
      <meta charset="UTF-8">
      <title>تقرير الملف الائتماني للعميل: ${client.fullName}</title>
      <style>
        body {
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
          margin: 30px;
          color: #333;
          background-color: #fff;
          line-height: 1.6;
        }
        .header {
          text-align: center;
          margin-bottom: 30px;
          border-bottom: 2px solid #1a365d;
          padding-bottom: 15px;
        }
        .header h1 {
          color: #1a365d;
          margin: 0;
          font-size: 24px;
        }
        .header p {
          color: #718096;
          margin: 5px 0 0 0;
          font-size: 13px;
        }
        .section-title {
          font-size: 16px;
          font-weight: bold;
          color: #1a365d;
          margin-top: 25px;
          margin-bottom: 10px;
          border-right: 4px solid #1a365d;
          padding-right: 10px;
        }
        .info-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 15px;
          margin-bottom: 20px;
        }
        .info-item {
          background-color: #f7fafc;
          padding: 10px 15px;
          border-radius: 6px;
          border: 1px solid #edf2f7;
        }
        .info-label {
          font-size: 11px;
          color: #718096;
          margin-bottom: 3px;
        }
        .info-value {
          font-size: 14px;
          font-weight: bold;
          color: #2d3748;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 10px;
          margin-bottom: 20px;
        }
        th, td {
          border: 1px solid #e2e8f0;
          padding: 10px 12px;
          text-align: right;
          font-size: 13px;
        }
        th {
          background-color: #f7fafc;
          color: #1a365d;
          font-weight: bold;
        }
        tr:nth-child(even) {
          background-color: #fafbfc;
        }
        .empty {
          text-align: center;
          color: #a0aec0;
          font-style: italic;
        }
        .highlight-val {
          color: #e53e3e;
          font-weight: bold;
        }
        .summary-card {
          background: #ebf8ff;
          border: 1px solid #bee3f8;
          padding: 15px 20px;
          border-radius: 8px;
          margin-top: 20px;
        }
        .summary-title {
          font-weight: bold;
          color: #2b6cb0;
          margin-bottom: 10px;
          font-size: 15px;
        }
        .summary-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 10px;
        }
        .summary-item {
          font-size: 13px;
          color: #2d3748;
        }
        .summary-item strong {
          color: #2b6cb0;
        }
        /* ID Card Images Section */
        .id-cards-grid {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 20px;
          margin-top: 15px;
          margin-bottom: 20px;
        }
        .id-card-item {
          text-align: center;
          border: 2px solid #e2e8f0;
          border-radius: 10px;
          overflow: hidden;
          background: #f7fafc;
        }
        .id-card-item img {
          width: 100%;
          max-height: 280px;
          object-fit: contain;
          display: block;
          padding: 8px;
        }
        .id-card-label {
          padding: 8px 12px;
          background: #edf2f7;
          font-size: 12px;
          font-weight: bold;
          color: #1a365d;
          border-top: 1px solid #e2e8f0;
        }
        @media print {
          body {
            margin: 20px;
          }
          .no-print {
            display: none;
          }
          .summary-card {
            background-color: #ebf8ff !important;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
          }
          .id-card-item {
            break-inside: avoid;
          }
          .id-card-item img {
            max-height: 260px;
          }
        }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>تقرير الملف الائتماني للعميل</h1>
        <p>التاريخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} | الشركة: FUTURE CLUB</p>
      </div>

      <div class="section-title">المعلومات الأساسية والوظيفية</div>
      <div class="info-grid">
        <div class="info-item">
          <div class="info-label">اسم العميل بالكامل</div>
          <div class="info-value">${client.fullName}</div>
        </div>
        <div class="info-item">
          <div class="info-label">الرقم القومي</div>
          <div class="info-value">${client.nationalId.isEmpty ? 'غير مسجل' : client.nationalId}</div>
        </div>
        <div class="info-item">
          <div class="info-label">تاريخ الميلاد</div>
          <div class="info-value">${client.birthDate}</div>
        </div>
        <div class="info-item">
          <div class="info-label">المحافظة</div>
          <div class="info-value">${client.governorate}</div>
        </div>
        <div class="info-item">
          <div class="info-label">جهة العمل</div>
          <div class="info-value">${client.companyName ?? '-'}</div>
        </div>
        <div class="info-item">
          <div class="info-label">المسمى الوظيفي</div>
          <div class="info-value">${client.jobTitle ?? '-'}</div>
        </div>
        <div class="info-item">
          <div class="info-label">طريقة استلام الراتب</div>
          <div class="info-value">${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل راتب بنكي' : 'نقدي / كاش'}</div>
        </div>
        <div class="info-item">
          <div class="info-label">إجمالي الراتب الشهري</div>
          <div class="info-value">${_formatLargeNumber(totalSalary)} ج.م</div>
        </div>
        <div class="info-item">
          <div class="info-label">البنوك المحول عليها الراتب</div>
          <div class="info-value">
            ${client.salaryBankDetails.isNotEmpty
              ? client.salaryBankDetails.map((b) => b['bank'] ?? '').where((name) => name.isNotEmpty).join(' ، ')
              : 'لا يوجد'}
          </div>
        </div>
        <div class="info-item">
          <div class="info-label">مبلغ التمويل المطلوب</div>
          <div class="info-value">${_formatLargeNumber(client.requestedAmount)} ج.م</div>
        </div>
      </div>

      $idImagesHtml

      <div class="section-title">التزامات القروض القائمة</div>
      <table>
        <thead>
          <tr>
            <th>اسم البنك</th>
            <th>قيمة القسط</th>
            <th>ملاحظات</th>
          </tr>
        </thead>
        <tbody>
          $loansHtml
        </tbody>
      </table>

      <div class="section-title">البطاقات الائتمانية والطلبات</div>
      <table>
        <thead>
          <tr>
            <th>اسم البنك</th>
            <th>النوع</th>
            <th>الليمت</th>
            <th>أعلى قيمة</th>
            <th>القسط</th>
            <th>المدة</th>
            <th>عبء الدين (5%)</th>
          </tr>
        </thead>
        <tbody>
          $cardsHtml
        </tbody>
      </table>

      <div class="section-title">ملخص الالتزامات ومؤشرات الائتمان</div>
      <div class="summary-card">
        <div class="summary-title">خلاصة الحسابات المالية (معدلات DBR والاستحقاق):</div>
        <div class="summary-grid">
          <div class="summary-item">إجمالي الالتزامات الشهرية: <strong>${_formatLargeNumber(totalInstallments)} ج.م</strong></div>
          <div class="summary-item">معدل عبء الدين الفعلي (DBR): <strong class="highlight-val">${dbrPercentage.toStringAsFixed(1)}%</strong></div>
          <div class="summary-item">نسبة الـ 45% المتاحة من الراتب: <strong>${_formatLargeNumber(availableSalaryFortyFive)}.00 ج.م</strong></div>
          <div class="summary-item">صافي القسط المتاح الجديد: <strong>${_formatLargeNumber(netLimit)}.00 ج.م</strong></div>
          <div class="summary-item" style="grid-column: span 2; margin-top: 10px; border-top: 1px dashed #bee3f8; padding-top: 10px;">
            تقدير الحد الأقصى للتمويل المتاح: <strong>${_formatLargeNumber(maxLoanValue)}.00 ج.م</strong> (تقريبي)
          </div>
        </div>
      </div>

      <script>
        window.onload = function() {
          // Delay print to allow images to load
          setTimeout(function() {
            window.print();
            window.onafterprint = function() {
              window.close();
            };
          }, 1500);
        };
      </script>
    </body>
    </html>
    ''';

    // 4. Create blob & open it in a printable tab safely
    openHtmlWindow(printHtml);
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedHistoryTab == index;
    final activeColor = index == 0
        ? const Color(0xFF64FFDA) // الكل - cyan accent
        : index == 1
            ? TfcColors.primary // تفاعلات الملف - gold
            : index == 2
                ? const Color(0xFF7B61FF) // المتابعات - purple
                : const Color(0xFF00F5D4); // مراسلات البنك - turquoise

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedHistoryTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: [
            Icon(icon, size: 14, color: isSelected ? activeColor : TfcColors.outline),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : TfcColors.outline,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a dialog to edit client details.

  // === Transaction Status Steps Definition ===
  static const List<Map<String, String>> _transactionSteps = [
    {'key': 'pending', 'label': 'قيد الانتظار', 'icon': 'hourglass_empty'},
    {'key': 'iscore_inquiry', 'label': 'استعلام ايسكور', 'icon': 'search'},
    {
      'key': 'preparing_documents',
      'label': 'تحضير الاوراق',
      'icon': 'description'
    },
    {'key': 'under_review', 'label': 'قيد الدراسة', 'icon': 'rate_review'},
    {'key': 'at_bank', 'label': 'فى البنك', 'icon': 'account_balance'},
    {'key': 'approved', 'label': 'مقبول', 'icon': 'check_circle'},
    {'key': 'rejected', 'label': 'مرفوض', 'icon': 'cancel'},
  ];

  int _getStatusIndex(String status) {
    final idx = _transactionSteps.indexWhere((s) => s['key'] == status);
    return idx == -1 ? 0 : idx;
  }

  IconData _getStepIcon(String iconName) {
    switch (iconName) {
      case 'hourglass_empty':
        return Icons.hourglass_empty;
      case 'search':
        return Icons.search;
      case 'description':
        return Icons.description;
      case 'rate_review':
        return Icons.rate_review;
      case 'account_balance':
        return Icons.account_balance;
      case 'check_circle':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      default:
        return Icons.circle;
    }
  }

  Color _getStepColor(int stepIndex, int currentIndex, String currentStatus) {
    if (currentStatus == 'rejected') {
      // If rejected, only the rejected step (last) is red, everything before current is dimmed
      if (stepIndex == 6) {
        return Colors.redAccent;
      }
      if (stepIndex <= currentIndex) {
        return Colors.redAccent.withValues(alpha: 0.4);
      }
      return Colors.white.withValues(alpha: 0.1);
    }
    if (stepIndex < currentIndex) return TfcColors.success; // completed
    if (stepIndex == currentIndex) return TfcColors.primary; // current
    return Colors.white.withValues(alpha: 0.15); // future
  }

  Widget _buildTransactionStatusStepper(
      ClientModel client, bool isAdmin, String staffName) {
    final currentStatus = client.status;
    final currentIndex = _getStatusIndex(currentStatus);
    // For rejected, show steps up to the point of rejection
    final isRejected = currentStatus == 'rejected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(Icons.timeline, color: TfcColors.primary, size: 18),
            SizedBox(width: 8),
            Text(
              "حالة المعاملة",
              style: TextStyle(
                color: TfcColors.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Visual Stepper Bar
        LayoutBuilder(
          builder: (context, constraints) {
            // Steps to display: if rejected, show the 6 normal steps + rejected
            // Otherwise show only 6 (excluding rejected)
            final displaySteps = isRejected
                ? _transactionSteps
                : _transactionSteps
                    .where((s) => s['key'] != 'rejected')
                    .toList();
            final stepCount = displaySteps.length;

            return Column(
              children: [
                // Progress line + circles
                SizedBox(
                  height: 56,
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: List.generate(stepCount * 2 - 1, (i) {
                      if (i.isEven) {
                        // Circle
                        final stepIdx = i ~/ 2;
                        final step = displaySteps[stepIdx];
                        final originalIdx = _transactionSteps
                            .indexWhere((s) => s['key'] == step['key']);
                        final color = _getStepColor(
                            originalIdx, currentIndex, currentStatus);
                        final isActive = originalIdx <= currentIndex;
                        final isCurrent = originalIdx == currentIndex;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              width: isCurrent ? 38 : 30,
                              height: isCurrent ? 38 : 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive
                                    ? color.withValues(alpha: 0.15)
                                    : Colors.white.withValues(alpha: 0.04),
                                border: Border.all(
                                  color: color,
                                  width: isCurrent ? 2.5 : 1.5,
                                ),
                                boxShadow: isCurrent
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _getStepIcon(step['icon']!),
                                size: isCurrent ? 18 : 14,
                                color: isActive
                                    ? color
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Connector line
                        final beforeIdx = i ~/ 2;
                        final afterIdx = beforeIdx + 1;
                        final beforeOriginal = _transactionSteps.indexWhere(
                            (s) => s['key'] == displaySteps[beforeIdx]['key']);
                        final afterOriginal = _transactionSteps.indexWhere(
                            (s) => s['key'] == displaySteps[afterIdx]['key']);
                        final isCompleted = afterOriginal <= currentIndex;

                        return Expanded(
                          child: Container(
                            height: 2.5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: isCompleted
                                  ? LinearGradient(
                                      colors: [
                                        _getStepColor(beforeOriginal,
                                            currentIndex, currentStatus),
                                        _getStepColor(afterOriginal,
                                            currentIndex, currentStatus),
                                      ],
                                    )
                                  : null,
                              color: isCompleted
                                  ? null
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        );
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                // Labels
                Row(
                  textDirection: TextDirection.rtl,
                  children: List.generate(stepCount * 2 - 1, (i) {
                    if (i.isEven) {
                      final stepIdx = i ~/ 2;
                      final step = displaySteps[stepIdx];
                      final originalIdx = _transactionSteps
                          .indexWhere((s) => s['key'] == step['key']);
                      final isCurrent = originalIdx == currentIndex;
                      final isActive = originalIdx <= currentIndex;
                      final color = _getStepColor(
                          originalIdx, currentIndex, currentStatus);

                      return SizedBox(
                        width: 50,
                        child: Text(
                          step['label']!,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontSize: isCurrent ? 9 : 8,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isActive
                                ? color
                                : Colors.white.withValues(alpha: 0.3),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    } else {
                      return const Spacer();
                    }
                  }),
                ),
              ],
            );
          },
        ),

        // Admin-only dropdown to change status
        if (isAdmin) ...[
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          const Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.admin_panel_settings,
                  color: TfcColors.primary, size: 16),
              SizedBox(width: 6),
              Text(
                "تغيير حالة المعاملة (أدمن فقط)",
                style: TextStyle(
                  color: TfcColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: TfcColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: TfcColors.primary.withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: client.status,
                dropdownColor: TfcColors.surfaceDim,
                isExpanded: true,
                onChanged: (val) {
                  if (val != null) {
                    ref
                        .read(clientProvider.notifier)
                        .updateClientStatus(client.id, val, staffName);
                  }
                },
                items: _transactionSteps.map((step) {
                  Color? itemColor;
                  if (step['key'] == 'approved') itemColor = TfcColors.success;
                  if (step['key'] == 'rejected') itemColor = Colors.redAccent;
                  return DropdownMenuItem(
                    value: step['key'],
                    child: Text(
                      step['label']!,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: itemColor),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          const Text(
            "* تعديل الحالة متاح للأدمن فقط.",
            style: TextStyle(color: TfcColors.outline, fontSize: 10),
            textDirection: TextDirection.rtl,
          ),
        ],
      ],
    );
  }

  Widget _buildSimpleStatusChip(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha((0.2 * 255).toInt())),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  List<Map<String, dynamic>> _parseBusinesses(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  Widget _buildSubInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Wrap(
        textDirection: TextDirection.rtl,
        children: [
          Text("$label: ", style: const TextStyle(fontSize: 11, color: Colors.white54)),
          Text(value,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 11, color: Colors.white)),
        ],
      ),
    );
  }

  void _showManageBusinessDialog(BuildContext context, ClientModel client, String staffName) {
    final List<Map<String, dynamic>> tempEntries = client.businessData.isNotEmpty
        ? client.businessData
        : _parseBusinesses(client.companyName ?? "[]");
    
    final List<Map<String, dynamic>> uiEntries = tempEntries.map((b) {
      return {
        'activity': TextEditingController(text: b['activity'] ?? ''),
        'startDate': TextEditingController(text: b['startDate'] ?? ''),
        'place': TextEditingController(text: b['place'] ?? ''),
        'documents': (() {
          final d = b['documents'];
          if (d is Map) {
            return {
              'سجل تجارى': d['سجل تجارى'] == true,
              'بطاقة ضربية': d['بطاقة ضربية'] == true,
              'كشف حساب': d['كشف حساب'] == true,
              'ميزانيات': d['ميزانيات'] == true,
              'فواتير': d['فواتير'] == true,
              'رخصة مشروع او صناعية': d['رخصة مشروع او صناعية'] == true,
              'عقد ايجار او تمليك لمقر الشركة': d['عقد ايجار او تمليك لمقر الشركة'] == true,
            };
          }
          final list = d is List ? d : <dynamic>[];
          return {
            'سجل تجارى': list.contains('سجل تجارى'),
            'بطاقة ضربية': list.contains('بطاقة ضربية'),
            'كشف حساب': list.contains('كشف حساب'),
            'ميزانيات': list.contains('ميزانيات'),
            'فواتير': list.contains('فواتير'),
            'رخصة مشروع او صناعية': list.contains('رخصة مشروع او صناعية'),
            'عقد ايجار او تمليك لمقر الشركة': list.contains('عقد ايجار او تمليك لمقر الشركة'),
          };
        })(),
      };
    }).toList();

    if (uiEntries.isEmpty) {
      uiEntries.add({
        'activity': TextEditingController(),
        'startDate': TextEditingController(),
        'place': TextEditingController(),
        'documents': {
          'سجل تجارى': false,
          'بطاقة ضربية': false,
          'كشف حساب': false,
          'ميزانيات': false,
          'فواتير': false,
          'رخصة مشروع او صناعية': false,
          'عقد ايجار او تمليك لمقر الشركة': false,
        },
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: TfcColors.surfaceDim,
              title: const Text("إدارة الأنشطة التجارية للعميل",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: uiEntries.length,
                        itemBuilder: (context, idx) {
                          final b = uiEntries[idx];
                          final docsMap = b['documents'] as Map<String, bool>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Text("النشاط #${idx + 1}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                                    if (uiEntries.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                        onPressed: () {
                                          setDialogState(() {
                                            uiEntries.removeAt(idx);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Expanded(
                                      child: _buildDialogFormField(
                                        label: "النشاط",
                                        child: TextFormField(
                                          controller: b['activity'],
                                          textAlign: TextAlign.right,
                                          decoration: const InputDecoration(hintText: "اسم النشاط"),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDialogFormField(
                                        label: "تاريخ بدء النشاط",
                                        child: TextFormField(
                                          controller: b['startDate'],
                                          textAlign: TextAlign.right,
                                          decoration: const InputDecoration(hintText: "مثال: 2020"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDialogFormField(
                                  label: "مكان النشاط",
                                  child: TextFormField(
                                    controller: b['place'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "العنوان بالتفصيل"),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  "الأوراق المتاحة",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: TfcColors.secondary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: docsMap.keys.map((docName) {
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: docsMap[docName],
                                            activeColor: TfcColors.primary,
                                            onChanged: (val) {
                                              setDialogState(() {
                                                docsMap[docName] = val ?? false;
                                              });
                                            },
                                          ),
                                          Text(docName, style: const TextStyle(fontSize: 10)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            uiEntries.add({
                              'activity': TextEditingController(),
                              'startDate': TextEditingController(),
                              'place': TextEditingController(),
                              'documents': {
                                'سجل تجارى': false,
                                'بطاقة ضربية': false,
                                'كشف حساب': false,
                                'ميزانيات': false,
                                'فواتير': false,
                                'رخصة مشروع او صناعية': false,
                                'عقد ايجار او تمليك لمقر الشركة': false,
                              },
                            });
                          });
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text("إضافة نشاط آخر"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final businessList = uiEntries.map((b) => {
                      'activity': b['activity'].text.trim(),
                      'startDate': b['startDate'].text.trim(),
                      'place': b['place'].text.trim(),
                      'documents': (b['documents'] as Map<String, bool>)
                          .entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList(),
                    }).toList();

                    final primaryCompany = businessList.isNotEmpty 
                        ? businessList[0]['activity'] as String 
                        : '';

                    final updated = ClientModel(
                      id: client.id,
                      fullName: client.fullName,
                      phoneNumber: client.phoneNumber,
                      secondaryPhoneNumber: client.secondaryPhoneNumber,
                      nationalId: client.nationalId,
                      birthDate: client.birthDate,
                      companyName: primaryCompany.isNotEmpty ? primaryCompany : null,
                      jobTitle: client.jobTitle,
                      employmentType: client.employmentType,
                      isInsured: client.isInsured,
                      salaryTransferMethod: client.salaryTransferMethod,
                      salaryBankDetails: client.salaryBankDetails,
                      cashSalaryAmount: client.cashSalaryAmount,
                      creditScore: client.creditScore,
                      requestedAmount: client.requestedAmount,
                      governorate: client.governorate,
                      representativeName: client.representativeName,
                      status: client.status,
                      createdAt: client.createdAt,
                      businessData: businessList,
                    );

                    final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ التعديلات بنجاح")));
                      }
                    }
                  },
                  child: const Text("حفظ التغييرات"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageMedicalDialog(BuildContext context, ClientModel client, String staffName) {
    final List<Map<String, dynamic>> tempEntries = client.businessData.isNotEmpty
        ? client.businessData
        : [];
    
    final List<Map<String, dynamic>> uiEntries = tempEntries.map((b) {
      final docsMap = {
        'صورة كارنيه النقابة': false,
        'صورة مزاولة المهنة': false,
        'صورة رخصة العيادة/الصيدلية': false,
      };
      final d = b['documents'];
      if (d is Map) {
        docsMap['صورة كارنيه النقابة'] = d['صورة كارنيه النقابة'] == true;
        docsMap['صورة مزاولة المهنة'] = d['صورة مزاولة المهنة'] == true;
        docsMap['صورة رخصة العيادة/الصيدلية'] = d['صورة رخصة العيادة/الصيدلية'] == true;
      } else if (d is List) {
        docsMap['صورة كارنيه النقابة'] = d.contains('صورة كارنيه النقابة');
        docsMap['صورة مزاولة المهنة'] = d.contains('صورة مزاولة المهنة');
        docsMap['صورة رخصة العيادة/الصيدلية'] = d.contains('صورة رخصة العيادة/الصيدلية');
      }

      return {
        'specialization': TextEditingController(text: b['specialization']?.toString() ?? ''),
        'practiceStartDate': TextEditingController(text: b['practiceStartDate']?.toString() ?? ''),
        'licenseDate': TextEditingController(text: b['licenseDate']?.toString() ?? ''),
        'documents': docsMap,
      };
    }).toList();

    if (uiEntries.isEmpty) {
      uiEntries.add({
        'specialization': TextEditingController(),
        'practiceStartDate': TextEditingController(),
        'licenseDate': TextEditingController(),
        'documents': {
          'صورة كارنيه النقابة': false,
          'صورة مزاولة المهنة': false,
          'صورة رخصة العيادة/الصيدلية': false,
        },
      });
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: TfcColors.surfaceDim,
              title: const Text("إدارة الأنشطة الطبية للعميل",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: uiEntries.length,
                        itemBuilder: (context, idx) {
                          final b = uiEntries[idx];
                          final docsMap = b['documents'] as Map<String, bool>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Text("نشاط طبي #${idx + 1}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                                    if (uiEntries.length > 1)
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                        onPressed: () {
                                          setDialogState(() {
                                            uiEntries.removeAt(idx);
                                          });
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (['doctor_clinic', 'doctor_hospital'].contains(client.employmentType))
                                  _buildDialogFormField(
                                    label: "التخصص",
                                    child: TextFormField(
                                      controller: b['specialization'],
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(hintText: "مثال: باطنة، أسنان..."),
                                    ),
                                  ),
                                if (['doctor_clinic', 'doctor_hospital'].contains(client.employmentType))
                                  const SizedBox(height: 12),
                                Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Expanded(
                                      child: _buildDialogFormField(
                                        label: "تاريخ مزاولة المهنة",
                                        child: TextFormField(
                                          controller: b['practiceStartDate'],
                                          textAlign: TextAlign.right,
                                          decoration: const InputDecoration(hintText: "مثال: 2015-05-01"),
                                        ),
                                      ),
                                    ),
                                    if (['doctor_clinic', 'pharmacist_owner'].contains(client.employmentType)) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogFormField(
                                          label: "تاريخ الترخيص",
                                          child: TextFormField(
                                            controller: b['licenseDate'],
                                            textAlign: TextAlign.right,
                                            decoration: const InputDecoration(hintText: "مثال: 2018-01-01"),
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "الأوراق المتاحة",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: TfcColors.secondary, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 6,
                                    children: docsMap.keys.map((docName) {
                                      if (docName == 'صورة رخصة العيادة/الصيدلية' && client.employmentType == 'doctor_hospital') {
                                        return const SizedBox.shrink();
                                      }
                                      return Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Checkbox(
                                            value: docsMap[docName],
                                            activeColor: TfcColors.primary,
                                            onChanged: (val) {
                                              setDialogState(() {
                                                docsMap[docName] = val ?? false;
                                              });
                                            },
                                          ),
                                          Text(docName, style: const TextStyle(fontSize: 10)),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            uiEntries.add({
                              'specialization': TextEditingController(),
                              'practiceStartDate': TextEditingController(),
                              'licenseDate': TextEditingController(),
                              'documents': {
                                'صورة كارنيه النقابة': false,
                                'صورة مزاولة المهنة': false,
                                'صورة رخصة العيادة/الصيدلية': false,
                              },
                            });
                          });
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text("إضافة نشاط طبي آخر"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final businessList = uiEntries.map((b) => {
                      'specialization': b['specialization'].text.trim(),
                      'practiceStartDate': b['practiceStartDate'].text.trim(),
                      'licenseDate': b['licenseDate'].text.trim(),
                      'documents': (b['documents'] as Map<String, bool>)
                          .entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList(),
                    }).toList();

                    final updated = ClientModel(
                      id: client.id,
                      fullName: client.fullName,
                      phoneNumber: client.phoneNumber,
                      secondaryPhoneNumber: client.secondaryPhoneNumber,
                      nationalId: client.nationalId,
                      birthDate: client.birthDate,
                      companyName: client.companyName,
                      jobTitle: client.jobTitle,
                      employmentType: client.employmentType,
                      isInsured: client.isInsured,
                      salaryTransferMethod: client.salaryTransferMethod,
                      salaryBankDetails: client.salaryBankDetails,
                      cashSalaryAmount: client.cashSalaryAmount,
                      creditScore: client.creditScore,
                      requestedAmount: client.requestedAmount,
                      governorate: client.governorate,
                      representativeName: client.representativeName,
                      status: client.status,
                      createdAt: client.createdAt,
                      businessData: businessList,
                    );

                    final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم حفظ التعديلات بنجاح")));
                      }
                    }
                  },
                  child: const Text("حفظ التغييرات"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDialogFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: TfcColors.secondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool highlight = false}) {
    return Container(
      decoration: highlight
          ? BoxDecoration(
              color: TfcColors.primary.withAlpha((0.08 * 255).toInt()),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: TfcColors.primary.withAlpha((0.25 * 255).toInt())),
            )
          : null,
      padding: highlight
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(vertical: 8.0),
      margin:
          highlight ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          Text(label,
              style: TextStyle(
                  color: highlight
                      ? TfcColors.primary
                      : TfcColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.normal)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.left,
              textDirection: TextDirection.rtl,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: highlight ? 14 : 13,
                color: highlight ? TfcColors.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }



  String _formatLargeNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  double _extractSalary(ClientModel client) {
    // Primary: read from structured model fields added in this session
    if (client.salaryTransferMethod == 'cash' &&
        client.cashSalaryAmount != null &&
        client.cashSalaryAmount! > 0) {
      return client.cashSalaryAmount!;
    }
    if (client.salaryTransferMethod == 'bank_transfer' &&
        client.salaryBankDetails.isNotEmpty) {
      double total = 0.0;
      for (final entry in client.salaryBankDetails) {
        total += double.tryParse(entry['amount'] ?? '') ?? 0.0;
      }
      if (total > 0) return total;
    }

    // Fallback: parse from history logs (legacy support)
    final salaryLog = client.history.firstWhere(
      (log) =>
          log.actionType.contains("تفاصيل الراتب") ||
          log.notes.contains("طريقة تحويل الراتب"),
      orElse: () => InteractionLogModel(
          id: '',
          actionType: '',
          notes: '',
          createdBy: '',
          createdAt: DateTime.now()),
    );

    if (salaryLog.notes.isNotEmpty) {
      final notes = salaryLog.notes;
      double totalSalary = 0.0;
      if (notes.contains("إيداع نقدي بمبلغ:")) {
        final regExp = RegExp(r'بمبلغ:\s*([\d\.]+)');
        final match = regExp.firstMatch(notes);
        if (match != null) {
          totalSalary = double.tryParse(match.group(1) ?? '') ?? 0.0;
        }
      } else if (notes.contains("تحويل بنكي على الحسابات:")) {
        final regExp = RegExp(r'\(\s*([\d\.]+)\s*ج\.م\s*\)');
        for (final m in regExp.allMatches(notes)) {
          totalSalary += double.tryParse(m.group(1) ?? '') ?? 0.0;
        }
      }
      if (totalSalary > 0) {
        return totalSalary;
      }
    }

    // Mock defaults for pre-seeded demo clients
    if (client.id.contains("ahmed")) return 15000.0;
    if (client.id.contains("sara")) return 20000.0;
    if (client.id.contains("mohammed")) return 8000.0;
    return 15000.0;
  }

  Widget _buildCreditSummaryBento(
      ClientModel client, RolePermissions permissions) {
    if (permissions.fieldVisibility['salary'] == false ||
        permissions.fieldVisibility['loans'] == false ||
        permissions.fieldVisibility['cards'] == false) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, color: TfcColors.outline),
              SizedBox(height: 8),
              Text(
                  "ملخص الالتزامات الائتمانية والـ DBR مخفي لعدم صلاحية عرض الراتب أو القروض أو البطاقات",
                  style: TextStyle(color: TfcColors.outline),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    double loanInst = 0.0;
    double cardFiveP = 0.0;
    double cardHighest = 0.0;

    for (var loan in client.existingLoans) {
      loanInst += loan.installmentValue;
    }
    for (var card in client.creditCardsRequests) {
      cardFiveP += card.fivePercentCalc;
      cardHighest += card.highestValue;
    }

    final totalObl = loanInst + cardHighest;
    final totalOblWithFivePercent = loanInst + cardFiveP;
    final salary = _extractSalary(client);

    final dbr = salary > 0 ? (totalObl / salary) * 100 : 0.0;
    final maxAllowed = salary * 0.50; // DBR ceiling at 50%
    final available = maxAllowed - totalObl;

    Color dbrColor = dbr > 50
        ? const Color(0xFFFF6B6B)
        : (dbr > 35 ? Colors.amberAccent : TfcColors.primary);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: TfcColors.primary.withAlpha((0.1 * 255).toInt()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withAlpha((0.15 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined,
                    color: TfcColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("ملخص الالتزامات الائتمانية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSummaryTile(
                  "إجمالي أقساط القروض",
                  "${_formatLargeNumber(loanInst)} ج.م",
                  Icons.account_balance,
                  TfcColors.secondary),
              _buildSummaryTile(
                  "إجمالي 5% البطاقات",
                  "${_formatLargeNumber(cardFiveP)} ج.م",
                  Icons.credit_card,
                  const Color(0xFF7B68EE)),
              _buildSummaryTile(
                  "إجمالي الالتزامات بـ 5%",
                  "${_formatLargeNumber(totalOblWithFivePercent)} ج.م",
                  Icons.account_balance_wallet,
                  const Color(0xFF8E44AD)),
              _buildSummaryTile(
                  "الحد الأعلى للبطاقات",
                  "${_formatLargeNumber(cardHighest)} ج.م",
                  Icons.trending_up,
                  Colors.amberAccent),
              _buildSummaryTile(
                  "إجمالي الالتزامات",
                  "${_formatLargeNumber(totalObl)} ج.م",
                  Icons.payments,
                  const Color(0xFFFF6B6B)),
              _buildSummaryTile(
                  "حد الـ DBR المسموح (50%)",
                  "${_formatLargeNumber(maxAllowed)} ج.م",
                  Icons.monetization_on,
                  TfcColors.primary),
              _buildSummaryTile("نسبة عبء الدين DBR",
                  "${dbr.toStringAsFixed(1)}%", Icons.speed, dbrColor),
              _buildSummaryTile(
                  "المتاح لقسط جديد",
                  "${_formatLargeNumber(available)} ج.م",
                  Icons.savings,
                  available > 0 ? TfcColors.primary : const Color(0xFFFF6B6B)),
            ],
          ),
          if (salary > 0 && dbr > 0) ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "مؤشر عبء الدين (DBR): ${dbr.toStringAsFixed(1)}% من الحد الأقصى 50%",
                  style: TextStyle(fontSize: 12, color: dbrColor),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (dbr / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor:
                        Colors.white.withAlpha((0.08 * 255).toInt()),
                    valueColor: AlwaysStoppedAnimation<Color>(dbrColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.2 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 10, color: color),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }

  void _confirmDeleteClient(BuildContext context, ClientModel client) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: TfcColors.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 56),
              const SizedBox(height: 16),
              const Text(
                "تأكيد حذف العميل",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.redAccent),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 12),
              Text(
                "هل أنت متأكد من حذف العميل \"${client.fullName}\" نهائياً؟\nسيتم حذف جميع بياناته بما في ذلك القروض والبطاقات والمستندات وسجل المتابعة.\n\nهذا الإجراء لا يمكن التراجع عنه.",
                style: const TextStyle(
                    color: TfcColors.outline, fontSize: 14, height: 1.6),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: TfcColors.outline),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text("إلغاء",
                          style: TextStyle(color: TfcColors.outline)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_forever,
                          color: Colors.white, size: 20),
                      label: const Text("حذف نهائياً",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        await ref
                            .read(clientProvider.notifier)
                            .deleteClient(client.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  "تم حذف العميل \"${client.fullName}\" بنجاح",
                                  textAlign: TextAlign.right),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          widget.onBack();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditClientDialog(
      BuildContext context, ClientModel client, String staffName) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: client.fullName);
    final phoneCtrl = TextEditingController(text: client.phoneNumber);
    final secPhoneCtrl =
        TextEditingController(text: client.secondaryPhoneNumber ?? '');
    final nationalIdCtrl = TextEditingController(text: client.nationalId);
    final birthDateCtrl = TextEditingController(text: client.birthDate);
    final companyCtrl = TextEditingController(text: client.companyName ?? '');
    final jobCtrl = TextEditingController(text: client.jobTitle ?? '');
    final amountCtrl =
        TextEditingController(text: client.requestedAmount.toString());
    final scoreCtrl =
        TextEditingController(text: client.creditScore.toString());
    final repCtrl =
        TextEditingController(text: client.representativeName ?? '');

    // Map legacy employment type values to new ones
    const legacyEmploymentMap = {
      'government_sector': 'government_employee',
    };
    const validEmploymentTypes = [
      'government_employee', 'private_sector', 'business_owner',
      'doctor_clinic', 'doctor_hospital', 'pharmacist', 'pharmacist_owner',
      'military', 'faculty', 'teacher', 'freelance', 'retired', 'other',
    ];
    String employment = legacyEmploymentMap[client.employmentType] 
        ?? (validEmploymentTypes.contains(client.employmentType) 
            ? client.employmentType 
            : 'other');
    String salaryMethod = client.salaryTransferMethod;
    bool insured = client.isInsured;
    const egyptGovernorates = [
      "القاهرة",
      "الجيزة",
      "الإسكندرية",
      "الدقهلية",
      "البحر الأحمر",
      "البحيرة",
      "الفيوم",
      "الغربية",
      "الإسماعيلية",
      "المنوفية",
      "المنيا",
      "القليوبية",
      "الوادي الجديد",
      "السويس",
      "أسوان",
      "أسيوط",
      "بني سويف",
      "بورسعيد",
      "دمياط",
      "الشرقية",
      "جنوب سيناء",
      "كفر الشيخ",
      "مطروح",
      "الأقصر",
      "قنا",
      "شمال سيناء",
      "سوهاج"
    ];

    String gov = egyptGovernorates.contains(client.governorate)
        ? client.governorate
        : "القاهرة";
    bool showSecondaryPhone = client.secondaryPhoneNumber != null &&
        client.secondaryPhoneNumber!.isNotEmpty;

    // Salary detail controllers
    final List<Map<String, TextEditingController>> salaryBankEntries =
        client.salaryBankDetails.isNotEmpty
            ? client.salaryBankDetails
                .map((e) => {
                      'bank': TextEditingController(text: e['bank'] ?? ''),
                      'amount': TextEditingController(text: e['amount'] ?? ''),
                    })
                .toList()
            : [
                {
                  'bank': TextEditingController(),
                  'amount': TextEditingController()
                }
              ];
    final cashSalaryCtrl = TextEditingController(
        text: client.cashSalaryAmount != null
            ? client.cashSalaryAmount.toString()
            : '');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: TfcColors.surfaceDim,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withAlpha(20)),
              ),
              title: const Text(
                "تعديل ملف العميل",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: TfcColors.primary),
                textAlign: TextAlign.right,
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),

                        // Header Section: Personal Data
                        const Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(Icons.person,
                                color: TfcColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "البيانات الشخصية للعميل",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: TfcColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 1. Full Name & Primary Phone
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "الاسم الكامل (ثلاثي كما في البطاقة)",
                                child: TextFormField(
                                  controller: nameCtrl,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      hintText: "أحمد بن عبد الله القحطاني"),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? "مطلوب" : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "رقم الهاتف المحمول",
                                child: TextFormField(
                                  controller: phoneCtrl,
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      hintText: "05XXXXXXXX"),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? "مطلوب" : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Dynamic Secondary Phone Toggler & Input
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: showSecondaryPhone
                              ? Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Expanded(
                                      child: _buildFormField(
                                        label: "رقم الهاتف الإضافي",
                                        child: TextFormField(
                                          controller: secPhoneCtrl,
                                          textAlign: TextAlign.right,
                                          keyboardType: TextInputType.phone,
                                          decoration: InputDecoration(
                                            hintText: "05XXXXXXXX",
                                            suffixIcon: IconButton(
                                              icon: const Icon(
                                                  Icons.remove_circle,
                                                  color: Colors.redAccent,
                                                  size: 20),
                                              tooltip: "إزالة الرقم الإضافي",
                                              onPressed: () {
                                                setState(() {
                                                  showSecondaryPhone = false;
                                                  secPhoneCtrl.clear();
                                                });
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Expanded(child: SizedBox()),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      foregroundColor: TfcColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        showSecondaryPhone = true;
                                      });
                                    },
                                    icon: const Icon(Icons.add_circle_outline,
                                        size: 18),
                                    label: const Text("إضافة رقم هاتف آخر",
                                        style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),

                        // 2. National ID & Birth Date
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "الرقم القومي (14 رقم)",
                                child: TextFormField(
                                  controller: nationalIdCtrl,
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      hintText: "10029384758694"),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    if (v.trim().length < 10) {
                                      return "يرجى كتابة رقم صحيح";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "تاريخ الميلاد",
                                child: TextFormField(
                                  controller: birthDateCtrl,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      hintText: "YYYY-MM-DD"),
                                  validator: (v) =>
                                      v!.trim().isEmpty ? "مطلوب" : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 3. Employment Type & Company Name
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "نوع التوظيف",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: employment,
                                      dropdownColor: TfcColors.surfaceDim,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                            value: "government_employee",
                                            child: Text("موظف حكومى",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "private_sector",
                                            child: Text("موظف قطاع خاص",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "business_owner",
                                            child: Text("صاحب عمل",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "doctor_clinic",
                                            child: Text("دكتور عيادة",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "doctor_hospital",
                                            child: Text("دكتور مستشفى",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "pharmacist",
                                            child: Text("صيدلى",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "pharmacist_owner",
                                            child: Text("صيدلى صاحب صيدلية",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "military",
                                            child: Text("قوات مسلحة",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "faculty",
                                            child: Text("هيئة تدريس",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "teacher",
                                            child: Text("مدرس",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "freelance",
                                            child: Text("فريلانس",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "retired",
                                            child: Text("معاش",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "other",
                                            child: Text("أخرى",
                                                textDirection:
                                                    TextDirection.rtl)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => employment = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "اسم جهة العمل / الشركة",
                                child: TextFormField(
                                  controller: companyCtrl,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      hintText: "مثال: أرامكو للخدمات"),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 4. Job Title & Insured Status (Radios)
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "المسمى الوظيفي الحالي",
                                child: TextFormField(
                                  controller: jobCtrl,
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      hintText: "مثال: مهندس برمجيات رئيسي"),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "حالة التأمين الاجتماعي",
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Radio<bool>(
                                      value: true,
                                      // ignore: deprecated_member_use
                                      groupValue: insured,
                                      activeColor: TfcColors.primary,
                                      // ignore: deprecated_member_use
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => insured = val);
                                        }
                                      },
                                    ),
                                    const Text("مؤمن عليه",
                                        style: TextStyle(fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Radio<bool>(
                                      value: false,
                                      // ignore: deprecated_member_use
                                      groupValue: insured,
                                      activeColor: TfcColors.primary,
                                      // ignore: deprecated_member_use
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => insured = val);
                                        }
                                      },
                                    ),
                                    const Text("غير مؤمن",
                                        style: TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 5. Salary Transfer Method (Radios)
                        _buildFormField(
                          label: "طريقة تحويل الراتب",
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Radio<String>(
                                value: "bank_transfer",
                                // ignore: deprecated_member_use
                                groupValue: salaryMethod,
                                activeColor: TfcColors.primary,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => salaryMethod = val);
                                  }
                                },
                              ),
                              const Text("تحويل راتب للبنك",
                                  style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 24),
                              Radio<String>(
                                value: "cash",
                                // ignore: deprecated_member_use
                                groupValue: salaryMethod,
                                activeColor: TfcColors.primary,
                                // ignore: deprecated_member_use
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => salaryMethod = val);
                                  }
                                },
                              ),
                              const Text("إيداع نقدي / شيك",
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                        // Dynamic Salary Details Section
                        const SizedBox(height: 12),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: salaryMethod == "bank_transfer"
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Text(
                                          "تفاصيل الحسابات البنكية المحول عليها الراتب",
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: TfcColors.secondary),
                                        ),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                              foregroundColor:
                                                  TfcColors.primary),
                                          onPressed: () {
                                            setState(() {
                                              salaryBankEntries.add({
                                                'bank': TextEditingController(),
                                                'amount':
                                                    TextEditingController(),
                                              });
                                            });
                                          },
                                          icon: const Icon(Icons.add_circle,
                                              size: 16),
                                          label: const Text("إضافة حساب بنكي",
                                              style: TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(salaryBankEntries.length,
                                        (idx) {
                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          textDirection: TextDirection.rtl,
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: _buildFormField(
                                                label: "اسم البنك",
                                                child: TextFormField(
                                                  controller:
                                                      salaryBankEntries[idx]
                                                          ['bank'],
                                                  textAlign: TextAlign.right,
                                                  decoration:
                                                      const InputDecoration(
                                                          hintText:
                                                              "اسم البنك"),
                                                  validator: (v) => v!.isEmpty
                                                      ? "مطلوب"
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: _buildFormField(
                                                label: "المبلغ (ج.م)",
                                                child: TextFormField(
                                                  controller:
                                                      salaryBankEntries[idx]
                                                          ['amount'],
                                                  textAlign: TextAlign.right,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  decoration:
                                                      const InputDecoration(
                                                          hintText: "0.00"),
                                                  validator: (v) => v!.isEmpty
                                                      ? "مطلوب"
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (salaryBankEntries.length >
                                                1) ...[
                                              const SizedBox(width: 8),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 24.0),
                                                child: IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      color: Colors.redAccent,
                                                      size: 20),
                                                  onPressed: () {
                                                    setState(() {
                                                      salaryBankEntries
                                                          .removeAt(idx);
                                                    });
                                                  },
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                  ],
                                )
                              : _buildFormField(
                                  label: "قيمة الراتب النقدي (ج.م)",
                                  child: TextFormField(
                                    controller: cashSalaryCtrl,
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        hintText: "قيمة الراتب النقدي"),
                                    validator: (v) =>
                                        v!.isEmpty ? "مطلوب" : null,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white10),
                        const SizedBox(height: 12),

                        // Header Section: Request Data
                        const Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Icon(Icons.description,
                                color: TfcColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              "بيانات الطلب والتمويل",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: TfcColors.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 6. Governorate & Requested Amount
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "المحافظة",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: gov,
                                      dropdownColor: TfcColors.surfaceDim,
                                      isExpanded: true,
                                      items: egyptGovernorates.map((g) {
                                        return DropdownMenuItem(
                                          value: g,
                                          child: Text(g,
                                              textDirection: TextDirection.rtl),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => gov = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "مبلغ التمويل المطلوب (ج.م)",
                                child: TextFormField(
                                  controller: amountCtrl,
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      double.tryParse(v ?? '') == null
                                          ? "أدخل رقم صحيح"
                                          : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 7. Credit Score (I-SCORE) & Rep Name
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              child: _buildFormField(
                                label: "تقييم آي سكور (300-850)",
                                child: TextFormField(
                                  controller: scoreCtrl,
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    final val = int.tryParse(v ?? '');
                                    if (val == null || val < 300 || val > 850) {
                                      return "التقييم بين 300 و 850";
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildFormField(
                                label: "المندوب المسؤول",
                                child: Builder(
                                  builder: (context) {
                                    final empState =
                                        ref.watch(employeesProvider);
                                    final companyStaff = empState.employees
                                        .where((e) =>
                                            e.isConfirmed &&
                                            (e.role == 'admin' ||
                                                e.role == 'manager' ||
                                                e.role == 'company_employee'))
                                        .toList();
                                    return DropdownButtonFormField<String>(
                                      initialValue: companyStaff.any(
                                              (e) => e.fullName == repCtrl.text)
                                          ? repCtrl.text
                                          : null,
                                      dropdownColor: TfcColors.surfaceContainer,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        hintText: "اختر المندوب المسؤول",
                                        prefixIcon: Icon(Icons.person_search,
                                            color: TfcColors.outline),
                                      ),
                                      items: companyStaff
                                          .map((e) => DropdownMenuItem(
                                                value: e.fullName,
                                                child: Text(e.fullName,
                                                    textDirection:
                                                        TextDirection.rtl),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() => repCtrl.text = v);
                                        }
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء",
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.primary,
                    foregroundColor: TfcColors.onPrimary,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final updated = client.copyWith(
                      fullName: nameCtrl.text.trim(),
                      phoneNumber: phoneCtrl.text.trim(),
                      secondaryPhoneNumber: showSecondaryPhone &&
                              secPhoneCtrl.text.trim().isNotEmpty
                          ? secPhoneCtrl.text.trim()
                          : null,
                      nationalId: nationalIdCtrl.text.trim(),
                      birthDate: birthDateCtrl.text.trim(),
                      companyName: companyCtrl.text.trim().isEmpty
                          ? null
                          : companyCtrl.text.trim(),
                      jobTitle: jobCtrl.text.trim().isEmpty
                          ? null
                          : jobCtrl.text.trim(),
                      employmentType: employment,
                      isInsured: insured,
                      salaryTransferMethod: salaryMethod,
                      salaryBankDetails: salaryMethod == 'bank_transfer'
                          ? salaryBankEntries
                              .map((e) => {
                                    'bank': e['bank']!.text.trim(),
                                    'amount': e['amount']!.text.trim(),
                                  })
                              .toList()
                          : [],
                      cashSalaryAmount: salaryMethod == 'cash'
                          ? double.tryParse(cashSalaryCtrl.text)
                          : null,
                      requestedAmount: double.tryParse(amountCtrl.text) ?? 0.0,
                      creditScore: int.tryParse(scoreCtrl.text) ?? 600,
                      governorate: gov,
                      representativeName: repCtrl.text.trim().isEmpty
                          ? null
                          : repCtrl.text.trim(),
                    );

                    final errorMsg = await ref
                        .read(clientProvider.notifier)
                        .updateClient(updated, staffName: staffName);

                    if (errorMsg == null) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("تم تحديث بيانات العميل بنجاح",
                                textAlign: TextAlign.right),
                            backgroundColor: TfcColors.primary,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("خطأ في تحديث البيانات",
                                textAlign: TextAlign.right,
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            content: Text(errorMsg, textAlign: TextAlign.right),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("حسناً"),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  child: const Text("حفظ التعديلات"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEditLoanDialog(
      BuildContext context, ClientModel client, String staffName,
      {ExistingLoanModel? loan}) {
    final formKey = GlobalKey<FormState>();
    final bankCtrl = TextEditingController(text: loan?.bankName ?? '');
    final instCtrl = TextEditingController(
        text: loan?.installmentValue != null
            ? loan!.installmentValue.toString()
            : '');
    final notesCtrl = TextEditingController(text: loan?.notes ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TfcColors.surfaceDim,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withAlpha(20)),
          ),
          title: Text(
            loan == null ? "إضافة قسط قرض قائم" : "تعديل قسط قرض قائم",
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: TfcColors.primary),
            textAlign: TextAlign.right,
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFormField(
                    label: "اسم البنك / الجهة التمويلية",
                    child: TextFormField(
                      controller: bankCtrl,
                      textAlign: TextAlign.right,
                      validator: (v) =>
                          v!.trim().isEmpty ? "اسم البنك مطلوب" : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: "قيمة القسط الشهري (ج.م)",
                    child: TextFormField(
                      controller: instCtrl,
                      textAlign: TextAlign.right,
                      keyboardType: TextInputType.number,
                      validator: (v) => double.tryParse(v ?? '') == null
                          ? "الرجاء إدخال رقم صحيح"
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: "ملاحظات",
                    child: TextFormField(
                      controller: notesCtrl,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("إلغاء", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TfcColors.primary,
                foregroundColor: TfcColors.onPrimary,
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final updatedLoans =
                    List<ExistingLoanModel>.from(client.existingLoans);
                if (loan == null) {
                  // Add new loan
                  updatedLoans.add(ExistingLoanModel(
                    id: "l-${DateTime.now().millisecondsSinceEpoch}",
                    bankName: bankCtrl.text.trim(),
                    installmentValue: double.parse(instCtrl.text.trim()),
                    notes: notesCtrl.text.trim().isEmpty
                        ? null
                        : notesCtrl.text.trim(),
                  ));
                } else {
                  // Edit existing loan
                  final idx = updatedLoans
                      .indexWhere((element) => element.id == loan.id);
                  if (idx != -1) {
                    updatedLoans[idx] = loan.copyWith(
                      bankName: bankCtrl.text.trim(),
                      installmentValue: double.parse(instCtrl.text.trim()),
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                    );
                  }
                }

                final success = await ref
                    .read(clientProvider.notifier)
                    .updateClientLoans(client.id, updatedLoans,
                        staffName: staffName);

                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم حفظ بيانات القرض بنجاح",
                          textAlign: TextAlign.right),
                      backgroundColor: TfcColors.primary,
                    ),
                  );
                }
              },
              child: const Text("حفظ"),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditCardDialog(
      BuildContext context, ClientModel client, String staffName,
      {CreditCardRequestModel? card}) {
    final formKey = GlobalKey<FormState>();
    final bankCtrl = TextEditingController(text: card?.bankName ?? '');
    final valCtrl = TextEditingController(
        text: card?.value != null ? card!.value.toString() : '');
    final fivePercentCtrl = TextEditingController(
        text: card?.fivePercentCalc != null
            ? card!.fivePercentCalc.toString()
            : '');
    final instCtrl = TextEditingController(
        text: card?.installment != null ? card!.installment.toString() : '');
    final highestCtrl = TextEditingController(
        text: card?.highestValue != null
            ? card!.highestValue.toString()
            : '');
    final notesCtrl = TextEditingController(text: card?.notes ?? '');
    final durationCtrl =
        TextEditingController(text: card?.duration ?? '');

    String type = card?.type ?? 'card';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void recalculate() {
              final val = double.tryParse(valCtrl.text) ?? 0.0;
              final calc = val * 0.05;
              fivePercentCtrl.text =
                  calc > 0 ? calc.toStringAsFixed(2) : '0.00';

              final inst = type == 'request'
                  ? (double.tryParse(instCtrl.text) ?? 0.0)
                  : 0.0;
              final highestVal = calc > inst ? calc : inst;
              highestCtrl.text =
                  highestVal > 0 ? highestVal.toStringAsFixed(2) : '0.00';
            }

            return AlertDialog(
              backgroundColor: TfcColors.surfaceDim,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withAlpha(20)),
              ),
              title: Text(
                card == null
                    ? "تقديم بطاقة / طلب جديد"
                    : "تعديل بطاقة / طلب ائتماني",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: TfcColors.primary),
                textAlign: TextAlign.right,
              ),
              content: SizedBox(
                width: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Row 1: Bank Name, Limit Value, 5% calculation
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildFormField(
                                label: "اسم البنك",
                                child: TextFormField(
                                  controller: bankCtrl,
                                  textAlign: TextAlign.right,
                                  validator: (v) => v!.trim().isEmpty
                                      ? "اسم البنك مطلوب"
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildFormField(
                                label: "قيمة الليمت",
                                child: TextFormField(
                                  controller: valCtrl,
                                  textAlign: TextAlign.right,
                                  keyboardType: TextInputType.number,
                                  validator: (v) =>
                                      double.tryParse(v ?? '') == null
                                          ? "الرجاء إدخال رقم صحيح"
                                          : null,
                                  onChanged: (v) => setState(recalculate),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildFormField(
                                label: "قيمة الـ 5%",
                                child: TextFormField(
                                  controller: fivePercentCtrl,
                                  textAlign: TextAlign.right,
                                  readOnly: true,
                                  style: const TextStyle(
                                      color: TfcColors.secondary,
                                      fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: "0.00",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Row 2: Type, Duration, Installment, Highest Limit
                        Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildFormField(
                                label: "النوع",
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(10),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: type,
                                      dropdownColor: TfcColors.surfaceDim,
                                      isExpanded: true,
                                      items: const [
                                        DropdownMenuItem(
                                            value: "card",
                                            child: Text("بطاقة",
                                                textDirection:
                                                    TextDirection.rtl)),
                                        DropdownMenuItem(
                                            value: "request",
                                            child: Text("أبلكيشن",
                                                textDirection:
                                                    TextDirection.rtl)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            type = val;
                                            recalculate();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildFormField(
                                label: "المدة",
                                child: TextFormField(
                                  controller: durationCtrl,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (type == 'request') ...[
                              Expanded(
                                flex: 2,
                                child: _buildFormField(
                                  label: "قيمة القسط",
                                  child: TextFormField(
                                    controller: instCtrl,
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return null;
                                      }
                                      return double.tryParse(v) == null
                                          ? "الرجاء إدخال رقم صحيح"
                                          : null;
                                    },
                                    onChanged: (v) => setState(recalculate),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              flex: 2,
                              child: _buildFormField(
                                label: "الحد الأعلى",
                                child: TextFormField(
                                  controller: highestCtrl,
                                  textAlign: TextAlign.right,
                                  readOnly: true,
                                  style: const TextStyle(
                                      color: Colors.amberAccent,
                                      fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: "0.00",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Row 3: Notes
                        _buildFormField(
                          label: "ملاحظات إضافية",
                          child: TextFormField(
                            controller: notesCtrl,
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              hintText:
                                  "تفاصيل أو ملاحظات إضافية بخصوص البطاقة أو الطلب...",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("إلغاء",
                      style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TfcColors.primary,
                    foregroundColor: TfcColors.onPrimary,
                  ),
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;

                    final updatedCards = List<CreditCardRequestModel>.from(
                        client.creditCardsRequests);
                    final value = double.parse(valCtrl.text.trim());
                    final fivePercent = value * 0.05;
                    final installment = type == 'request'
                        ? (double.tryParse(instCtrl.text.trim()) ?? 0.0)
                        : 0.0;
                    final highestValue = double.parse(highestCtrl.text.trim());

                    if (card == null) {
                      // Add new card
                      updatedCards.add(CreditCardRequestModel(
                        id: "cc-${DateTime.now().millisecondsSinceEpoch}",
                        bankName: bankCtrl.text.trim(),
                        value: value,
                        fivePercentCalc: fivePercent,
                        type: type,
                        duration: durationCtrl.text.trim(),
                        installment: installment,
                        highestValue: highestValue,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      ));
                    } else {
                      // Edit existing card
                      final idx = updatedCards
                          .indexWhere((element) => element.id == card.id);
                      if (idx != -1) {
                        updatedCards[idx] = card.copyWith(
                          bankName: bankCtrl.text.trim(),
                          value: value,
                          fivePercentCalc: fivePercent,
                          type: type,
                          duration: durationCtrl.text.trim(),
                          installment: installment,
                          highestValue: highestValue,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        );
                      }
                    }

                    final success = await ref
                        .read(clientProvider.notifier)
                        .updateClientCards(client.id, updatedCards,
                            staffName: staffName);

                    if (success && context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم حفظ بيانات البطاقة بنجاح",
                              textAlign: TextAlign.right),
                          backgroundColor: TfcColors.primary,
                        ),
                      );
                    }
                  },
                  child: const Text("حفظ"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDeleteLoanOrCard(BuildContext context,
      {required String clientId,
      String? loanId,
      String? cardId,
      required String staffName}) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: TfcColors.surfaceDim,
          title: const Text("تأكيد الحذف",
              style: TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.right),
          content: const Text(
              "هل أنت متأكد من رغبتك في حذف هذا البند من التزامات العميل؟",
              textAlign: TextAlign.right),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("إلغاء", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final success =
                    await ref.read(clientProvider.notifier).removeLoanOrCard(
                          clientId: clientId,
                          loanId: loanId,
                          cardId: cardId,
                          staffName: staffName,
                        );
                if (success && context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم حذف البند بنجاح",
                          textAlign: TextAlign.right),
                      backgroundColor: TfcColors.primary,
                    ),
                  );
                }
              },
              child: const Text("حذف"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              color: TfcColors.onSurfaceVariant,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
  Color _getCreditScoreColorValue(int score) {
    if (score >= 720) return TfcColors.success;
    if (score >= 620) return Colors.amber;
    return Colors.redAccent;
  }

  Widget _buildClientsTable(List<ClientModel> clients, bool showNationalId, bool showCreditScore) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 16,
      borderColor: Colors.white.withValues(alpha: 0.05),
      fillColor: TfcColors.surfaceDim.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.table_rows, color: TfcColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "جدول طلبات العملاء الحاليين",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: TfcColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  "إجمالي الطلبات: ${clients.length}",
                  style: const TextStyle(color: TfcColors.outline, fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          if (clients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                  "لا توجد طلبات عملاء مطابقة للبحث حالياً.",
                  style: TextStyle(color: TfcColors.outline, fontSize: 14),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.white.withValues(alpha: 0.02),
                    ),
                    dataRowMinHeight: 64,
                    dataRowMaxHeight: 72,
                    dividerThickness: 0.5,
                    columns: const [
                      DataColumn(
                        label: Text(
                          "اسم العميل",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "الرقم القومي",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "التمويل المطلوب",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "سكور الائتمان",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "الحالة",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "المندوب",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "الإجراءات",
                          style: TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: clients.map((client) {
                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                if (widget.onClientSelected != null) {
                                  widget.onClientSelected!(client.id);
                                }
                              },
                              child: Text(
                                client.fullName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              showNationalId ? client.nationalId : "••••••••••••••",
                              style: TextStyle(
                                color: showNationalId ? TfcColors.onSurface : Colors.orangeAccent.withValues(alpha: 0.6),
                                fontStyle: showNationalId ? FontStyle.normal : FontStyle.italic,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              "${_formatLargeNumber(client.requestedAmount)} ج.م",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          DataCell(
                            showCreditScore
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getCreditScoreColorValue(client.creditScore).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _getCreditScoreColorValue(client.creditScore).withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      client.creditScore.toString(),
                                      style: TextStyle(
                                        color: _getCreditScoreColorValue(client.creditScore),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  )
                                : Text(
                                    "مخفي 🔒",
                                    style: TextStyle(
                                      color: Colors.orangeAccent.withValues(alpha: 0.6),
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                          ),
                          DataCell(_buildSimpleStatusChip(client.status)),
                          DataCell(Text(client.representativeName ?? "-")),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: TfcColors.primary, size: 14),
                              tooltip: "عرض التفاصيل",
                              onPressed: () {
                                // No onClientSelected in VirtualIncomeBento; no action
                                // placeholder for navigation if needed
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Confirm delete individual compound unit
  void _confirmDeleteCompoundUnit(BuildContext context, ClientModel client, int index, String staffName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("حذف وحدة الكمبوند", textDirection: TextDirection.rtl, style: TextStyle(color: Colors.white)),
        content: Text("هل أنت تأكد من حذف هذه الوحدة (#${index + 1}) من حساب العميل؟", textDirection: TextDirection.rtl, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              final list = List<Map<String, dynamic>>.from(client.compoundUnitsData);
              if (index >= 0 && index < list.length) {
                list.removeAt(index);
                final updated = client.copyWith(hasCompoundUnit: list.isNotEmpty, compoundUnitsData: list);
                final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error ?? "تم حذف الوحدة بنجاح"), backgroundColor: error == null ? Colors.green : Colors.redAccent),
                  );
                }
              }
            },
            child: const Text("حذف النهائي", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Compound Units Management Dialog
  // =====================================================
  void _showManageCompoundUnitsDialog(BuildContext context, ClientModel client, String staffName) {
    showDialog(
      context: context,
      builder: (ctx) {
        final List<Map<String, dynamic>> uiEntries = [];
        for (var u in client.compoundUnitsData) {
          final List<dynamic> rawFiles = u['unitContractFiles'] ?? [];
          final files = rawFiles.map((e) => ClientDocumentModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
          uiEntries.add({
            'compoundName': TextEditingController(text: u['compoundName']?.toString() ?? ''),
            'developerName': TextEditingController(text: u['developerName']?.toString() ?? ''),
            'contractDate': TextEditingController(text: u['contractDate']?.toString() ?? ''),
            'unitValue': TextEditingController(text: u['unitValue']?.toString() ?? ''),
            'downPayment': TextEditingController(text: u['downPayment']?.toString() ?? ''),
            'paidInstallmentsCount': TextEditingController(text: u['paidInstallmentsCount']?.toString() ?? ''),
            'paidAmount': TextEditingController(text: u['paidAmount']?.toString() ?? ''),
            'unitContractFiles': files,
          });
        }
        if (uiEntries.isEmpty) {
          uiEntries.add({
            'compoundName': TextEditingController(),
            'developerName': TextEditingController(),
            'contractDate': TextEditingController(),
            'unitValue': TextEditingController(),
            'downPayment': TextEditingController(),
            'paidInstallmentsCount': TextEditingController(),
            'paidAmount': TextEditingController(),
            'unitContractFiles': <ClientDocumentModel>[],
          });
        }
        return StatefulBuilder(builder: (ctx2, setDialogState) {
          return AlertDialog(
            title: const Text("إدارة وحدات الكمبوند", textAlign: TextAlign.right),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(children: [
                  ...uiEntries.asMap().entries.map((ent) {
                    final idx = ent.key;
                    final u = ent.value;
                    final files = u['unitContractFiles'] as List<ClientDocumentModel>;
                    final valCtrl = u['unitValue'] as TextEditingController;
                    final downCtrl = u['downPayment'] as TextEditingController;
                    double pct = 0;
                    final v = double.tryParse(valCtrl.text) ?? 0;
                    final d = double.tryParse(downCtrl.text) ?? 0;
                    if (v > 0) pct = (d / v) * 100;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, textDirection: TextDirection.rtl, children: [
                          Text("الوحدة #${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (uiEntries.length > 1) IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => setDialogState(() => uiEntries.removeAt(idx))),
                        ]),
                        const SizedBox(height: 8),
                        _buildDialogRow("اسم الكمبوند", u['compoundName'], "اسم المطور", u['developerName']),
                        const SizedBox(height: 8),
                        _buildDialogRow("تاريخ التعاقد", u['contractDate'], "قيمة الوحدة", u['unitValue'], isNumber2: true),
                        const SizedBox(height: 8),
                        Row(textDirection: TextDirection.rtl, children: [
                          Expanded(child: _buildDialogFormField(label: "المقدم المدفوع", child: TextFormField(controller: downCtrl, textAlign: TextAlign.right, keyboardType: TextInputType.number, onChanged: (_) => setDialogState(() {})))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDialogFormField(label: "نسبة المقدم", child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                            child: Text("${pct.toStringAsFixed(1)}%", textAlign: TextAlign.right, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                          ))),
                        ]),
                        const SizedBox(height: 8),
                        _buildDialogRow("عدد الأقساط المدفوعة", u['paidInstallmentsCount'], "قيمة ما تم دفعه", u['paidAmount'], isNumber1: true, isNumber2: true),
                        const SizedBox(height: 8),
                        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          const Text("صورة عقد الوحدة", textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: TfcColors.secondary)),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: () {
                              DocumentUploadHelper.showUploadDialog(ctx2, onUploadComplete: (name, url) {
                                setDialogState(() { files.add(ClientDocumentModel(id: "unit-doc-${DateTime.now().millisecondsSinceEpoch}", documentName: "عقد وحدة: $name", documentUrl: url, status: "pending")); });
                              });
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary.withValues(alpha: 0.1), foregroundColor: TfcColors.primary),
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: const Text("رفع ملف العقد", style: TextStyle(fontSize: 12)),
                          ),
                          if (files.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...files.map((file) => Row(textDirection: TextDirection.rtl, children: [
                              Expanded(child: Text(file.documentName.replaceAll("عقد وحدة: ", ""), style: const TextStyle(fontSize: 11, color: Colors.white70), overflow: TextOverflow.ellipsis)),
                              IconButton(icon: const Icon(Icons.close, size: 14, color: Colors.redAccent), onPressed: () => setDialogState(() => files.remove(file))),
                            ])),
                          ],
                        ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setDialogState(() => uiEntries.add({
                      'compoundName': TextEditingController(), 'developerName': TextEditingController(),
                      'contractDate': TextEditingController(), 'unitValue': TextEditingController(),
                      'downPayment': TextEditingController(), 'paidInstallmentsCount': TextEditingController(),
                      'paidAmount': TextEditingController(), 'unitContractFiles': <ClientDocumentModel>[],
                    })),
                    icon: const Icon(Icons.add_circle), label: const Text("إضافة وحدة أخرى"),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  final list = uiEntries.map((u) => {
                    'compoundName': (u['compoundName'] as TextEditingController).text.trim(),
                    'developerName': (u['developerName'] as TextEditingController).text.trim(),
                    'contractDate': (u['contractDate'] as TextEditingController).text.trim(),
                    'unitValue': double.tryParse((u['unitValue'] as TextEditingController).text) ?? 0.0,
                    'downPayment': double.tryParse((u['downPayment'] as TextEditingController).text) ?? 0.0,
                    'paidInstallmentsCount': int.tryParse((u['paidInstallmentsCount'] as TextEditingController).text) ?? 0,
                    'paidAmount': double.tryParse((u['paidAmount'] as TextEditingController).text) ?? 0.0,
                    'unitContractFiles': (u['unitContractFiles'] as List<ClientDocumentModel>).map((e) => e.toJson()).toList(),
                  }).toList();
                  final updated = client.copyWith(hasCompoundUnit: list.isNotEmpty, compoundUnitsData: list);
                  final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                  if (ctx2.mounted) {
                    Navigator.pop(ctx2);
                    ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text(error ?? "تم حفظ التعديلات بنجاح")));
                  }
                },
                child: const Text("حفظ التغييرات"),
              ),
            ],
          );
        });
      },
    );
  }

  // =====================================================
  // Modern Cars Management Dialog
  // =====================================================
  void _showManageModernCarsDialog(BuildContext context, ClientModel client, String staffName) {
    showDialog(
      context: context,
      builder: (ctx) {
        final List<Map<String, dynamic>> uiEntries = [];
        for (var c in client.modernCarsData) {
          uiEntries.add({
            'carType': TextEditingController(text: c['carType']?.toString() ?? ''),
            'carModel': TextEditingController(text: c['carModel']?.toString() ?? ''),
            'carTodayValue': TextEditingController(text: c['carTodayValue']?.toString() ?? ''),
            'licenseStatus': c['licenseStatus']?.toString() ?? 'بدون حظر',
          });
        }
        if (uiEntries.isEmpty) {
          uiEntries.add({
            'carType': TextEditingController(), 'carModel': TextEditingController(),
            'carTodayValue': TextEditingController(), 'licenseStatus': 'بدون حظر',
          });
        }
        return StatefulBuilder(builder: (ctx2, setDialogState) {
          return AlertDialog(
            title: const Text("إدارة السيارات الحديثة", textAlign: TextAlign.right),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(children: [
                  ...uiEntries.asMap().entries.map((ent) {
                    final idx = ent.key;
                    final c = ent.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
                      child: Column(children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, textDirection: TextDirection.rtl, children: [
                          Text("السيارة #${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (uiEntries.length > 1) IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18), onPressed: () => setDialogState(() => uiEntries.removeAt(idx))),
                        ]),
                        const SizedBox(height: 8),
                        _buildDialogRow("نوع السيارة", c['carType'], "موديل كام", c['carModel']),
                        const SizedBox(height: 8),
                        Row(textDirection: TextDirection.rtl, children: [
                          Expanded(child: _buildDialogFormField(label: "قيمة سعر السيارة اليوم", child: TextFormField(controller: c['carTodayValue'] as TextEditingController, textAlign: TextAlign.right, keyboardType: TextInputType.number))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDialogFormField(label: "الرخصة", child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                              value: c['licenseStatus'] as String, dropdownColor: TfcColors.surfaceDim, isExpanded: true,
                              items: const [DropdownMenuItem(value: 'عليها حظر', child: Text("عليها حظر")), DropdownMenuItem(value: 'بدون حظر', child: Text("بدون حظر"))],
                              onChanged: (val) { if (val != null) setDialogState(() => c['licenseStatus'] = val); },
                            )),
                          ))),
                        ]),
                      ]),
                    );
                  }),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => setDialogState(() => uiEntries.add({
                      'carType': TextEditingController(), 'carModel': TextEditingController(),
                      'carTodayValue': TextEditingController(), 'licenseStatus': 'بدون حظر',
                    })),
                    icon: const Icon(Icons.add_circle), label: const Text("إضافة سيارة أخرى"),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  final list = uiEntries.map((c) => {
                    'carType': (c['carType'] as TextEditingController).text.trim(),
                    'carModel': (c['carModel'] as TextEditingController).text.trim(),
                    'carTodayValue': double.tryParse((c['carTodayValue'] as TextEditingController).text) ?? 0.0,
                    'licenseStatus': c['licenseStatus'],
                  }).toList();
                  final updated = client.copyWith(hasModernCar: list.isNotEmpty, modernCarsData: list);
                  final error = await ref.read(clientProvider.notifier).updateClient(updated, staffName: staffName);
                  if (ctx2.mounted) {
                    Navigator.pop(ctx2);
                    ScaffoldMessenger.of(ctx2).showSnackBar(SnackBar(content: Text(error ?? "تم حفظ التعديلات بنجاح")));
                  }
                },
                child: const Text("حفظ التغييرات"),
              ),
            ],
          );
        });
      },
    );
  }


  Widget _buildDialogRow(String label1, dynamic ctrl1, String label2, dynamic ctrl2, {bool isNumber1 = false, bool isNumber2 = false}) {
    return Row(textDirection: TextDirection.rtl, children: [
      Expanded(child: _buildDialogFormField(label: label1, child: TextFormField(controller: ctrl1 as TextEditingController, textAlign: TextAlign.right, keyboardType: isNumber1 ? TextInputType.number : TextInputType.text))),
      const SizedBox(width: 12),
      Expanded(child: _buildDialogFormField(label: label2, child: TextFormField(controller: ctrl2 as TextEditingController, textAlign: TextAlign.right, keyboardType: isNumber2 ? TextInputType.number : TextInputType.text))),
    ]);
  }
}


class VirtualIncomeBento extends ConsumerStatefulWidget {
  final ClientModel client;
  final String staffName;
  final RolePermissions permissions;

  const VirtualIncomeBento(
      {super.key,
      required this.client,
      required this.staffName,
      required this.permissions});

  @override
  ConsumerState<VirtualIncomeBento> createState() => _VirtualIncomeBentoState();
}

class _VirtualIncomeBentoState extends ConsumerState<VirtualIncomeBento> {
  // Helper to build status chip similar to _ClientDetailsScreenState
  Widget _buildSimpleStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'مقبول':
        chipColor = Colors.green;
        break;
      case 'مرفوض':
        chipColor = Colors.redAccent;
        break;
      default:
        chipColor = Colors.grey;
    }
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: chipColor,
    );
  }
  String _incomeType = 'card'; // 'card', 'valu'
  double? _selectedLimit;
  final TextEditingController _ratioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ratioController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ratioController.dispose();
    super.dispose();
  }

  String _formatLargeNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.permissions.fieldVisibility['salary'] == false) {
      return const GlassCard(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, color: TfcColors.outline),
              SizedBox(height: 8),
              Text("حسابات الدخل الافتراضي مخفية لعدم صلاحية عرض الراتب",
                  style: TextStyle(color: TfcColors.outline),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    double currentValue = _selectedLimit ?? 0.0;

    double ratio = double.tryParse(_ratioController.text) ?? 0.0;
    double dbr = 0.0;
    if (_incomeType == 'card') {
      dbr = ratio > 0 ? (currentValue / ratio) : 0.0;
    } else {
      dbr = (currentValue * ratio) / 2;
    }

    double loanInst = 0.0;
    double cardHighest = 0.0;
    for (var loan in widget.client.existingLoans) {
      loanInst += loan.installmentValue;
    }
    for (var card in widget.client.creditCardsRequests) {
      cardHighest += card.highestValue;
    }
    double totalObl = loanInst + cardHighest;

    double available = dbr - totalObl;

    final itemsList = widget.client.creditCardsRequests
        .where((c) =>
            _incomeType == 'card' ? c.type == 'card' : c.type == 'request')
        .toList();

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: TfcColors.primary.withAlpha((0.1 * 255).toInt()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withAlpha((0.15 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate,
                    color: TfcColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("الدخل الافتراضي",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Radio<String>(
                value: 'card',
                // ignore: deprecated_member_use
                groupValue: _incomeType,
                activeColor: TfcColors.primary,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _incomeType = val;
                      _selectedLimit = null;
                    });
                  }
                },
              ),
              const Text("بطاقة"),
              const SizedBox(width: 16),
              Radio<String>(
                value: 'valu',
                // ignore: deprecated_member_use
                groupValue: _incomeType,
                activeColor: TfcColors.primary,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _incomeType = val;
                      _selectedLimit = null;
                    });
                  }
                },
              ),
              const Text("فاليو"),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                flex: 2,
                child: itemsList.isEmpty
                    ? Text(
                        "لا توجد ${_incomeType == 'card' ? 'بطاقات' : 'طلبات'} مسجلة",
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(color: Colors.redAccent))
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.05 * 255).toInt()),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  Colors.white.withAlpha((0.1 * 255).toInt())),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<double>(
                            value: _selectedLimit,
                            dropdownColor: TfcColors.surfaceDim,
                            isExpanded: true,
                            hint: Text(
                                "اختر ${_incomeType == 'card' ? 'البطاقة' : 'الطلب'}",
                                textDirection: TextDirection.rtl),
                            items: itemsList.map((c) {
                              return DropdownMenuItem<double>(
                                value: c.value,
                                child: Text(
                                    "${c.bankName} - القيمة: ${_formatLargeNumber(c.value)}",
                                    textDirection: TextDirection.rtl),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedLimit = val);
                            },
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _ratioController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: "النسبة",
                    filled: true,
                    fillColor: Colors.white.withAlpha((0.05 * 255).toInt()),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              _buildResultBox(
                  "قيمة ${_incomeType == 'card' ? 'البطاقة' : 'فاليو'}",
                  "${_formatLargeNumber(currentValue)} ج.م",
                  Colors.blueAccent),
              _buildResultBox("حد الـ DBR", "${_formatLargeNumber(dbr)} ج.م",
                  Colors.purpleAccent),
              _buildResultBox(
                  "إجمالي الالتزامات",
                  "${_formatLargeNumber(totalObl)} ج.م",
                  const Color(0xFFFF6B6B)),
              _buildResultBox(
                  "المتاح لقسط جديد",
                  "${_formatLargeNumber(available)} ج.م",
                  available > 0 ? TfcColors.primary : Colors.redAccent),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: TfcColors.primary,
              foregroundColor: TfcColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              final typeStr = _incomeType == 'card' ? 'بطاقة' : 'فاليو';
              final limitStr = _formatLargeNumber(currentValue);
              final dbrStr = _formatLargeNumber(dbr);
              final totalOblStr = _formatLargeNumber(totalObl);
              final availableStr = _formatLargeNumber(available);
              final ratioStr = _ratioController.text.trim().isEmpty
                  ? '0'
                  : _ratioController.text.trim();

              final notes = "حساب دخل افتراضي ($typeStr):\n"
                  "- القيمة: $limitStr ج.م\n"
                  "- النسبة: $ratioStr\n"
                  "- حد الـ DBR المحسوب: $dbrStr ج.م\n"
                  "- إجمالي الالتزامات: $totalOblStr ج.م\n"
                  "- المتاح لقسط جديد: $availableStr ج.م";

              await ref.read(clientProvider.notifier).addInteractionLog(
                    widget.client.id,
                    "حساب دخل افتراضي",
                    notes,
                    widget.staffName,
                  );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("تم تسجيل الحساب في سجل التفاعلات بنجاح",
                        textAlign: TextAlign.right),
                    backgroundColor: TfcColors.primary,
                  ),
                );
              }
            },
            icon: const Icon(Icons.save, size: 18),
            label: const Text(
              "حفظ النتائج في سجل التفاعلات والنشاط",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBox(String title, String value, Color color) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.2 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title,
              style: TextStyle(fontSize: 11, color: color),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

// ============================================================
// Total Fees Summary Widget
// ============================================================
class _TotalFeesWidget extends ConsumerStatefulWidget {
  final String clientId;
  const _TotalFeesWidget({required this.clientId});

  @override
  ConsumerState<_TotalFeesWidget> createState() => _TotalFeesWidgetState();
}

class _TotalFeesWidgetState extends ConsumerState<_TotalFeesWidget> {
  bool _isLoading = true;
  double _totalFees = 0.0;
  double _collectedFees = 0.0;
  double _uncollectedFees = 0.0;
  int _invoiceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    try {
      if (!SupabaseConfig.isInitialized) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      List<dynamic> rows = [];
      try {
        final response = await SupabaseConfig.client
            .from('operation_entries')
            .select('has_invoice, invoice_fees, invoice_collected')
            .eq('client_id', widget.clientId)
            .eq('has_invoice', true);
        rows = response as List<dynamic>;
      } catch (_) {
        // If columns don't exist yet, no fees to show
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      double total = 0.0;
      double collected = 0.0;
      double uncollected = 0.0;
      int count = 0;

      for (final r in rows) {
        final fees = (r['invoice_fees'] as num?)?.toDouble() ?? 0.0;
        final status = r['invoice_collected'] as String?;
        total += fees;
        count++;
        if (status == 'collected') {
          collected += fees;
        } else {
          uncollected += fees;
        }
      }

      if (mounted) {
        setState(() {
          _totalFees = total;
          _collectedFees = collected;
          _uncollectedFees = uncollected;
          _invoiceCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading fees summary: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    // Listen for operations refresh to reload fees
    ref.listen<int>(operationsRefreshTriggerProvider, (prev, next) {
      _loadFees();
    });

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: TfcColors.primary),
        ),
      );
    }

    if (_invoiceCount == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, color: TfcColors.outline.withValues(alpha: 0.3), size: 40),
            const SizedBox(height: 10),
            const Text(
              "لا توجد فواتير أتعاب مسجلة لهذا العميل",
              style: TextStyle(color: TfcColors.outline, fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          // Main Total Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  TfcColors.primary.withValues(alpha: 0.08),
                  Colors.blueAccent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: TfcColors.primary.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TfcColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet, color: TfcColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("إجمالى الأتعاب المستحقة", style: TextStyle(color: TfcColors.outline, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(
                            "${_fmt(_totalFees)} ج.م",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: TfcColors.primary,
                            ),
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
                        "$_invoiceCount فاتورة",
                        style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Collected & Uncollected breakdown
          Row(
            children: [
              // Collected
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TfcColors.success.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TfcColors.success.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: TfcColors.success.withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 6),
                          const Text("تم التحصيل", style: TextStyle(color: TfcColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_fmt(_collectedFees)} ج.م",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: TfcColors.success),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Uncollected
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TfcColors.error.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TfcColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cancel_outlined, color: TfcColors.error.withValues(alpha: 0.7), size: 16),
                          const SizedBox(width: 6),
                          const Text("لم يتم التحصيل", style: TextStyle(color: TfcColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${_fmt(_uncollectedFees)} ج.م",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: TfcColors.error),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

