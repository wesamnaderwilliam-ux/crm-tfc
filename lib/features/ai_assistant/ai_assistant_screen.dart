import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:collection/collection.dart';
import '../../core/theme.dart';
import '../../core/supabase_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/banks_provider.dart';
import '../../providers/ai_provider.dart';
import '../../models/client_model.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  final String? initialClientId;
  const AiAssistantScreen({super.key, this.initialClientId});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  String? _selectedClientId;
  bool _isAnalyzing = false;
  String _analysisStep = "";
  AiAnalysisResult? _analysisResult;
  List<Map<String, dynamic>> _matchingProgramsList = [];
  bool _isDistributing = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialClientId != null && widget.initialClientId!.isNotEmpty) {
      _selectedClientId = widget.initialClientId;
      // Trigger analysis immediately after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runAiAnalysis();
      });
    }
  }

  Future<void> _runAiAnalysis() async {
    if (_selectedClientId == null) return;
    final clientState = ref.read(clientProvider);
    final client = clientState.clients.firstWhereOrNull((c) => c.id == _selectedClientId);
    if (client == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _matchingProgramsList = [];
      _analysisStep = "جاري قراءة الملف الائتماني والمالي للعميل...";
    });

    // Simulate step-by-step processing for premium UI feel
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _analysisStep = "جاري تحميل وتصنيف برامج التمويل المتاحة بالبنوك...";
    });

    // Load available banks/programs - fetch ALL banks and flatten their programs
    List<Map<String, dynamic>> allPrograms = [];
    try {
      if (SupabaseConfig.isInitialized) {
        final repo = ref.read(banksRepositoryProvider);
        final banks = await repo.getAllBanks();
        for (var b in banks) {
          final progs = b['bank_programs_details'] as List?;
          if (progs != null) {
            for (var p in progs) {
              allPrograms.add({
                'id': p['id']?.toString() ?? '',
                'bank_id': b['id']?.toString() ?? '',
                'program_id': p['program_id']?.toString() ?? '',
                'description': p['description'] ?? '',
                'interest_rate': p['interest_rate'] ?? 0.0,
                'max_loan_amount': p['max_loan_amount'] ?? 0.0,
                'banks': {'id': b['id']?.toString() ?? '', 'bank_name': b['bank_name'] ?? ''},
                'core_programs': p['core_programs'] ?? {'program_name': 'برنامج عام'},
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error loading bank programs context: $e");
    }

    await Future.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    setState(() {
      _analysisStep = "جاري مطابقة المعايير وإجراء حسابات العبء الائتماني (DTI)...";
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _analysisStep = "جاري صياغة التقرير الاستشاري الائتماني بالذكاء الاصطناعي...";
    });

    try {
      final analyze = ref.read(aiAnalysisProvider);
      final result = await analyze(client: client, availablePrograms: allPrograms);
      
      // Resolve details for matching programs to render interactively
      final List<Map<String, dynamic>> matchedDetails = [];
      for (var id in result.recommendedProgramIds) {
        final prog = allPrograms.firstWhereOrNull(
          (p) => p['id'].toString().trim() == id.toString().trim(),
        );
        if (prog != null) {
          matchedDetails.add(prog);
        }
      }

      // If AI/simulation returned IDs but none matched, show all programs as fallback
      if (matchedDetails.isEmpty && allPrograms.isNotEmpty) {
        // Take up to 3 programs as recommendations
        matchedDetails.addAll(allPrograms.take(3));
      }

      if (mounted) {
        setState(() {
          _analysisResult = result;
          _matchingProgramsList = matchedDetails;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء تحليل الملف: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    }
  }

  Future<void> _distributeClientToProgram(Map<String, dynamic> program) async {
    if (_selectedClientId == null) return;
    final clientState = ref.read(clientProvider);
    final client = clientState.clients.firstWhereOrNull((c) => c.id == _selectedClientId);
    if (client == null) return;

    final bankId = program['bank_id'] as String?;
    final programId = program['program_id'] as String?;
    final bank = program['banks'] as Map?;
    final bankName = bank?['bank_name']?.toString() ?? 'بنك غير معروف';
    final core = program['core_programs'] as Map?;
    final programName = core?['program_name']?.toString() ?? 'برنامج تمويلي';

    if (bankId == null || programId == null) return;

    setState(() {
      _isDistributing = true;
    });

    final staffName = ref.read(authProvider).fullName;

    try {
      if (!SupabaseConfig.isInitialized) {
        // Mock distribution local state update
        await Future.delayed(const Duration(milliseconds: 600));
        
        final actionText = 'إضافة توزيع بنك جديد (ترشيح ذكي)';
        final notesText = 'تم توزيع العميل تلقائياً للبنك: $bankName برنامج ($programName) بناءً على التوصية الذكية لمستشار الائتمان.';

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
          clients: clientState.clients.map((c) => c.id == _selectedClientId ? c.copyWith(history: newHistory) : c).toList(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ تم توزيع العميل بنجاح للبرنامج: $programName بـ $bankName", textAlign: TextAlign.right),
              backgroundColor: TfcColors.success,
            ),
          );
        }
      } else {
        final currentUserId = SupabaseConfig.client.auth.currentUser?.id;

        // Fetch first employee associated with this bank to assign as contact person
        final empRes = await SupabaseConfig.client
            .from('bank_employees')
            .select('id')
            .eq('bank_id', bankId)
            .limit(1)
            .maybeSingle();

        final String? contactEmployeeId = empRes != null ? empRes['id'] as String? : null;

        final data = {
          'client_id': _selectedClientId,
          'program_id': programId,
          'bank_id': bankId,
          'employee_id': contactEmployeeId,
          'status': 'pending',
        };

        await SupabaseConfig.client
            .from('distribution_entries')
            .upsert(data, onConflict: 'client_id,program_id,bank_id');

        // Log interaction
        await SupabaseConfig.client.from('interaction_history').insert({
          'client_id': _selectedClientId,
          'action_type': 'إضافة توزيع بنك جديد (ترشيح ذكي)',
          'notes': 'تم توزيع العميل تلقائياً للبنك: $bankName برنامج ($programName) بناءً على التوصية الذكية لمستشار الائتمان بواسطة: $staffName',
          if (currentUserId != null && currentUserId.isNotEmpty) 'created_by': currentUserId,
          'created_by_name': staffName,
        });

        // Sync client list
        ref.read(clientProvider.notifier).fetchClients();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("✅ تم إدراج العميل في جدول التوزيعات للبرنامج: $programName بـ $bankName", textAlign: TextAlign.right),
              backgroundColor: TfcColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("خطأ أثناء التوزيع: $e", textAlign: TextAlign.right),
            backgroundColor: TfcColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDistributing = false;
        });
      }
    }
  }

  String _fmt(double val) {
    if (val == val.roundToDouble()) return val.toInt().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return val.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientProvider).clients;
    final selectedClient = clients.firstWhereOrNull((c) => c.id == _selectedClientId);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "المساعد الائتماني والترشيح الذكي (AI)",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TfcColors.primary),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "تحليل ذكي للملف الائتماني ومطابقة معايير البنوك وصياغة تقارير التوزيع آلياً",
                    style: TextStyle(color: TfcColors.outline),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Selector Row
              Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClientId,
                          hint: const Text("اختر العميل للبدء في التحليل الائتماني...", style: TextStyle(color: TfcColors.outline)),
                          dropdownColor: TfcColors.surfaceDim,
                          items: clients.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(
                                "${c.fullName} - ${c.governorate} (مطلوب: ${_fmt(c.requestedAmount)} ج.م)",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            );
                          }).toList(),
                          onChanged: _isAnalyzing
                              ? null
                              : (val) {
                                  setState(() {
                                    _selectedClientId = val;
                                    _analysisResult = null;
                                    _matchingProgramsList = [];
                                  });
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: (_selectedClientId == null || _isAnalyzing) ? null : _runAiAnalysis,
                    icon: const Icon(Icons.psychology, size: 20),
                    label: const Text("بدء التحليل الذكي"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TfcColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main body area
              Expanded(
                child: _isAnalyzing
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 60,
                              height: 60,
                              child: CircularProgressIndicator(
                                color: TfcColors.primary,
                                strokeWidth: 5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _analysisStep,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: TfcColors.primary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "تستغرق هذه العملية ثوانٍ معدودة لمعالجة البيانات...",
                              style: TextStyle(color: TfcColors.outline, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : selectedClient == null
                        ? const Center(
                            child: Text(
                              "يرجى اختيار أحد العملاء من القائمة بالأعلى لبدء التحليل والمطابقة التلقائية مع معايير البنوك.",
                              style: TextStyle(color: TfcColors.outline),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Right column: Client profile details
                              Expanded(
                                flex: 2,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildClientProfileCard(selectedClient),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),

                              // Left column: Report & recommendation
                              Expanded(
                                flex: 3,
                                child: _analysisResult == null
                                    ? GlassCard(
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.auto_awesome, color: TfcColors.primary.withValues(alpha: 0.3), size: 64),
                                              const SizedBox(height: 16),
                                              const Text("لم يتم إجراء تحليل ائتماني بعد للعميل المختار.", style: TextStyle(color: TfcColors.outline)),
                                              const SizedBox(height: 8),
                                              const Text("اضغط على زر 'بدء التحليل الذكي' بالأعلى لإنشاء التقرير.", style: TextStyle(color: Colors.white30, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // Report scroll view
                                          Expanded(
                                            child: GlassCard(
                                              padding: const EdgeInsets.all(20),
                                              child: Scrollbar(
                                                child: SingleChildScrollView(
                                                  child: MarkdownBody(
                                                    data: _analysisResult!.reportMarkdown,
                                                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                                      p: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 13),
                                                      h1: const TextStyle(color: TfcColors.primary, fontWeight: FontWeight.bold, fontSize: 18, height: 2),
                                                      h2: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15, height: 1.8),
                                                      listBullet: const TextStyle(color: TfcColors.primary),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Quick action program cards
                                          if (_matchingProgramsList.isNotEmpty) ...[
                                            const Text(
                                              "الترشيحات الذكية للبرامج التمويلية:",
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: TfcColors.primary),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              height: 135,
                                              child: ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: _matchingProgramsList.length,
                                                itemBuilder: (c, idx) {
                                                  final prog = _matchingProgramsList[idx];
                                                  final core = prog['core_programs'] as Map?;
                                                  final bank = prog['banks'] as Map?;
                                                  
                                                  final progName = core?['program_name']?.toString() ?? 'برنامج ائتماني';
                                                  final bankName = bank?['bank_name']?.toString() ?? 'بنك عام';
                                                  final rate = prog['interest_rate'] ?? 20.0;
                                                  final maxLoan = prog['max_loan_amount'] ?? 1000000.0;

                                                  return Container(
                                                    width: 240,
                                                    margin: const EdgeInsets.only(left: 12),
                                                    child: GlassCard(
                                                      padding: const EdgeInsets.all(12),
                                                      borderColor: TfcColors.primary.withValues(alpha: 0.15),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(progName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, overflow: TextOverflow.ellipsis)),
                                                              Text(bankName, style: const TextStyle(color: TfcColors.outline, fontSize: 10)),
                                                            ],
                                                          ),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                            children: [
                                                              Text("الفائدة: $rate%", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                                              Text("الأقصى: ${_fmt(maxLoan)}", style: const TextStyle(color: Colors.white60, fontSize: 10)),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 4),
                                                          SizedBox(
                                                            width: double.infinity,
                                                            child: ElevatedButton(
                                                              onPressed: _isDistributing ? null : () => _distributeClientToProgram(prog),
                                                              style: ElevatedButton.styleFrom(
                                                                backgroundColor: TfcColors.primary.withValues(alpha: 0.15),
                                                                foregroundColor: TfcColors.primary,
                                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                                side: const BorderSide(color: TfcColors.primary, width: 0.5),
                                                              ),
                                                              child: const Text("توزيع فوري للبرنامج", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientProfileCard(ClientModel client) {
    double totalSalary = 0.0;
    if (client.salaryTransferMethod == 'bank_transfer') {
      for (var b in client.salaryBankDetails) {
        totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
      }
    } else {
      totalSalary = client.cashSalaryAmount ?? 0.0;
    }

    final dti = _calculateDti(client);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: TfcColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(client.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          _buildProfileDetail("المحافظة والسكن", client.governorate),
          _buildProfileDetail("القطاع الوظيفي", client.employmentType == 'government_sector' ? 'قطاع حكومي' : (client.employmentType == 'private_sector' ? 'قطاع خاص' : 'أعمال حرة')),
          _buildProfileDetail("المسمى الوظيفي والجهة", "${client.jobTitle ?? 'غير محدد'} (${client.companyName ?? 'غير محدد'})"),
          _buildProfileDetail("إجمالي الراتب الموثق", "${_fmt(totalSalary)} ج.م (${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'كاش / نقدي'})"),
          _buildProfileDetail("حالة التأمينات الاجتماعية", client.isInsured ? "مؤمن عليه بالقطاع" : "غير مؤمن عليه"),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 8),
              const Text("المؤشرات والطلبات المالية", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          _buildProfileDetail("المبلغ المطلوب تمويله", "${_fmt(client.requestedAmount)} ج.م"),
          _buildProfileDetail("التقييم الائتماني (I-Score)", "${client.creditScore} نقطة", color: client.creditScore >= 700 ? TfcColors.success : (client.creditScore >= 600 ? Colors.amber : Colors.redAccent)),
          _buildProfileDetail("العبء المالي القائم DTI", "${dti.toStringAsFixed(1)}%", color: dti > 45 ? Colors.redAccent : TfcColors.success),
          
          // Existing Loans Section
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, color: Colors.cyanAccent, size: 18),
              const SizedBox(width: 8),
              Text("تفاصيل القروض القائمة (${client.existingLoans.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          if (client.existingLoans.isEmpty)
            const Text("لا توجد قروض قائمة مسجلة للعميل.", style: TextStyle(color: TfcColors.outline, fontSize: 12))
          else
            ...client.existingLoans.map((l) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                "• ${l.bankName}: قسط (${_fmt(l.installmentValue)} ج.م) ${l.notes != null && l.notes!.isNotEmpty ? '- ${l.notes}' : ''}",
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            )),

          // Credit Cards Section
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.credit_card_outlined, color: Colors.purpleAccent, size: 18),
              const SizedBox(width: 8),
              Text("تفاصيل بطاقات الائتمان (${client.creditCardsRequests.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          if (client.creditCardsRequests.isEmpty)
            const Text("لا توجد بطاقات أو طلبات مسجلة للعميل.", style: TextStyle(color: TfcColors.outline, fontSize: 12))
          else
            ...client.creditCardsRequests.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Text(
                "• ${c.bankName} (${c.type == 'card' ? 'بطاقة' : 'طلب'}): حد (${_fmt(c.value)} ج.م) | قسط (${_fmt(c.installment)} ج.م) ${c.notes != null && c.notes!.isNotEmpty ? '- ${c.notes}' : ''}",
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            )),

          // Documents Section
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(Icons.folder_open_outlined, color: Colors.lightGreenAccent, size: 18),
              const SizedBox(width: 8),
              Text("المستندات المرفوعة وحالتها (${client.documents.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          if (client.documents.isEmpty)
            const Text("لم يتم رفع أي مستندات للعميل حتى الآن.", style: TextStyle(color: TfcColors.outline, fontSize: 12))
          else
            ...client.documents.map((d) {
              Color statusColor = Colors.amber;
              String statusText = "قيد الانتظار";
              if (d.status == 'verified') {
                statusColor = TfcColors.success;
                statusText = "معتمد";
              } else if (d.status == 'rejected') {
                statusColor = Colors.redAccent;
                statusText = "مرفوض";
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "• ${d.documentName}",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.5),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProfileDetail(String title, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: TfcColors.outline, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color ?? Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateDti(ClientModel client) {
    double totalSalary = 0.0;
    if (client.salaryTransferMethod == 'bank_transfer') {
      for (var b in client.salaryBankDetails) {
        totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
      }
    } else {
      totalSalary = client.cashSalaryAmount ?? 0.0;
    }
    if (totalSalary <= 0) return 0.0;

    double totalInstallments = 0.0;
    for (var l in client.existingLoans) {
      totalInstallments += l.installmentValue;
    }
    for (var c in client.creditCardsRequests) {
      totalInstallments += c.fivePercentCalc;
    }

    return (totalInstallments / totalSalary) * 100;
  }
}
