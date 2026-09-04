import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/employees_provider.dart';
import '../../providers/client_provider.dart';
import '../../models/profile.dart';
import '../client/operations_widget.dart';

class EmployeeTargetModel {
  final String id;
  final String employeeId;
  final double targetAmount;
  final String targetMonth; // YYYY-MM

  EmployeeTargetModel({
    required this.id,
    required this.employeeId,
    required this.targetAmount,
    required this.targetMonth,
  });

  factory EmployeeTargetModel.fromJson(Map<String, dynamic> json) {
    return EmployeeTargetModel(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      targetAmount: (json['target_amount'] as num?)?.toDouble() ?? 0.0,
      targetMonth: json['target_month'] ?? '',
    );
  }
}

class TargetRollupNode {
  final Profile employee;
  final double personalTarget;
  final double personalAchieved;
  final List<TargetRollupNode> children = [];

  TargetRollupNode({
    required this.employee,
    required this.personalTarget,
    required this.personalAchieved,
  });

  double get totalTarget {
    double sum = personalTarget;
    for (var child in children) {
      sum += child.totalTarget;
    }
    return sum;
  }

  double get totalAchieved {
    double sum = personalAchieved;
    for (var child in children) {
      sum += child.totalAchieved;
    }
    return sum;
  }
}

class EmployeeTargetsPanel extends ConsumerStatefulWidget {
  const EmployeeTargetsPanel({super.key});

  @override
  ConsumerState<EmployeeTargetsPanel> createState() => _EmployeeTargetsPanelState();
}

class _EmployeeTargetsPanelState extends ConsumerState<EmployeeTargetsPanel> {
  bool _isLoading = true;
  String _selectedMonth = ""; // Format YYYY-MM
  List<EmployeeTargetModel> _targets = [];
  List<OperationEntry> _allOperations = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (!SupabaseConfig.isInitialized) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch targets for the selected month
      final targetsResponse = await SupabaseConfig.client
          .from('employee_targets')
          .select('*')
          .eq('target_month', _selectedMonth);

      // Fetch approved operations
      final opsResponse = await SupabaseConfig.client
          .from('operation_entries')
          .select('*')
          .eq('status', 'approved');

      final List<dynamic> targetsRows = targetsResponse as List<dynamic>;
      final List<dynamic> opsRows = opsResponse as List<dynamic>;

      if (mounted) {
        setState(() {
          _targets = targetsRows.map((r) => EmployeeTargetModel.fromJson(r)).toList();
          _allOperations = opsRows.map((r) => OperationEntry.fromJson(r)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading target data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, int> _getMonthDaysDetails() {
    final parts = _selectedMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final now = DateTime.now();
    int remainingDays = 1;

    if (now.year == year && now.month == month) {
      remainingDays = daysInMonth - now.day + 1;
    } else if (year > now.year || (year == now.year && month > now.month)) {
      remainingDays = daysInMonth;
    } else {
      remainingDays = 1;
    }
    if (remainingDays < 1) remainingDays = 1;

    return {
      'total': daysInMonth,
      'remaining': remainingDays,
    };
  }

  List<TargetRollupNode> _buildRollupHierarchy(List<Profile> activeEmployees) {
    final Map<String, double> targetMap = {
      for (var t in _targets) t.employeeId: t.targetAmount
    };

    final Map<String, double> achievedMap = {};
    final parts = _selectedMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;

    for (final emp in activeEmployees) {
      double achieved = 0.0;
      final cleanEmpName = emp.fullName.toLowerCase().trim();

      for (final op in _allOperations) {
        if (op.approvalDate != null &&
            op.approvalDate!.year == year &&
            op.approvalDate!.month == month) {
          final client = ref.read(clientProvider).clients.firstWhereOrNull((c) => c.id == op.clientId);
          final repName = (client?.representativeName ?? '').toLowerCase().trim();

          if (repName == cleanEmpName && op.approvedAmount != null) {
            achieved += op.approvedAmount!;
          }
        }
      }
      achievedMap[emp.id] = achieved;
    }

    final Map<String, TargetRollupNode> nodes = {
      for (var emp in activeEmployees)
        emp.id: TargetRollupNode(
          employee: emp,
          personalTarget: targetMap[emp.id] ?? 0.0,
          personalAchieved: achievedMap[emp.id] ?? 0.0,
        )
    };

    final List<TargetRollupNode> roots = [];

    for (final node in nodes.values) {
      final managerId = node.employee.managerId;
      if (managerId != null && nodes.containsKey(managerId)) {
        nodes[managerId]!.children.add(node);
      } else {
        roots.add(node);
      }
    }

    return roots;
  }

  void _showAddTargetDialog({bool isGroup = false}) {
    final empState = ref.read(employeesProvider);
    final activeEmployees = empState.employees
        .where((e) => e.employeeStatus == 'active' && e.role != 'bank_employee')
        .toList();

    final targetController = TextEditingController();
    List<String> selectedEmployeeIds = [];
    String? selectedSingleId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: TfcColors.surfaceDim,
            title: Text(
              isGroup ? "إضافة هدف لمجموعة موظفين" : "إضافة هدف لموظف منفرد",
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.92,
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("الشهر المستهدف: $_selectedMonth", style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.outline)),
                    const SizedBox(height: 16),
                    if (isGroup) ...[
                      const Text("اختر الموظفين:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Scrollbar(
                          child: ListView.builder(
                            itemCount: activeEmployees.length,
                            itemBuilder: (ctx, index) {
                              final emp = activeEmployees[index];
                              final isSelected = selectedEmployeeIds.contains(emp.id);
                              return CheckboxListTile(
                                title: Text(emp.fullName, textAlign: TextAlign.right),
                                subtitle: Text(
                                  emp.role == 'manager' ? 'مدير' : 'موظف',
                                  style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                                ),
                                value: isSelected,
                                activeColor: TfcColors.primary,
                                dense: true,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedEmployeeIds.add(emp.id);
                                    } else {
                                      selectedEmployeeIds.remove(emp.id);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      if (selectedEmployeeIds.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "تم اختيار ${selectedEmployeeIds.length} موظف",
                            style: const TextStyle(color: TfcColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ] else ...[
                      const Text("اختر الموظف:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSingleId,
                            hint: const Text("اختر موظفاً"),
                            dropdownColor: TfcColors.surfaceDim,
                            isExpanded: true,
                            items: activeEmployees.map((emp) {
                              return DropdownMenuItem(
                                value: emp.id,
                                child: Text(emp.fullName, textAlign: TextAlign.right),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedSingleId = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      keyboardType: TextInputType.number,
                      autofocus: false,
                      decoration: const InputDecoration(
                        labelText: "قيمة الهدف البيعي (ج.م)",
                        hintText: "مثال: 500000",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("إلغاء"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(targetController.text) ?? 0.0;
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                    return;
                  }

                  final idsToSave = isGroup ? selectedEmployeeIds : (selectedSingleId != null ? [selectedSingleId!] : <String>[]);
                  if (idsToSave.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("الرجاء تحديد موظف واحد على الأقل", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  
                  // Optimistic local state update
                  setState(() {
                    for (final empId in idsToSave) {
                      _targets.removeWhere((t) => t.employeeId == empId && t.targetMonth == _selectedMonth);
                      _targets.add(EmployeeTargetModel(
                        id: 'temp-$empId',
                        employeeId: empId,
                        targetAmount: amount,
                        targetMonth: _selectedMonth,
                      ));
                    }
                  });

                  try {
                    final bulkData = idsToSave.map((empId) => {
                      'employee_id': empId,
                      'target_amount': amount,
                      'target_month': _selectedMonth,
                    }).toList();

                    await SupabaseConfig.client
                        .from('employee_targets')
                        .upsert(bulkData, onConflict: 'employee_id,target_month');

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ تم حفظ الأهداف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("خطأ أثناء الحفظ: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                    );
                  }
                  _loadData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
                child: const Text("حفظ الهدف", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTargetDialog(TargetRollupNode node) {
    final existingTarget = _targets.firstWhereOrNull((t) => t.employeeId == node.employee.id);
    if (existingTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا يوجد هدف محدد لهذا الموظف لتعديله", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
      );
      return;
    }

    final controller = TextEditingController(text: existingTarget.targetAmount.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: Text(
          "تعديل هدف ${node.employee.fullName}",
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary, fontSize: 16),
        ),
        content: SizedBox(
          width: 350,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("الشهر: $_selectedMonth", style: const TextStyle(color: TfcColors.outline)),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "قيمة الهدف الجديدة (ج.م)",
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newAmount = double.tryParse(controller.text) ?? 0.0;
              if (newAmount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("الرجاء إدخال مبلغ صحيح", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                );
                return;
              }
              Navigator.pop(ctx);
              // Optimistic update - instantly reflect on screen
              setState(() {
                final idx = _targets.indexWhere((t) => t.id == existingTarget.id);
                if (idx != -1) {
                  _targets[idx] = EmployeeTargetModel(
                    id: existingTarget.id,
                    employeeId: existingTarget.employeeId,
                    targetAmount: newAmount,
                    targetMonth: existingTarget.targetMonth,
                  );
                }
              });
              // Background server sync
              SupabaseConfig.client
                  .from('employee_targets')
                  .update({'target_amount': newAmount})
                  .eq('id', existingTarget.id)
                  .then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ تم تعديل الهدف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success, duration: Duration(seconds: 1)),
                  );
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                  );
                  _loadData();
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.primary),
            child: const Text("حفظ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _deleteTarget(TargetRollupNode node) {
    final existingTarget = _targets.firstWhereOrNull((t) => t.employeeId == node.employee.id);
    if (existingTarget == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("لا يوجد هدف محدد لهذا الموظف لحذفه", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TfcColors.surfaceDim,
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: TfcColors.error)),
        content: Text(
          "هل أنت متأكد من حذف هدف ${node.employee.fullName} لشهر $_selectedMonth؟",
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Optimistic delete - remove from local list instantly
              setState(() {
                _targets.removeWhere((t) => t.id == existingTarget.id);
              });
              // Background server sync
              SupabaseConfig.client
                  .from('employee_targets')
                  .delete()
                  .eq('id', existingTarget.id)
                  .then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("✅ تم حذف الهدف بنجاح", textAlign: TextAlign.right), backgroundColor: TfcColors.success, duration: Duration(seconds: 1)),
                  );
                }
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("خطأ: $e", textAlign: TextAlign.right), backgroundColor: TfcColors.error),
                  );
                  _loadData();
                }
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: TfcColors.error),
            child: const Text("حذف", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  Widget _buildNodeTreeItem(TargetRollupNode node, Map<String, int> daysDetails, {int depth = 0, bool isAdmin = false}) {
    final totalTarget = node.totalTarget;
    final totalAchieved = node.totalAchieved;
    final remaining = totalTarget - totalAchieved;
    final remainingAmount = remaining > 0 ? remaining : 0.0;

    final double percent = totalTarget > 0 ? (totalAchieved / totalTarget) * 100 : 0.0;
    final dailyAvg = remainingAmount / daysDetails['remaining']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(right: depth * 20.0),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            node.employee.fullName.substring(0, 1),
                            style: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.employee.fullName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              node.employee.role == 'manager' ? "مدير" : "موظف",
                              style: const TextStyle(color: TfcColors.outline, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      "${percent.toStringAsFixed(1)}%",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: percent >= 100
                              ? TfcColors.success
                              : percent >= 50
                                  ? Colors.orangeAccent
                                  : TfcColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 12,
                  textDirection: TextDirection.rtl,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("الهدف الإجمالي (شخصي + تبعي)", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                        Text("${_fmt(totalTarget)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if (node.personalTarget != totalTarget)
                          Text("(الشخصي: ${_fmt(node.personalTarget)} ج.م)", style: const TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("المحقق الفعلي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                        Text(
                          "${_fmt(totalAchieved)} ج.م",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TfcColors.success),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("المتبقي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                        Text(
                          "${_fmt(remainingAmount)} ج.م",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: remainingAmount > 0 ? TfcColors.error : TfcColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalTarget > 0 ? (totalAchieved / totalTarget).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: Colors.white10,
                    color: percent >= 100
                        ? TfcColors.success
                        : percent >= 50
                            ? Colors.orangeAccent
                            : TfcColors.error,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 4,
                  spacing: 8,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text("المتوسط اليومي المطلوب للأيام المتبقية:", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                    Text(
                      remainingAmount > 0
                          ? "${_fmt(dailyAvg)} ج.م / يومياً (${daysDetails['remaining']} يوم)"
                          : "تم تحقيق الهدف الكامل! 🎉",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: remainingAmount > 0 ? Colors.orangeAccent : TfcColors.success),
                    ),
                  ],
                ),
                if (isAdmin && node.personalTarget > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditTargetDialog(node),
                        icon: const Icon(Icons.edit, size: 14, color: TfcColors.primary),
                        label: const Text("تعديل", style: TextStyle(color: TfcColors.primary, fontSize: 12)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => _deleteTarget(node),
                        icon: const Icon(Icons.delete_outline, size: 14, color: TfcColors.error),
                        label: const Text("حذف", style: TextStyle(color: TfcColors.error, fontSize: 12)),
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        ...node.children.map((child) => _buildNodeTreeItem(child, daysDetails, depth: depth + 1, isAdmin: isAdmin)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final empState = ref.watch(employeesProvider);
    final activeEmployees = empState.employees
        .where((e) => e.employeeStatus == 'active' && e.role != 'bank_employee')
        .toList();
    final authState = ref.watch(authProvider);
    final isAdmin = authState.role == 'admin';

    if (_isLoading || empState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: TfcColors.primary));
    }

    final rollupRoots = _buildRollupHierarchy(activeEmployees);
    final daysDetails = _getMonthDaysDetails();

    double totalTargetSum = 0.0;
    double totalAchievedSum = 0.0;

    for (final node in rollupRoots) {
      totalTargetSum += node.totalTarget;
      totalAchievedSum += node.totalAchieved;
    }

    final totalRemaining = totalTargetSum - totalAchievedSum;
    final totalRemainingAmount = totalRemaining > 0 ? totalRemaining : 0.0;
    final double overallPercent = totalTargetSum > 0 ? (totalAchievedSum / totalTargetSum) * 100 : 0.0;
    final overallDailyAvg = totalRemainingAmount / daysDetails['remaining']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text("الشهر المستهدف: ", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMonth,
                      dropdownColor: TfcColors.surfaceDim,
                      items: List.generate(12, (index) {
                        final date = DateTime(DateTime.now().year, index + 1);
                        final val = "${date.year}-${date.month.toString().padLeft(2, '0')}";
                        return DropdownMenuItem(
                          value: val,
                          child: Text(val),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedMonth = val;
                          });
                          _loadData();
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (isAdmin)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddTargetDialog(isGroup: true),
                    icon: const Icon(Icons.group_add, size: 16),
                    label: const Text("هدف جماعي"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTargetDialog(isGroup: false),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text("هدف فردي"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TfcColors.primary,
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderColor: TfcColors.primary.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "أداء المبيعات الإجمالي للشركة",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.primary),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                spacing: 16,
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("إجمالي الأهداف المطلوبة", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                      Text("${_fmt(totalTargetSum)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("المحقق الفعلي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                      Text("${_fmt(totalAchievedSum)} ج.م", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: TfcColors.success)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("المتبقي الكلي", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                      Text(
                        "${_fmt(totalRemainingAmount)} ج.م",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: totalRemainingAmount > 0 ? TfcColors.error : TfcColors.success),
                      ),
                    ],
                  ),
                  Text(
                    "${overallPercent.toStringAsFixed(1)}%",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: overallPercent >= 100
                            ? TfcColors.success
                            : overallPercent >= 50
                                ? Colors.orangeAccent
                                : TfcColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalTargetSum > 0 ? (totalAchievedSum / totalTargetSum).clamp(0.0, 1.0) : 0.0,
                  backgroundColor: Colors.white10,
                  color: overallPercent >= 100
                      ? TfcColors.success
                      : overallPercent >= 50
                          ? Colors.orangeAccent
                          : TfcColors.error,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("المتوسط اليومي الكلي المطلوب للشركة للأيام المتبقية:", style: TextStyle(color: TfcColors.outline, fontSize: 11)),
                  Text(
                    totalRemainingAmount > 0
                        ? "${_fmt(overallDailyAvg)} ج.م / يومياً (لمدة ${daysDetails['remaining']} يوم)"
                        : "تم تحقيق الهدف الإجمالي بالكامل! 🎉",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: totalRemainingAmount > 0 ? Colors.orangeAccent : TfcColors.success),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("هيكل أهداف الموظفين والتسلسل الإداري", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        if (rollupRoots.isEmpty)
          const Center(child: Text("لا توجد أهداف مسجلة لهذا الشهر", style: TextStyle(color: TfcColors.outline)))
        else
          ...rollupRoots.map((root) => _buildNodeTreeItem(root, daysDetails, isAdmin: isAdmin)),
      ],
    );
  }
}
