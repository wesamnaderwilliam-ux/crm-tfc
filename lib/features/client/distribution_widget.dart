import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/banks_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../models/client_model.dart';
import 'operations_widget.dart';

/// Representation of a Bank selection inside a program distribution
class BankSelection {
  String? id; // database primary key (uuid)
  String? bankId;
  String? bankName;
  String? employeeId;
  String? employeeName;
  String status; // 'pending', 'accepted', 'rejected'
  bool isClosed; // true = مغلق (مع الاحتفاظ بالحالة الأصلية)

  BankSelection({
    this.id,
    this.bankId,
    this.bankName,
    this.employeeId,
    this.employeeName,
    this.status = 'pending',
    this.isClosed = false,
  });
}

/// A single distribution entry representing a selected credit program and its assigned bank distributions
class DistributionEntry {
  String? selectedProgramId;
  String? selectedProgramName;
  final List<BankSelection> bankSelections = [];

  DistributionEntry({
    this.selectedProgramId,
    this.selectedProgramName,
    List<BankSelection>? selections,
  }) {
    if (selections != null) {
      bankSelections.addAll(selections);
    }
  }
}

class DistributionWidget extends ConsumerStatefulWidget {
  final String clientId;
  final double requestedAmount;
  const DistributionWidget({
    super.key,
    required this.clientId,
    required this.requestedAmount,
  });

  @override
  ConsumerState<DistributionWidget> createState() => _DistributionWidgetState();
}

class _DistributionWidgetState extends ConsumerState<DistributionWidget>
    with SingleTickerProviderStateMixin {
  final List<DistributionEntry> _entries = [];
  late AnimationController _animController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _loadDistribution();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadDistribution() async {
    if (!SupabaseConfig.isInitialized) {
      // Simulation fallback: Mock entries
      if (_entries.isEmpty) {
        setState(() {
          _entries.add(
            DistributionEntry(
              selectedProgramId: "mock-prog-1",
              selectedProgramName: "برنامج تمويل شخصي",
              selections: [
                BankSelection(
                  id: "mock-sel-1",
                  bankId: "mock-bank-1",
                  bankName: "البنك الأهلي",
                  status: "pending",
                )
              ]
            )
          );
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final authState = ref.read(authProvider);
    final bool isUserAdmin = authState.role == 'admin';

    try {
      final response = await SupabaseConfig.client
          .from('distribution_entries')
          .select('''
            id,
            program_id,
            bank_id,
            employee_id,
            status,
            is_closed,
            core_programs ( program_name ),
            banks ( bank_name ),
            bank_employees ( employee_name, phone_1, job_title )
          ''')
          .eq('client_id', widget.clientId);

      final List<dynamic> rows = response as List<dynamic>;

      // Group rows by program_id
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (var row in rows) {
        final progId = row['program_id'] as String;
        grouped.putIfAbsent(progId, () => []).add(row as Map<String, dynamic>);
      }

      final List<DistributionEntry> loadedEntries = [];
      for (var entry in grouped.entries) {
        final progId = entry.key;
        final progRows = entry.value;
        final progName = progRows.first['core_programs'] != null
            ? progRows.first['core_programs']['program_name']?.toString()
            : "برنامج غير معروف";

        final isBankEmp = authState.role == 'bank_employee';
        final userBankName = authState.bankName?.trim().toLowerCase() ?? '';
        final userEmpId = authState.user?.id ?? '';
        final userBankEmpId = authState.bankEmployeeId?.toString().trim() ?? '';
        final userFullName = authState.fullName.trim().toLowerCase();

        final selections = progRows.where((r) {
          if (!isBankEmp) return true;
          // Hide closed distributions from bank employees
          final rowIsClosed = r['is_closed'] == true || r['status'] == 'closed';
          if (rowIsClosed) return false;

          final empData = r['bank_employees'] as Map<String, dynamic>?;
          final rowEmpId = (r['employee_id']?.toString() ?? '').trim();
          final rowEmpName = (empData?['employee_name']?.toString() ?? '').trim().toLowerCase();

          final matchesEmp = (userEmpId.isNotEmpty && rowEmpId == userEmpId) ||
              (userBankEmpId.isNotEmpty && rowEmpId == userBankEmpId) ||
              (userFullName.isNotEmpty && rowEmpName.isNotEmpty && (rowEmpName.contains(userFullName) || userFullName.contains(rowEmpName)));

          return matchesEmp;
        }).map((r) {
          final bankData = r['banks'] as Map<String, dynamic>?;
          final empData = r['bank_employees'] as Map<String, dynamic>?;
          final rowIsClosed = r['is_closed'] == true || r['status'] == 'closed';
          var rowStatus = r['status'] as String? ?? 'pending';
          if (rowStatus == 'closed') rowStatus = 'pending'; // Fallback if old closed string was present

          return BankSelection(
            id: r['id'] as String,
            bankId: r['bank_id'] as String,
            bankName: bankData != null ? bankData['bank_name']?.toString() : null,
            employeeId: r['employee_id'] as String?,
            employeeName: empData != null
                ? (isUserAdmin
                    ? '${empData['employee_name']} ${empData['phone_1'] ?? ""}'.trim()
                    : ((empData['job_title'] != null && empData['job_title'].toString().trim().isNotEmpty)
                        ? '${empData['employee_name']} (${empData['job_title']})'.trim()
                        : '${empData['employee_name']}'.trim()))
                : null,
            status: rowStatus,
            isClosed: rowIsClosed,
          );
        }).toList();

        if (selections.isNotEmpty) {
          loadedEntries.add(DistributionEntry(
            selectedProgramId: progId,
            selectedProgramName: progName,
            selections: selections,
          ));
        }
      }

      if (mounted) {
        setState(() {
          _entries.clear();
          _entries.addAll(loadedEntries);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading distribution: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ في تحميل التوزيع: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteBankSelection(BankSelection sel) async {
    final authState = ref.read(authProvider);
    final staffName = authState.fullName;
    final bankName = sel.bankName ?? 'بنك غير معروف';

    if (sel.id == null) return;

    if (!SupabaseConfig.isInitialized) {
      // Simulation mode log update
      final clientState = ref.read(clientProvider);
      final client = clientState.clients.firstWhereOrNull((c) => c.id == widget.clientId);
      if (client != null) {
        final newHistory = [
          InteractionLogModel(
            id: "hi-${DateTime.now().millisecondsSinceEpoch}",
            actionType: 'حذف توزيع البنك',
            notes: 'تم إزالة توزيع البنك: $bankName من قبل: $staffName',
            createdBy: staffName,
            createdAt: DateTime.now(),
          ),
          ...client.history
        ];
        ref.read(clientProvider.notifier).state = clientState.copyWith(
          clients: clientState.clients.map((c) => c.id == widget.clientId ? c.copyWith(history: newHistory) : c).toList(),
        );
      }
      return;
    }

    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      
      await SupabaseConfig.client
          .from('distribution_entries')
          .delete()
          .eq('id', sel.id!);

      // Insert log
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': widget.clientId,
        'action_type': 'حذف توزيع البنك',
        'notes': 'تم إزالة توزيع البنك: $bankName من قبل: $staffName',
        if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
        'created_by_name': staffName,
      });
      
      // Refresh client logs
      ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: ref.read(authProvider).bankEmployeeId);
    } catch (e) {
      debugPrint("Error deleting selection: $e");
    }
  }

  Future<void> _saveOrUpdateBankSelection(String programId, BankSelection sel) async {
    if (programId.isEmpty || sel.bankId == null) return;

    final authState = ref.read(authProvider);
    final staffName = authState.fullName;
    final bankName = sel.bankName ?? 'بنك غير معروف';
    final isNew = (sel.id == null);
    String statusArabic = sel.status == 'accepted'
        ? 'مقبول'
        : sel.status == 'rejected'
            ? 'مرفوض'
            : 'قيد الانتظار';
    final closedStatusSuffix = sel.isClosed ? ' (مغلق 🔒)' : '';

    if (!SupabaseConfig.isInitialized) {
      // In simulation mode, mock ID generation and log update
      sel.id ??= "mock-id-${DateTime.now().millisecondsSinceEpoch}";
      
      final clientState = ref.read(clientProvider);
      final client = clientState.clients.firstWhereOrNull((c) => c.id == widget.clientId);
      if (client != null) {
        final actionText = isNew ? 'إضافة توزيع بنك جديد' : (sel.isClosed ? 'إغلاق توزيع البنك' : 'تحديث توزيع البنك');
        final notesText = isNew 
            ? 'تم إضافة توزيع للبنك: $bankName بحالة ($statusArabic)$closedStatusSuffix'
            : 'تم تحديث حالة توزيع البنك ($bankName) لتصبح: $statusArabic$closedStatusSuffix';

        final newHistory = [
          InteractionLogModel(
            id: "hi-${DateTime.now().millisecondsSinceEpoch}",
            actionType: actionText,
            notes: '$notesText بواسطة: $staffName',
            createdBy: staffName,
            createdAt: DateTime.now(),
          ),
          ...client.history
        ];
        ref.read(clientProvider.notifier).state = clientState.copyWith(
          clients: clientState.clients.map((c) => c.id == widget.clientId ? c.copyWith(history: newHistory) : c).toList(),
        );
      }
      return;
    }

    try {
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

      final data = {
        'client_id': widget.clientId,
        'program_id': programId,
        'bank_id': sel.bankId,
        'employee_id': sel.employeeId,
        'status': sel.status,
        'is_closed': sel.isClosed,
      };

      if (sel.id == null) {
        final res = await SupabaseConfig.client
            .from('distribution_entries')
            .upsert(data, onConflict: 'client_id,program_id,bank_id')
            .select('id')
            .single();
        sel.id = res['id'] as String;
      } else {
        await SupabaseConfig.client
            .from('distribution_entries')
            .update(data)
            .eq('id', sel.id!);
      }

      final bankName = sel.bankName ?? 'بنك غير معروف';
      final actionText = isNew ? 'إضافة توزيع بنك جديد' : (sel.isClosed ? 'إغلاق توزيع البنك' : 'تحديث توزيع البنك');
      final notesText = isNew 
          ? 'تم إضافة توزيع للبنك: $bankName بحالة ($statusArabic)$closedStatusSuffix'
          : 'تم تحديث حالة توزيع البنك ($bankName) لتصبح: $statusArabic$closedStatusSuffix';

      // Insert log
      await SupabaseConfig.client.from('interaction_history').insert({
        'client_id': widget.clientId,
        'action_type': actionText,
        'notes': '$notesText بواسطة: $staffName',
        if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
        'created_by_name': staffName,
      });

      // Refresh client logs
      ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: ref.read(authProvider).bankEmployeeId);
    } catch (e) {
      debugPrint("Error saving selection: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء الحفظ: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  void _addEntry() {
    setState(() {
      _entries.add(DistributionEntry());
    });
  }

  void _removeEntry(int index) async {
    final entry = _entries[index];
    setState(() {
      _entries.removeAt(index);
    });

    if (SupabaseConfig.isInitialized) {
      for (var sel in entry.bankSelections) {
        if (sel.id != null) {
          await _deleteBankSelection(sel);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin' || authState.role == 'manager';
    final corePrograms = ref.watch(coreProgramsProvider);

    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: const Color(0xFF7B61FF).withValues(alpha: 0.15),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF00F5D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_tree_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "التوزيع على البنوك",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: TfcColors.onSurface,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: TfcColors.primary),
              ),
            )
          else if (_entries.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.account_tree_outlined,
                      color: TfcColors.outline.withValues(alpha: 0.4),
                      size: 48),
                  const SizedBox(height: 12),
                  Text(
                    "لا توجد توزيعات حالياً",
                    style: TextStyle(
                      color: TfcColors.outline.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    Text(
                      "اضغط على \"إضافة توزيع\" لبدء توزيع العميل على البنوك",
                      style: TextStyle(
                        color: TfcColors.outline.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ],
              ),
            )
          else
            corePrograms.when(
              data: (programs) => _buildEntriesList(programs, isAdmin),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: TfcColors.primary),
                ),
              ),
              error: (e, _) => Text(
                "خطأ في تحميل البرامج: $e",
                style: const TextStyle(color: TfcColors.error),
                textDirection: TextDirection.rtl,
              ),
            ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: _addEntry,
                icon: const Icon(Icons.add_circle_outline, color: TfcColors.primary, size: 18),
                label: const Text("إضافة توزيع", style: TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
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
        ],
      ),
    );
  }

  Widget _buildEntriesList(List<Map<String, dynamic>> programs, bool isAdmin) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _entries.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Divider(
          color: TfcColors.outline.withValues(alpha: 0.1),
          height: 1,
        ),
      ),
      itemBuilder: (context, index) {
        return _DistributionEntryCard(
          key: ValueKey('entry_$index'),
          entry: _entries[index],
          index: index,
          programs: programs,
          isAdmin: isAdmin,
          clientId: widget.clientId,
          requestedAmount: widget.requestedAmount,
          onRemove: () => _removeEntry(index),
          onChanged: () => setState(() {}),
          onSaveBankSelection: (sel) =>
              _saveOrUpdateBankSelection(_entries[index].selectedProgramId ?? "", sel),
          onDeleteBankSelection: _deleteBankSelection,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Distribution Entry Card
// ─────────────────────────────────────────────────────────────────────────────
class _DistributionEntryCard extends ConsumerStatefulWidget {
  final DistributionEntry entry;
  final int index;
  final List<Map<String, dynamic>> programs;
  final bool isAdmin;
  final String clientId;
  final double requestedAmount;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Function(BankSelection) onSaveBankSelection;
  final Function(BankSelection) onDeleteBankSelection;

  const _DistributionEntryCard({
    super.key,
    required this.entry,
    required this.index,
    required this.programs,
    required this.isAdmin,
    required this.clientId,
    required this.requestedAmount,
    required this.onRemove,
    required this.onChanged,
    required this.onSaveBankSelection,
    required this.onDeleteBankSelection,
  });

  @override
  ConsumerState<_DistributionEntryCard> createState() =>
      _DistributionEntryCardState();
}

class _DistributionEntryCardState
    extends ConsumerState<_DistributionEntryCard> {
  
  List<BankSelection> get _bankSelections => widget.entry.bankSelections;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _getEntryBorderColor(),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Entry header
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7B61FF), Color(0xFF00F5D4)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.selectedProgramName ?? "اختر البرنامج",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: entry.selectedProgramName != null
                        ? TfcColors.onSurface
                        : TfcColors.outline,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
              if (widget.isAdmin)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: TfcColors.error.withValues(alpha: 0.7),
                  onPressed: widget.onRemove,
                  tooltip: "حذف التوزيع",
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Step 1: Program Selection
          if (widget.isAdmin)
            _buildProgramDropdown()
          else if (entry.selectedProgramName != null)
            _InfoRow(
              label: "البرنامج",
              value: entry.selectedProgramName!,
              icon: Icons.category_rounded,
            ),

          if (entry.selectedProgramId != null) ...[
            const SizedBox(height: 16),
            // Step 2: Show available banks for this program
            _buildBanksSection(),
          ],
        ],
      ),
    );
  }

  Color _getEntryBorderColor() {
    if (_bankSelections.isEmpty) {
      return Colors.white.withValues(alpha: 0.06);
    }
    final hasAccepted = _bankSelections.any((b) => b.status == 'accepted');
    final hasRejected = _bankSelections.any((b) => b.status == 'rejected');
    if (hasAccepted && !hasRejected) return TfcColors.success.withValues(alpha: 0.3);
    if (hasRejected && !hasAccepted) return TfcColors.error.withValues(alpha: 0.3);
    return const Color(0xFF7B61FF).withValues(alpha: 0.2);
  }

  Widget _buildProgramDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: widget.entry.selectedProgramId,
          isExpanded: true,
          hint: const Text(
            "اختر البرنامج الائتماني",
            style: TextStyle(color: TfcColors.outline, fontSize: 13),
            textDirection: TextDirection.rtl,
          ),
          dropdownColor: TfcColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: TfcColors.primary, size: 22),
          items: widget.programs.map((p) {
            return DropdownMenuItem<String>(
              value: p['id'].toString(),
              child: Text(
                p['program_name'] ?? '',
                style: const TextStyle(fontSize: 13),
                textDirection: TextDirection.rtl,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            final program = widget.programs.firstWhere(
              (p) => p['id'].toString() == val,
              orElse: () => {},
            );
            setState(() {
              widget.entry.selectedProgramId = val;
              widget.entry.selectedProgramName =
                  program['program_name'] ?? '';
              _bankSelections.clear(); // Reset bank selections
            });
            widget.onChanged();
          },
        ),
      ),
    );
  }

  Widget _buildBanksSection() {
    final programId = widget.entry.selectedProgramId!;
    final banksAsync = ref.watch(banksByProgramProvider(programId));

    return banksAsync.when(
      data: (bankPrograms) {
        if (bankPrograms.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TfcColors.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: TfcColors.warning.withValues(alpha: 0.15)),
            ),
            child: const Text(
              "لا توجد بنوك تقدم هذا البرنامج حالياً",
              style: TextStyle(color: TfcColors.warning, fontSize: 13),
              textDirection: TextDirection.rtl,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.account_balance,
                    color: TfcColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  "البنوك المتاحة (${bankPrograms.length})",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: TfcColors.onSurfaceVariant,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // List of bank selection cards
            ..._bankSelections.asMap().entries.map((mapEntry) {
              final idx = mapEntry.key;
              final bankSel = mapEntry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BankSelectionCard(
                  bankSelection: bankSel,
                  availableBanks: bankPrograms,
                  isAdmin: widget.isAdmin,
                  clientId: widget.clientId,
                  requestedAmount: widget.requestedAmount,
                  programName: widget.entry.selectedProgramName ?? '',
                  onRemove: () {
                    widget.onDeleteBankSelection(bankSel);
                    setState(() => _bankSelections.removeAt(idx));
                  },
                  onChanged: () => setState(() {}),
                  onSave: () => widget.onSaveBankSelection(bankSel),
                ),
              );
            }),

            // If no banks selected yet and admin, show hint
            if (_bankSelections.isEmpty && widget.isAdmin)
              InkWell(
                onTap: () => _addBankSelection(bankPrograms),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: TfcColors.primary.withValues(alpha: 0.2),
                        style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.add_circle_outline,
                          color: TfcColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "اضغط لإضافة بنك",
                        style:
                            TextStyle(color: TfcColors.primary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

            if (!widget.isAdmin && _bankSelections.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  "لم يتم توزيع العميل على بنوك بعد",
                  style: TextStyle(
                    color: TfcColors.outline.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),

            // Add bank button at the bottom
            if (widget.isAdmin && _bankSelections.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _addBankSelection(bankPrograms),
                  icon: const Icon(Icons.add_circle_outline, color: TfcColors.primary, size: 18),
                  label: const Text("إضافة بنك", style: TextStyle(color: TfcColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
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
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child:
                CircularProgressIndicator(color: TfcColors.primary, strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text(
        "خطأ: $e",
        style: const TextStyle(color: TfcColors.error, fontSize: 12),
      ),
    );
  }

  void _addBankSelection(List<Map<String, dynamic>> availableBanks) {
    setState(() {
      _bankSelections.add(BankSelection());
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bank Selection Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _BankSelectionCard extends ConsumerWidget {
  final BankSelection bankSelection;
  final List<Map<String, dynamic>> availableBanks;
  final bool isAdmin;
  final String clientId;
  final double requestedAmount;
  final String programName;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  const _BankSelectionCard({
    required this.bankSelection,
    required this.availableBanks,
    required this.isAdmin,
    required this.clientId,
    required this.requestedAmount,
    required this.programName,
    required this.onRemove,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isStrictAdmin = authState.role == 'admin';

    final statusColor = _getStatusColor(bankSelection.status);
    final statusLabel = _getStatusLabel(bankSelection.status);
    final statusIcon = _getStatusIcon(bankSelection.status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bank selection row
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(Icons.account_balance,
                  color: statusColor.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: isAdmin
                    ? _buildBankDropdown(context)
                    : Text(
                        bankSelection.bankName ?? "—",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  color: TfcColors.error.withValues(alpha: 0.6),
                  tooltip: "حذف",
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),

          // Employee selection (if bank is selected) - Only shown to Admin/Manager
          if (isAdmin && bankSelection.bankId != null) ...[
            const SizedBox(height: 12),
            _buildEmployeeSection(ref),
          ],

          // Accept / Reject / Close / Transfer to Operations buttons (admin only)
          if (isAdmin && bankSelection.bankId != null) ...[
            const SizedBox(height: 12),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _StatusButton(
                    label: "قبول",
                    icon: Icons.check_circle_outline,
                    isActive: bankSelection.status == 'accepted',
                    activeColor: TfcColors.success,
                    onTap: () {
                      bankSelection.status =
                          bankSelection.status == 'accepted'
                              ? 'pending'
                              : 'accepted';
                      onChanged();
                      onSave();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "رفض",
                    icon: Icons.cancel_outlined,
                    isActive: bankSelection.status == 'rejected',
                    activeColor: TfcColors.error,
                    onTap: () {
                      bankSelection.status =
                          bankSelection.status == 'rejected'
                              ? 'pending'
                              : 'rejected';
                      onChanged();
                      onSave();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatusButton(
                    label: "مغلق",
                    icon: bankSelection.isClosed ? Icons.lock : Icons.lock_outline,
                    isActive: bankSelection.isClosed,
                    activeColor: const Color(0xFFFFD700), // Elegant Gold (ذهبي أنيق)
                    onTap: () {
                      bankSelection.isClosed = !bankSelection.isClosed;
                      onChanged();
                      onSave();
                    },
                  ),
                ),
                if (isStrictAdmin) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusButton(
                      label: "عمليات",
                      icon: Icons.settings_suggest_outlined,
                      isActive: bankSelection.status == 'operations',
                      activeColor: Colors.blueAccent,
                      onTap: () async {
                        try {
                          final authState = ref.read(authProvider);
                          final staffName = authState.fullName;
                          final bankName = bankSelection.bankName ?? 'بنك غير معروف';

                          // Add to operations table without changing distribution status
                          await OperationsWidget.addOperation(
                            clientId: clientId,
                            bankName: bankSelection.bankName ?? 'بنك غير معروف',
                            programName: programName,
                            employeeName: bankSelection.employeeName ?? 'لم يحدد',
                            requestedAmount: requestedAmount,
                            staffName: authState.fullName,
                          );

                          if (!SupabaseConfig.isInitialized) {
                            // Simulation fallback: manually insert interaction log
                            final clientState = ref.read(clientProvider);
                            final client = clientState.clients.firstWhereOrNull((c) => c.id == clientId);
                            if (client != null) {
                              final newHistory = [
                                InteractionLogModel(
                                  id: "hi-${DateTime.now().millisecondsSinceEpoch}",
                                  actionType: 'تحويل للعمليات',
                                  notes: 'تم تحويل المعاملة للعمليات (البنك: $bankName، البرنامج: $programName) بواسطة: $staffName',
                                  createdBy: staffName,
                                  createdAt: DateTime.now(),
                                ),
                                ...client.history
                              ];
                              ref.read(clientProvider.notifier).state = clientState.copyWith(
                                clients: clientState.clients.map((c) => c.id == clientId ? c.copyWith(history: newHistory) : c).toList(),
                              );
                            }
                          }

                          // Trigger operations list refresh in the UI immediately
                          ref.read(operationsRefreshTriggerProvider.notifier).state++;

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("تم تحويل التوزيع للعمليات بنجاح ✅", textAlign: TextAlign.right),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint("Error transferring to operations: $e");
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("خطأ أثناء التحويل للعمليات: $e", textAlign: TextAlign.right),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBankDropdown(BuildContext context) {
    final uniqueBanks = <String, String>{};
    for (var bp in availableBanks) {
      final banks = bp['banks'];
      if (banks != null && banks is Map) {
        final id = banks['id']?.toString();
        final name = banks['bank_name']?.toString();
        if (id != null && name != null) {
          uniqueBanks[id] = name;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: bankSelection.bankId,
          isExpanded: true,
          hint: const Text(
            "اختر البنك",
            style: TextStyle(color: TfcColors.outline, fontSize: 12),
            textDirection: TextDirection.rtl,
          ),
          dropdownColor: TfcColors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: TfcColors.primary, size: 18),
          items: uniqueBanks.entries.map((e) {
            return DropdownMenuItem<String>(
              value: e.key,
              child: Text(
                e.value,
                style: const TextStyle(fontSize: 13),
                textDirection: TextDirection.rtl,
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val == null) return;
            bankSelection.bankId = val;
            bankSelection.bankName = uniqueBanks[val];
            bankSelection.employeeId = null;
            bankSelection.employeeName = null;
            onChanged();
            onSave();
          },
        ),
      ),
    );
  }

  Widget _buildEmployeeSection(WidgetRef ref) {
    final employeesAsync =
        ref.watch(bankEmployeesProvider(bankSelection.bankId!));

    return employeesAsync.when(
      data: (employees) {
        if (!isAdmin) {
          return _InfoRow(
            label: "الموظف المسؤول",
            value: bankSelection.employeeName ?? "لم يتم تحديد موظف",
            icon: Icons.person_outline,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: bankSelection.employeeId,
              isExpanded: true,
              hint: const Text(
                "اختر الموظف",
                style: TextStyle(color: TfcColors.outline, fontSize: 12),
                textDirection: TextDirection.rtl,
              ),
              dropdownColor: TfcColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: TfcColors.primary, size: 18),
              items: employees.map((e) {
                final String phoneSuffix = (ref.read(authProvider).role == 'admin' && e['phone_1'] != null)
                    ? ' - ${e['phone_1']}'
                    : '';
                return DropdownMenuItem<String>(
                  value: e['id'].toString(),
                  child: Text(
                    '${e['employee_name']}$phoneSuffix',
                    style: const TextStyle(fontSize: 12),
                    textDirection: TextDirection.rtl,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final emp = employees.firstWhere(
                  (e) => e['id'].toString() == val,
                  orElse: () => {},
                );
                bankSelection.employeeId = val;
                bankSelection.employeeName =
                    emp['employee_name']?.toString() ?? '';
                onChanged();
                onSave();
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: TfcColors.primary, strokeWidth: 2),
          ),
        ),
      ),
      error: (e, _) => Text(
        "خطأ في تحميل الموظفين",
        style: TextStyle(
            color: TfcColors.error.withValues(alpha: 0.7), fontSize: 11),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return TfcColors.success;
      case 'rejected':
        return TfcColors.error;
      case 'operations':
        return Colors.blueAccent;
      case 'pending':
      default:
        return const Color(0xFF64B5F6); // بيبي بلو (Baby Blue)
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted':
        return "مقبول";
      case 'rejected':
        return "مرفوض";
      case 'operations':
        return "محول للعمليات";
      default:
        return "قيد المراجعة";
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'operations':
        return Icons.settings_suggest;
      default:
        return Icons.schedule;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Icon(icon, size: 15, color: TfcColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          "$label: ",
          style: const TextStyle(
            color: TfcColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: TfcColors.onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF7B61FF).withValues(alpha: 0.15),
                TfcColors.primary.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: const Color(0xFF7B61FF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF7B61FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : TfcColors.outline,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? activeColor : TfcColors.outline,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
