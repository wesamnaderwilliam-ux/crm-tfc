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
مهمتك هي تحليل البيانات المالية للعميل ومطابقتها مع برامج التمويل المتاحة في البنوك لدينا بناءً على معايير وقواعد محددة.

القواعد المعتمدة للمكتب:
\${settings.matchingRules}

المطلوب منك:
1. قراءة بيانات العميل الأساسية والمالية كاملة بتمعن.
2. مراجعة وتحليل تفاصيل القروض والبطاقات القائمة (اسم البنك، قيمة القسط، الملاحظات) والتحقق من التزام العميل.
3. مراجعة ملخص التزامات العميل المالية الكلية ونسبة العبء الائتماني DTI لمطابقتها مع الحدود الائتمانية المسموحة بالبنوك.
4. مراجعة المستندات المرفقة للعميل (أسمائها وحالتها سواء معتمدة verified أو معلقة pending أو مرفوضة) وتحديد مدى كفايتها ومطابقتها للمطلوب.
5. مطابقة وضع العميل الائتماني والمالي والمستندات مع البرامج البنكية المتاحة بدقة، وترشيح أفضل 1 إلى 3 برامج بنكية مناسبة له.
6. كتابة تقرير ائتماني مفصل باللغة العربية ومنسق بأسلوب Markdown جميل ومقروء يحتوي على:
   - **ملخص التقرير المالي للعميل**: نقاط القوة والضعف (مثل الراتب، التقييم الائتماني، تفاصيل الالتزامات والـ DTI، وحالة المستندات المرفقة ومدى كفايتها).
   - **ترشيح البنوك والبرامج المتاحة**: شرح أسباب ترشيح كل برنامج بالتفصيل وكيف يطابق معطيات العميل ومستنداته المرفقة.
   - **التوصيات الاستشارية والخطوات اللاحقة**: التوجيهات اللازمة لتحسين موقف العميل أو إكمال المستندات الناقصة والمرفوضة لضمان موافقة البنك المقترح.

تنسيق الاستجابة:
يجب أن ترجع استجابة JSON تحتوي على حقلين:
- `report`: التقرير النهائي المنسق بصيغة Markdown باللغة العربية.
- `recommended_program_ids`: مصفوفة تحتوي على معرفات البرامج (id الخاص بكل برنامج مطابق من القائمة المتاحة).

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
          'id': p['id'],
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

      // Calculate sum totals for obligations summary
      double totalExistingLoansInstallments = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
      double totalCardsLimits = client.creditCardsRequests.where((c) => c.type == 'card').fold(0.0, (prev, c) => prev + c.value);
      double totalCardsInstallments = client.creditCardsRequests.where((c) => c.type == 'card').fold(0.0, (prev, c) => prev + c.installment);
      double totalCardRequestsLimits = client.creditCardsRequests.where((c) => c.type == 'request').fold(0.0, (prev, c) => prev + c.value);
      double totalCardsFivePercentCalc = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);

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
        'creditScore': client.creditScore,
        'requestedAmount': client.requestedAmount,
        'governorate': client.governorate,
        'dtiPercent': clientDti,
        
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
        
        // Obligations summary
        'obligationsSummary': {
          'totalExistingLoansInstallments': totalExistingLoansInstallments,
          'totalCreditCardsLimits': totalCardsLimits,
          'totalCreditCardsInstallments': totalCardsInstallments,
          'totalCreditCardRequestsLimits': totalCardRequestsLimits,
          'totalCreditCardsFivePercentObligation': totalCardsFivePercentCalc,
          'totalMonthlyObligations': totalExistingLoansInstallments + totalCardsFivePercentCalc,
        },
        
        // Detailed list of uploaded documents
        'documents': client.documents.map((d) => {
          'documentName': d.documentName,
          'status': d.status, // 'pending', 'verified', 'rejected'
        }).toList(),
      };

      final prompt = '''
بيانات العميل:
\${const JsonEncoder.withIndent('  ').convert(clientData)}

البرامج المتاحة بالبنوك:
\${const JsonEncoder.withIndent('  ').convert(formattedPrograms)}
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
      throw Exception('Failed response code: \${response.statusCode} - \${response.body}');
    } catch (e) {
      _logger.e('Gemini API Error, falling back to simulated matching: \$e');
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

// Simulated local rule-based matching engine
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

  // Filter programs based on basic criteria locally
  final List<String> recommendedIds = [];
  final List<String> matchingReasons = [];

  for (var p in availablePrograms) {
    final coreProg = p['core_programs'] as Map<String, dynamic>?;
    final programName = (coreProg?['program_name'] ?? '').toString();
    final bank = p['banks'] as Map<String, dynamic>?;
    final bankName = (bank?['bank_name'] ?? '').toString();
    final description = (p['description'] ?? '').toString();
    final rate = (p['interest_rate'] is num) ? (p['interest_rate'] as num).toDouble() : 20.0;
    final maxAmount = (p['max_loan_amount'] is num) ? (p['max_loan_amount'] as num).toDouble() : 1000000.0;

    bool isMatch = true;

    // Rule 1: Requested amount within limits
    if (client.requestedAmount > maxAmount) {
      isMatch = false;
    }

    // Rule 2: Cash transfer limit check
    if (client.salaryTransferMethod == 'cash' && rate < 18.0) {
      isMatch = false; // premium rate program requires bank transfer
    }

    // Rule 3: Credit score check
    if (client.creditScore < 580 && rate < 22.0) {
      isMatch = false; // weak score can't get low interest rates
    }

    // Rule 4: Salary limit
    if (totalSalary < 5000 && rate < 18.0) {
      isMatch = false; // low salary doesn't qualify for elite programs
    }

    if (isMatch && recommendedIds.length < 3) {
      recommendedIds.add(p['id'].toString());
      matchingReasons.add(
          '* **برنامج ($programName) بـ ($bankName)**: مناسب جداً نظراً لأن فائدته الفعالة تعادل ($rate%) والحد الأقصى للتمويل فيه يصل لـ (${maxAmount.toStringAsFixed(0)} ج.م)، ويتطابق مع نوع قطاع عملك وطريقة تحويل الراتب.${description.isNotEmpty ? "\n  > **وصف البرنامج:** $description" : ""}');
    }
  }

  // If no program matched, recommend the first ones with highest interest rate (flexible criteria)
  if (recommendedIds.isEmpty && availablePrograms.isNotEmpty) {
    // Sort by interest rate descending (typically more flexible)
    final sorted = List<Map<String, dynamic>>.from(availablePrograms)
      ..sort((a, b) {
        final rateA = (a['interest_rate'] is num) ? (a['interest_rate'] as num).toDouble() : 20.0;
        final rateB = (b['interest_rate'] is num) ? (b['interest_rate'] as num).toDouble() : 20.0;
        return rateB.compareTo(rateA);
      });
    final count = sorted.length > 2 ? 2 : sorted.length;
    for (int i = 0; i < count; i++) {
      final p = sorted[i];
      final coreProg = p['core_programs'] as Map<String, dynamic>?;
      final bank = p['banks'] as Map<String, dynamic>?;
      final description = (p['description'] ?? '').toString();
      recommendedIds.add(p['id'].toString());
      matchingReasons.add(
          '* **برنامج (${coreProg?['program_name']}) بـ (${bank?['bank_name']})**: مرشح كخيار بديل بفائدة (${p['interest_rate']}%) لأنه يقبل شروطاً ائتمانية أكثر مرونة.${description.isNotEmpty ? "\n  > **وصف البرنامج:** $description" : ""}');
    }
  }

  // Generate Report Markdown
  final dtiColor = clientDti > 45 ? '🔴' : '🟢';
  final scoreColor = client.creditScore >= 700 ? '🟢' : (client.creditScore >= 600 ? '🟡' : '🔴');
  
  final buffer = StringBuffer();
  buffer.writeln('# 📋 تقرير التحليل الائتماني المساعد');
  buffer.writeln('**تاريخ التحليل:** ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');
  buffer.writeln('**اسم العميل:** ${client.fullName}');
  buffer.writeln('**المندوب المسؤول:** ${client.representativeName ?? "غير محدد"}');
  buffer.writeln('\n---');
  buffer.writeln('## 🔍 أولاً: ملخص تحليل الملف المالي للعميل');
  buffer.writeln('* **السن التقريبي:** $clientAge عاماً.');
  buffer.writeln('* **طريقة استلام الراتب:** ${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'نقدي/كاش'} (إجمالي الراتب: ${totalSalary.toStringAsFixed(0)} ج.م).');
  buffer.writeln('* **القطاع الوظيفي:** ${client.employmentType == 'government_sector' ? 'قطاع حكومي' : (client.employmentType == 'private_sector' ? 'قطاع خاص' : 'أعمال حرة / freelance')}.');
  buffer.writeln('* **التقييم الائتماني (I-Score):** $scoreColor **${client.creditScore}** (${client.creditScore >= 700 ? 'ممتاز ومثالي للمطابقة' : (client.creditScore >= 600 ? 'مقبول وشبه مستقر' : 'ضعيف ويحتوي على خطورة رفض')}).');
  buffer.writeln('* **معدل العبء الائتماني (DTI):** $dtiColor **${clientDti.toStringAsFixed(1)}%** (إجمالي الأقساط القائمة والتزامات البطاقات: ${client.existingLoans.fold(0.0, (double prev, element) => prev + element.installmentValue).toStringAsFixed(0)} ج.م).');
  buffer.writeln('* **نسبة عبء التمويل الجديد المطلوب:** تم تحديد طلب لتمويل قيمته (${client.requestedAmount.toStringAsFixed(0)} ج.م).');

  buffer.writeln('\n---');
  buffer.writeln('## 💡 ثانياً: البرامج الائتمانية الموصى بها ومطابقة البنوك');
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
