import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import 'package:logger/logger.dart';

final Logger _logger = Logger();

class AiSettings {
  final String apiKey;
  final String model;
  final String matchingRules;

  AiSettings({
    required this.apiKey,
    required this.model,
    required this.matchingRules,
  });

  AiSettings copyWith({
    String? apiKey,
    String? model,
    String? matchingRules,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      matchingRules: matchingRules ?? this.matchingRules,
    );
  }
}

class AiSettingsNotifier extends StateNotifier<AiSettings> {
  AiSettingsNotifier()
      : super(AiSettings(
          apiKey: '',
          model: 'gemini-1.5-flash',
          matchingRules: _defaultRules,
        )) {
    _loadSettings();
  }

  static const String _defaultRules = '''
المعايير المعتمدة للمطابقة:
1. تحويل الراتب: البرامج ذات الفائدة المنخفضة (< 18%) تتطلب "تحويل راتب بنكي".
2. نوع القطاع:
   - قطاع حكومي أو خاص مؤمن عليه: مؤهل لمعظم البرامج ذات الفوائد التنافسية.
   - أعمال حرة أو قطاع خاص غير مؤمن عليه: يوجه لبرامج مخصصة بفائدة أعلى ومستندات بديلة (مثل سجل تجاري وبطاقة ضريبية).
3. الحد الأدنى للراتب:
   - تمويل شخصي أو عقاري كبير: حد أدنى للراتب 7,000 ج.م.
   - تمويل متوسط أو بطاقات ائتمان: حد أدنى للراتب 4,000 ج.م.
4. التقييم الائتماني (I-Score):
   - ممتاز (> 720): مؤهل لنسبة فائدة تفضيلية ومبالغ تمويل قصوى.
   - مقبول (580 - 720): مؤهل للبرامج الاعتيادية.
   - ضعيف (< 580): ينصح بتحسين التقييم أو التقديم بضمانات إضافية.
''';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('tfc_gemini_api_key') ?? '';
      final model = prefs.getString('tfc_gemini_model') ?? 'gemini-1.5-flash';
      final matchingRules = prefs.getString('tfc_gemini_rules') ?? _defaultRules;
      state = AiSettings(apiKey: apiKey, model: model, matchingRules: matchingRules);
    } catch (e) {
      _logger.e('Error loading AI settings: $e');
    }
  }

  Future<void> setApiKey(String apiKey) async {
    state = state.copyWith(apiKey: apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tfc_gemini_api_key', apiKey);
  }

  Future<void> setModel(String model) async {
    state = state.copyWith(model: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tfc_gemini_model', model);
  }

  Future<void> setMatchingRules(String rules) async {
    state = state.copyWith(matchingRules: rules);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tfc_gemini_rules', rules);
  }
}

final aiSettingsProvider = StateNotifierProvider<AiSettingsNotifier, AiSettings>((ref) {
  return AiSettingsNotifier();
});

class AiAnalysisResult {
  final String reportMarkdown;
  final List<String> recommendedProgramIds; // Detail IDs matching best programs

  AiAnalysisResult({
    required this.reportMarkdown,
    required this.recommendedProgramIds,
  });
}

final aiAnalysisProvider = Provider((ref) {
  final settings = ref.watch(aiSettingsProvider);

  Future<AiAnalysisResult> analyzeClient({
    required ClientModel client,
    required List<Map<String, dynamic>> availablePrograms,
  }) async {
    // If API Key is missing, fallback to simulation mode
    if (settings.apiKey.trim().isEmpty) {
      return _generateSimulatedAnalysis(client, availablePrograms, settings.matchingRules);
    }

    try {
      final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/${settings.model}:generateContent?key=${settings.apiKey}');

      final systemPrompt = '''
أنت خبير ائتمان مالي ومستشار تمويلي ذكي لشركة "The Future Club" للاستشارات التمويلية.
مهمتك هي تحليل البيانات المالية والائتمانية والأصول للعميل بدقة وحرفية عالية، ومطابقتها مع وصف وشروط برامج التمويل المتاحة في دليل البنوك لدينا بذكاء وخبرة.

المطلوب منك:
1. **دراسة طبيعة وقطاع الوظيفة**: (قطاع حكومي، خاص مؤمن عليه، خاص غير مؤمن عليه، أعمال حرة، مهن حرة) والتحقق من الاستقرار الوظيفي والتأمينات.
2. **تحليل العبء الائتماني المتبقي (Remaining DBR Margin)**:
   - الحد الأقصى المسموح به للعبء الائتماني (DBR / DTI) هو 50% من إجمالي الراتب.
   - حساب إجمالي الالتزامات الشهرية القائمة (أقساط القروض القائمة + 5% من حدود جميع البطاقات والطلبات).
   - حساب المتبقي من الميزانية الشهرية المتاحة للتمويل الجديد: `(الراتب × 50%) - إجمالي الأقساط والالتزامات الحالية`.
3. **تحليل الأصول الضامنة والتمويلية الخاصة**:
   - التحقق إذا كان العميل يملك **وحدة في كمبوند** (اسم الكمبوند، الشركة المكونة، قيمة القسط/الوحدة) ومطابقته مع برامج البنوك المخصصة لملاك الكمبوندات أو أصحاب العقارات.
   - التحقق إذا كان العميل يملك **سيارة حديثة** (ماركة السيارة، الموديل، القيمة السوقية) ومطابقته مع برامج البنوك الخاصة بمالكي السيارات الحديثة أو أصحاب المركبات.
4. **مطابقة البيانات مع وصف برامج البنوك بدقة وخبرة**:
   - مراجعة وصف كل برنامج (`description`) والشروط الخاصة بكل بنك في القائمة المتاحة.
   - ترشيح أفضل 1 إلى 3 برامج بنكية مناسبة للعميل من قائمة دليل البنوك بناءً على المطابقة الدقيقة.
5. **كتابة تقرير ائتماني تحليلي مفصل** باللغة العربية ومنسق بأسلوب Markdown جميل ومقروء يحتوي على:
   - **ملخص التقرير المالي للعميل**: نقاط القوة والضعف (طبيعة الوظيفة، الراتب، I-Score، الـ DTI الحالية، **المتبقي المتاح من الـ DBR والقسط الشهري المسموح**، وجود وحدات كمبوند أو سيارات حديثة).
   - **ترشيح البنوك والبرامج المتاحة من دليل البنوك**: ذكر أسباب ترشيح كل برنامج بالتفصيل وكيف يطابق الوصف المذكور في دليل البنوك ومعطيات العميل.
   - **التوصيات الاستشارية والخطوات اللاحقة**: التوجيهات الخبيرة اللازمة لرفع فرصة الموافقة الائتمانية.

تنسيق الاستجابة:
يجب أن ترجع استجابة JSON تحتوي على حقلين:
- `report`: التقرير النهائي المنسق بصيغة Markdown باللغة العربية.
- `recommended_program_ids`: مصفوفة تحتوي على معرفات البرامج (`id` الخاص بكل برنامج مطابق من القائمة المتاحة).

تنسيق الـ JSON المطلوب إرجاعه:
```json
{
  "report": "نص التقرير هنا بـ Markdown...",
  "recommended_program_ids": ["id_1", "id_2"]
}
```
تأكد من إرجاع JSON صالح فقط بدون نصوص إضافية خارجه.
''';

      // Format programs for prompt context
      final formattedPrograms = availablePrograms.map((p) {
        final coreProg = p['core_programs'] as Map<String, dynamic>?;
        final progName = coreProg?['program_name'] ?? 'برنامج عام';
        final bank = p['banks'] as Map<String, dynamic>?;
        final bankName = bank?['bank_name'] ?? 'بنك غير معروف';
        
        return {
          'id': p['id']?.toString() ?? '',
          'bank_name': bankName,
          'program_name': progName,
          'description': p['description'] ?? '',
          'interest_rate': p['interest_rate'] ?? 0.0,
          'max_loan_amount': p['max_loan_amount'] ?? 0.0,
        };
      }).toList();

      // Format client details for prompt context
      final clientDti = _calculateDti(client);
      final clientAge = _calculateAge(client.birthDate);
      
      double totalSalary = 0.0;
      if (client.salaryTransferMethod == 'bank_transfer') {
        for (var b in client.salaryBankDetails) {
          totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
        }
      } else {
        totalSalary = client.cashSalaryAmount ?? 0.0;
      }

      // Calculate sum totals for obligations summary
      double totalExistingLoansInstallments = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
      double totalCardsLimits = client.creditCardsRequests.where((c) => c.type == 'card').fold(0.0, (prev, c) => prev + c.value);
      double totalCardsInstallments = client.creditCardsRequests.where((c) => c.type == 'card').fold(0.0, (prev, c) => prev + c.installment);
      double totalCardRequestsLimits = client.creditCardsRequests.where((c) => c.type == 'request').fold(0.0, (prev, c) => prev + c.value);
      double totalCardsFivePercentCalc = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);

      double totalMonthlyObligations = totalExistingLoansInstallments + totalCardsFivePercentCalc;
      double maxAllowedDbrObligation = totalSalary * 0.50; // 50% max DBR rule
      double remainingAvailableInstallmentBudget = maxAllowedDbrObligation - totalMonthlyObligations;
      if (remainingAvailableInstallmentBudget < 0) remainingAvailableInstallmentBudget = 0;
      double remainingDbrMarginPercent = 50.0 - clientDti;
      if (remainingDbrMarginPercent < 0) remainingDbrMarginPercent = 0;

      final clientData = {
        'fullName': client.fullName,
        'age': clientAge,
        'employmentType': client.employmentType,
        'companyName': client.companyName ?? 'غير محدد',
        'jobTitle': client.jobTitle ?? 'غير محدد',
        'isInsured': client.isInsured,
        'salaryTransferMethod': client.salaryTransferMethod,
        'cashSalaryAmount': client.cashSalaryAmount ?? 0.0,
        'salaryBankDetails': client.salaryBankDetails,
        'totalVerifiedSalary': totalSalary,
        'creditScore': client.creditScore,
        'requestedAmount': client.requestedAmount,
        'governorate': client.governorate,
        
        // DTI & DBR Detailed Calculations
        'dtiAnalysis': {
          'currentDtiPercent': clientDti,
          'maxAllowedDbrPercent': 50.0,
          'remainingDbrMarginPercent': remainingDbrMarginPercent,
          'totalMonthlyObligations': totalMonthlyObligations,
          'maxAllowedMonthlyObligationBudget': maxAllowedDbrObligation,
          'remainingAvailableInstallmentBudgetForNewLoan': remainingAvailableInstallmentBudget,
        },
        
        // Detailed list of existing loans
        'existingLoans': client.existingLoans.map((l) => {
          'bankName': l.bankName,
          'installmentValue': l.installmentValue,
          'notes': l.notes ?? '',
        }).toList(),
        
        // Detailed list of credit cards & requests
        'creditCardsAndRequests': client.creditCardsRequests.map((c) => {
          'bankName': c.bankName,
          'type': c.type, // 'card' or 'request'
          'limitValue': c.value,
          'fivePercentCalc': c.fivePercentCalc,
          'installment': c.installment,
          'highestValueUsed': c.highestValue,
          'duration': c.duration,
          'notes': c.notes ?? '',
        }).toList(),
        
        // Assets & Special Programs Eligibility
        'assetsData': {
          'hasCompoundUnit': client.hasCompoundUnit,
          'compoundUnits': client.compoundUnitsData,
          'hasModernCar': client.hasModernCar,
          'modernCars': client.modernCarsData,
          'businessData': client.businessData,
        },
        
        // Detailed list of uploaded documents
        'documents': client.documents.map((d) => {
          'documentName': d.documentName,
          'status': d.status, // 'pending', 'verified', 'rejected'
        }).toList(),
      };

      final prompt = '''
بيانات العميل المالية والائتمانية والأصول الكاملة:
${const JsonEncoder.withIndent('  ').convert(clientData)}

دليل برامج البنوك المتاحة للتطابق:
${const JsonEncoder.withIndent('  ').convert(formattedPrograms)}
''';

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': systemPrompt},
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json',
          }
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final candidates = responseData['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final responseText = parts[0]['text'] as String;
            
            // Parse candidate JSON response
            final Map<String, dynamic> parsedJson = jsonDecode(responseText);
            final report = parsedJson['report'] as String? ?? 'تعذر تكوين التقرير الائتماني.';
            final rawIds = parsedJson['recommended_program_ids'] as List? ?? [];
            final ids = rawIds.map((e) => e.toString()).toList();
            
            return AiAnalysisResult(reportMarkdown: report, recommendedProgramIds: ids);
          }
        }
      }
      throw Exception('Failed response code: ${response.statusCode} - ${response.body}');
    } catch (e) {
      _logger.e('Gemini API Error, falling back to simulated matching: $e');
      return _generateSimulatedAnalysis(client, availablePrograms, settings.matchingRules);
    }
  }

  return analyzeClient;
});

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
    // 5% calculation on credit card limits counts as monthly obligation
    totalInstallments += c.fivePercentCalc;
  }

  return (totalInstallments / totalSalary) * 100;
}

int _calculateAge(String birthDateStr) {
  try {
    final birthDate = DateTime.parse(birthDateStr);
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  } catch (_) {
    return 35; // default fallback
  }
}

// Simulated local rule-based matching engine with deep analytical criteria
AiAnalysisResult _generateSimulatedAnalysis(
  ClientModel client,
  List<Map<String, dynamic>> availablePrograms,
  String rulesText,
) {
  final clientDti = _calculateDti(client);
  final clientAge = _calculateAge(client.birthDate);
  
  double totalSalary = 0.0;
  if (client.salaryTransferMethod == 'bank_transfer') {
    for (var b in client.salaryBankDetails) {
      totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
    }
  } else {
    totalSalary = client.cashSalaryAmount ?? 0.0;
  }

  double totalExistingLoansInstallments = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
  double totalCardsFivePercentCalc = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);
  double totalMonthlyObligations = totalExistingLoansInstallments + totalCardsFivePercentCalc;
  double maxAllowedDbrObligation = totalSalary * 0.50; // 50% max DBR limit
  double remainingAvailableInstallmentBudget = maxAllowedDbrObligation - totalMonthlyObligations;
  if (remainingAvailableInstallmentBudget < 0) remainingAvailableInstallmentBudget = 0;
  double remainingDbrMarginPercent = 50.0 - clientDti;
  if (remainingDbrMarginPercent < 0) remainingDbrMarginPercent = 0;

  final List<String> recommendedIds = [];
  final List<String> matchingReasons = [];

  // Analytical scoring per program
  final List<Map<String, dynamic>> scoredPrograms = [];

  for (var p in availablePrograms) {
    final coreProg = p['core_programs'] as Map<String, dynamic>?;
    final programName = (coreProg?['program_name'] ?? '').toString();
    final bank = p['banks'] as Map<String, dynamic>?;
    final bankName = (bank?['bank_name'] ?? '').toString();
    final description = (p['description'] ?? '').toString();
    final rate = (p['interest_rate'] is num) ? (p['interest_rate'] as num).toDouble() : 20.0;
    final maxAmount = (p['max_loan_amount'] is num) ? (p['max_loan_amount'] as num).toDouble() : 1000000.0;

    int matchScore = 100;
    final List<String> reasons = [];

    // 1. DBR & Remaining Installment Budget Match
    if (clientDti >= 50.0) {
      matchScore -= 40;
      reasons.add("تجاوز نسبة الـ DBR المسموحة (50%).");
    } else {
      reasons.add("المتبقي المتاح من الـ DBR يعادل (${remainingDbrMarginPercent.toStringAsFixed(1)}%) بميزانية قسط متبقية (${remainingAvailableInstallmentBudget.toStringAsFixed(0)} ج.م/شهرياً).");
    }

    // 2. Requested Amount Match
    if (client.requestedAmount <= maxAmount) {
      matchScore += 20;
      reasons.add("المبلغ المطلوب (${client.requestedAmount.toStringAsFixed(0)} ج.م) يقع ضمن الحد الأقصى للبرنامج (${maxAmount.toStringAsFixed(0)} ج.م).");
    } else {
      matchScore -= 30;
      reasons.add("المبلغ المطلوب يتدعدى الحد الأقصى للبرنامج.");
    }

    // 3. Employment Type & Insurance Match
    final descLower = description.toLowerCase();
    final progLower = programName.toLowerCase();

    if (client.employmentType == 'government_sector' || (client.employmentType == 'private_sector' && client.isInsured)) {
      matchScore += 25;
      reasons.add("العميل ينتمي لقطاع مستقر ومؤمن عليه مما يمنحه أولوية قبول بالبنك.");
    } else if (client.employmentType == 'freelance' || !client.isInsured) {
      if (descLower.contains('أعمال حرة') || descLower.contains('مهن حرة') || descLower.contains('بدون إثبات') || descLower.contains('سجل تجاري')) {
        matchScore += 30;
        reasons.add("البرنامج يطابق شروط الأعمال الحرة والقطاع غير المؤمن بمرونة.");
      } else {
        matchScore -= 15;
      }
    }

    // 4. Compound Units & Assets Match
    if (client.hasCompoundUnit) {
      if (descLower.contains('كمبوند') || descLower.contains('عقار') || descLower.contains('ملاك') || progLower.contains('عقاري') || progLower.contains('كمبوند')) {
        matchScore += 35;
        reasons.add("العميل يملك وحدة في كمبوند مما يطابق برنامج البنك الخاص بملاك العقارات والكمبوندات.");
      }
    }

    // 5. Modern Cars Match
    if (client.hasModernCar) {
      if (descLower.contains('سيارة') || descLower.contains('سيارات') || descLower.contains('مركبات') || progLower.contains('سيارات')) {
        matchScore += 35;
        reasons.add("العميل يملك سيارة حديثة مما يطابق برنامج البنك المخصص لمالكي السيارات.");
      }
    }

    // 6. Salary Transfer Method
    if (client.salaryTransferMethod == 'bank_transfer') {
      matchScore += 15;
      reasons.add("طريقة تحويل الراتب بنكية مما يتيح فائدة تنافسية قدرها ($rate%).");
    }

    scoredPrograms.add({
      'program': p,
      'score': matchScore,
      'reasons': reasons,
      'description': description,
      'programName': programName,
      'bankName': bankName,
      'rate': rate,
      'maxAmount': maxAmount,
    });
  }

  // Sort by matchScore descending
  scoredPrograms.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

  final topPrograms = scoredPrograms.take(3).toList();
  for (var item in topPrograms) {
    final p = item['program'] as Map<String, dynamic>;
    recommendedIds.add(p['id'].toString());

    final pName = item['programName'];
    final bName = item['bankName'];
    final rate = item['rate'];
    final desc = item['description'];
    final List<String> rList = item['reasons'] as List<String>;

    final reasonStr = rList.map((r) => "   - $r").join("\n");

    matchingReasons.add(
      '* **برنامج ($pName) بـ ($bName)** (فائدة $rate% - أقصى مبلغ ${item['maxAmount']} ج.م):\n'
      '$reasonStr'
      '${desc.toString().isNotEmpty ? "\n  > **وصف واشتراطات البرنامج في دليل البنوك:** $desc" : ""}'
    );
  }

  // Generate Analytical Report Markdown
  final dtiColor = clientDti > 45 ? '🔴' : '🟢';
  final scoreColor = client.creditScore >= 700 ? '🟢' : (client.creditScore >= 600 ? '🟡' : '🔴');
  
  final buffer = StringBuffer();
  buffer.writeln('# 📋 تقرير التحليل الائتماني والترشيح البنكي الخبير');
  buffer.writeln('**تاريخ الفحص:** ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');
  buffer.writeln('**اسم العميل:** ${client.fullName}');
  buffer.writeln('**جهة العمل:** ${client.companyName ?? "غير محدد"} (${client.jobTitle ?? "غير محدد"})');
  buffer.writeln('\n---');
  
  buffer.writeln('## 📊 أولاً: تحليل طبيعة الوظيفة ومؤشرات الـ DBR والالتزامات');
  buffer.writeln('* **طبيعة الوظيفة والقطاع:** ${client.employmentType == 'government_sector' ? 'قطاع حكومي' : (client.employmentType == 'private_sector' ? 'قطاع خاص' : 'أعمال حرة')} (${client.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"}).');
  buffer.writeln('* **إجمالي الراتب الموثق:** ${totalSalary.toStringAsFixed(0)} ج.م (${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'كاش / نقدي'}).');
  buffer.writeln('* **التقييم الائتماني (I-Score):** $scoreColor **${client.creditScore}** نقطة.');
  buffer.writeln('* **إجمالي الالتزامات الشهرية القائمة:** ${totalMonthlyObligations.toStringAsFixed(0)} ج.م (أقساط قروض: ${totalExistingLoansInstallments.toStringAsFixed(0)} ج.م + استقطاع 5% بطاقات: ${totalCardsFivePercentCalc.toStringAsFixed(0)} ج.م).');
  buffer.writeln('* **نسبة العبء الائتماني الحالية (DTI):** $dtiColor **${clientDti.toStringAsFixed(1)}%** من أصل الحد الأقصى 50%.');
  buffer.writeln('* **المتبقي المتاح من الـ DBR:** **${remainingDbrMarginPercent.toStringAsFixed(1)}%**.');
  buffer.writeln('* **ميزانية القسط الشهري المتاح للتمويل الجديد:** 🟢 **${remainingAvailableInstallmentBudget.toStringAsFixed(0)} ج.م / شهرياً**.');
  
  if (client.hasCompoundUnit || client.hasModernCar) {
    buffer.writeln('\n---');
    buffer.writeln('## 🏡🚗 ثانياً: تحليل الأصول الضامنة والتمويلية الخاصة');
    if (client.hasCompoundUnit) {
      buffer.writeln('* **وحدة في كمبوند:** نعم (عدد الوحدات: ${client.compoundUnitsData.length}) - تمنح ميزة التقديم في برامج ملاك العقارات والكمبوندات.');
    }
    if (client.hasModernCar) {
      buffer.writeln('* **سيارة حديثة:** نعم (عدد السيارات: ${client.modernCarsData.length}) - تمنح ميزة التقديم في برامج أصحاب السيارات الحديثة.');
    }
  }

  buffer.writeln('\n---');
  buffer.writeln('## 💡 ثالثاً: البرامج الائتمانية للبنوك الموصى بها من دليل البنوك');
  if (matchingReasons.isEmpty) {
    buffer.writeln('⚠️ لم نجد برامج تتوافق مع بيانات العميل الائتمانية بشكل كامل حالياً. يرجى مراجعة معايير المطابقة في الإعدادات أو إضافة برامج جديدة بقاعدة البيانات.');
  } else {
    buffer.writeln('بناءً على معايير المطابقة الإرشادية والبيانات المرفقة للعميل، تم ترشيح البرامج التالية لضمان الحصول على أعلى موافقة ائتمانية:');
    buffer.writeln('');
    for (var reason in matchingReasons) {
      buffer.writeln(reason);
    }
  }

  buffer.writeln('\n---');
  buffer.writeln('## 🛠️ ثالثاً: توصيات استشاري التمويل والخطوات اللاحقة');
  buffer.writeln('1. **تحديث كشف الحساب**: يجب تجهيز كشف حساب بنكي رسمي مختوم لآخر 6 أشهر يوضح انتظام تحويل الرواتب.');
  if (clientDti > 45) {
    buffer.writeln('2. **تخفيض نسبة الـ DTI**: ينصح العميل بسداد إحدى المديونيات القائمة أو غلق بعض بطاقات الائتمان غير المستخدمة لخفض نسبة العبء الائتماني من أجل رفع فرصة الموافقة على القرض الجديد.');
  }
  if (client.creditScore < 600) {
    buffer.writeln('3. **تحسين الـ I-Score**: يلزم مراجعة التقرير الائتماني والتأكد من عدم وجود متأخرات قائمة، وسداد أي مبالغ مستحقة فورا.');
  }
  buffer.writeln('4. **مستندات العمل**: استخراج شهادة راتب (مفردات مرتب) حديثة موجهة للبنك المطلوب، والتأكد من تطابق المسمى الوظيفي المذكور بها.');
  
  buffer.writeln('\n*💡 ملاحظة: هذا التقرير تم إنشاؤه عبر "نظام الفحص المحاكي الذكي" المدمج بالتطبيق. يمكنك تفعيل Gemini AI من صفحة الإعدادات للحصول على تقارير أكثر دقة وتفصيلاً.*');

  return AiAnalysisResult(
    reportMarkdown: buffer.toString(),
    recommendedProgramIds: recommendedIds,
  );
}
