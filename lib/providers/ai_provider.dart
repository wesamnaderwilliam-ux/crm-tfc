import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/client_model.dart';
import '../core/supabase_config.dart';
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
قواعد واشتراطات المطابقة الائتمانية الصارمة (Strict Credit Qualification Rules):
1. **طبيعة الوظيفة والقطاع**:
   - قطاع حكومي / خاص مؤمن عليه: يحق له التقديم على جميع برامج تحويل الراتب والشركات المعتمدة.
   - قطاع خاص غير مؤمن عليه / أعمال حرة: يمنع منعاً باتاً ترشيحه لبرامج تحويل الراتب البنكية المباشرة، وتقتصر التوصية فقط على برامج (أعمال حرة، مهن حرة، سجل تجاري، أو أصحاب العقارات والسيارات).
2. **نسبة الـ DBR المتبقية وميزانية القسط**:
   - يُحظر ترشيح أي تمويل يتجاوز قسطه الشهري المتوقع ميزانية القسط المتبقية المتاحة للعميل (50% من الراتب - الأقساط القائمة و5% من البطاقات).
   - إذا كانت نسبة الـ DTI الحالية 50% أو أكثر، يُمنع ترشيح أية قروض جديدة وتقتصر التوصية على "سداد مديونيات أو غلق بطاقات".
3. **مطابقة الأصول التمويلية الخاصة (الكمبوندات والسيارات)**:
   - برامج البنوك الخاصة بـ (ملاك الوحدات في الكمبوندات) تُشترط فقط إذا كان العميل يملك بالفعل وحدة في كمبوند (`hasCompoundUnit = true`).
   - برامج البنوك الخاصة بـ (أصحاب السيارات الحديثة) تُشترط فقط إذا كان العميل يملك سيارة حديثة (`hasModernCar = true`).
4. **المطابقة مع الوصف الرسمي المذكور في دليل البنوك**:
   - يمنع اختيار أو ترشيح أي برنامج بنكي إذا كان الوصف المذكور له في دليل البنوك يتضمن شرطاً مفقوداً أو غير متوفر لدى العميل.
''';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String apiKey = prefs.getString('tfc_gemini_api_key') ?? '';
      String model = prefs.getString('tfc_gemini_model') ?? 'gemini-1.5-flash';
      String matchingRules = prefs.getString('tfc_gemini_rules') ?? _defaultRules;

      // Try loading global settings from Supabase if initialized
      if (SupabaseConfig.isInitialized) {
        try {
          final res = await SupabaseConfig.client
              .from('app_settings')
              .select('value')
              .eq('key', 'ai_settings')
              .maybeSingle();

          if (res != null && res['value'] != null) {
            final Map<String, dynamic> data = Map<String, dynamic>.from(res['value']);
            if (data['api_key'] != null && (data['api_key'] as String).isNotEmpty) {
              apiKey = data['api_key'];
            }
            if (data['model'] != null && (data['model'] as String).isNotEmpty) {
              model = data['model'];
            }
            if (data['matching_rules'] != null && (data['matching_rules'] as String).isNotEmpty) {
              matchingRules = data['matching_rules'];
            }
          }
        } catch (e) {
          _logger.w('Supabase app_settings fetch skipped or table missing: $e');
        }
      }

      state = AiSettings(apiKey: apiKey, model: model, matchingRules: matchingRules);
    } catch (e) {
      _logger.e('Error loading AI settings: $e');
    }
  }

  Future<void> saveAllSettings({required String apiKey, required String model, required String matchingRules}) async {
    state = AiSettings(apiKey: apiKey, model: model, matchingRules: matchingRules);
    
    // Save to local SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('tfc_gemini_api_key', apiKey);
      await prefs.setString('tfc_gemini_model', model);
      await prefs.setString('tfc_gemini_rules', matchingRules);
    } catch (e) {
      _logger.e('Error saving AI settings locally: $e');
    }

    // Save globally to Supabase table `app_settings` for all users
    if (SupabaseConfig.isInitialized) {
      try {
        await SupabaseConfig.client.from('app_settings').upsert({
          'key': 'ai_settings',
          'value': {
            'api_key': apiKey,
            'model': model,
            'matching_rules': matchingRules,
            'updated_at': DateTime.now().toIso8601String(),
          }
        }, onConflict: 'key');
      } catch (e) {
        _logger.e('Error saving AI settings to Supabase app_settings: $e');
      }
    }
  }

  Future<void> setApiKey(String apiKey) async {
    await saveAllSettings(apiKey: apiKey, model: state.model, matchingRules: state.matchingRules);
  }

  Future<void> setModel(String model) async {
    await saveAllSettings(apiKey: state.apiKey, model: model, matchingRules: state.matchingRules);
  }

  Future<void> setMatchingRules(String rules) async {
    await saveAllSettings(apiKey: state.apiKey, model: state.model, matchingRules: rules);
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
أنت "رئيس قطاع التحليل وإدارة المخاطر الائتمانية" ومستشار تمويلي أول لشركة "The Future Club (TFC)" للاستشارات التمويلية في مصر.
مهمتك هي إجراء فحص وتحليل ائتماني شامل ودقيق جداً لملف العميل، وبناء تقرير ائتماني احترافي، ومطابقة ملف العميل بدقة متناهية مع برامج البنوك المتاحة (سواء كانت برامج قائمة على دخل حقيقي أو برامج قائمة على دخل افتراضي / بدائل الدخل).

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🏦 المعايير الائتمانية وقواعد البرامج التمويلية (بنوك مصر):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. **تحليل الدخل الحقيقي (Real Income Programs):**
   - قطاع حكومي / قطاع خاص مؤمن عليه (بتحويل راتب): مؤهل لكافة برامج القروض الشخصية وبطاقات الائتمان بتحويل راتب بأعلى نسب تمويل وأقل أسعار فائدة.
   - قطاع خاص غير مؤمن عليه / دخل كاش / أصحاب مهن حرة: لا يتم ترشيحه لبرامج تحويل الراتب، وإنما يُوجّه لبرامج (المهن الحرة، أصحاب الأنشطة والسجلات التجارية، أو برامج بدائل الدخل الافتراضي).

2. **تحليل الدخل الافتراضي وبدائل الدخل (Surrogate / Alternative Income Programs):**
   - **برامج ملاك الوحدات بالكمبوندات والعقارات:** إذا كان العميل يملك وحدة في كمبوند أو عقار، يتم احتساب دخل افتراضي بناءً على القيمة التقديرية للوحدة وقيمة القسط المدفوع، ويُرشح لبرامج (ملاك الكمبوندات) التي تمنح تمويلات تصل إلى 2-5 مليون جنيه بدون اشتراط تحويل راتب أو إثبات دخل تقليدي.
   - **برامج ملاك السيارات الحديثة:** إذا كان العميل يملك سيارة حديثة (موديل آخر 3-5 سنوات)، يُرشح لبرامج التمويل بضمان رخصة السيارة والتي تمنح من 50% إلى 75% من القيمة السوقية التقديرية للسيارة.
   - **برامج بضمان الأوعية الادخارية والشهادات والودائع:** تمنح قروضاً تصل إلى 80%-90% من القيمة الاسمية للشهادات والودائع مع بقاء أصل الشهادة وعائدها.
   - **برامج بضمان البطاقات الائتمانية وحركات التطبيقات الرقمية:** في حال وجود بطاقات ائتمانية منتظمة أو سجل تعامل على تطبيقات التمويل، تتيح بعض البنوك برامج تمويل تعتمد على متوسط حدود البطاقات وتاريخ السداد (Good Standing).

3. **قواعد عبء الدين (DBR / DTI) الصارمة لتعليمات البنك المركزي المصري (CBE):**
   - الحد الأقصى لعبء الدين الإجمالي هو 50% من إجمالي الدخل المعتمد (الحقيقي أو الافتراضي).
   - إجمالي الالتزامات الشهرية = أقساط القروض القائمة + 5% من حدود جميع البطاقات الائتمانية والطلبات + أي التزامات أخرى.
   - هامش القسط المتاح للتمويل الجديد = `(إجمالي الدخل × 50%) - إجمالي الالتزامات الحالية`.
   - إذا كانت نسبة DTI الحالية 50% أو أكثر، يمنع ترشيح تمويل إضافي وتقتصر التوصية على (شراء مديونية، دمج قروض، أو إغلاق بطاقات ائتمانية).

4. **مطابقة برامج البنوك المتاحة بدقة:**
   - قم بمراجعة برامج البنوك المتاحة في القائمة المرفقة، وطابق شروط ووصف كل برنامج مع مؤشرات العميل (نوع الوظيفة، الـ DBR المتاح، الأصول الضامنة مثل الكمبوند والسيارة، والمبلغ المطلوب).
   - اختر فقط البرامج القابلة للتنفيذ بنسبة قبول ائتماني عالية واذكر أسباب الترشيح الدقيقة لكل بنك وبرنامج.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 التقرير الائتماني المالي المطلوب (Markdown):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
اكتب تقريراً غنياً وواضحاً ومقسماً إلى:
1. **الملخص الائتماني والتقييم الشامل**: (نوع الدخل، تقييم I-Score، الـ DTI الحالية، وميزانية القسط الشهري المتاح بدقة).
2. **تحليل بدائل الدخل والأصول الضامنة**: (بيان موقف وحدات الكمبوند، السيارات، الأنشطة، ومصادر الدخل الافتراضي).
3. **ترشيحات البرامج البنكية الأنسب**: ذكر كل برنامج بنكي والبنك وشروط التطابق والمبلغ المتاح وفترة السداد المقترحة.
4. **خطة العمل والتوصيات الائتمانية**: (المستندات المطلوبة، نصائح رفع فرصة الموافقة، وإرشادات معالجة الالتزامات إن لزم).

تنسيق الـ JSON المطلوب إرجاعه حصراً:
```json
{
  "report": "نص التقرير هنا بصيغة Markdown منسقة جداً...",
  "recommended_program_ids": ["id_1", "id_2"]
}
```
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

final aiChatProvider = Provider((ref) {
  final settings = ref.watch(aiSettingsProvider);

  Future<String> chatWithAi({
    ClientModel? client,
    List<Map<String, dynamic>>? availablePrograms,
    required List<Map<String, String>> chatHistory,
    required String userQuestion,
  }) async {
    final progs = availablePrograms ?? [];
    
    // Build context details if a client is selected
    String clientContext = '';
    if (client != null) {
      final clientDti = _calculateDti(client);
      double totalSalary = 0.0;
      if (client.salaryTransferMethod == 'bank_transfer') {
        for (var b in client.salaryBankDetails) {
          totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
        }
      } else {
        totalSalary = client.cashSalaryAmount ?? 0.0;
      }
      final double totalLoans = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
      final double totalCardsFive = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);
      final double totalObligations = totalLoans + totalCardsFive;
      final double maxDbrObligation = totalSalary * 0.50;
      final double remainingBudget = (maxDbrObligation - totalObligations).clamp(0, maxDbrObligation);

      clientContext = '''
📌 **بيانات العميل الحالي المرفق بالمحادثة:**
- **الاسم:** ${client.fullName}
- **السن:** ${_calculateAge(client.birthDate)} سنة
- **المحافظة:** ${client.governorate}
- **طبيعة الوظيفة والقطاع:** ${client.employmentType} (${client.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"})
- **جهة العمل:** ${client.companyName ?? "غير محدد"} - المسمى الوظيفي: ${client.jobTitle ?? "غير محدد"}
- **إجمالي الراتب الموثق:** ${totalSalary.toStringAsFixed(0)} ج.م (${client.salaryTransferMethod})
- **التقييم الائتماني (I-Score):** ${client.creditScore} نقطة
- **التمويل المطلوب:** ${client.requestedAmount.toStringAsFixed(0)} ج.م
- **إجمالي الالتزامات الشهرية القائمة:** ${totalObligations.toStringAsFixed(0)} ج.م
- **نسبة العبء الائتماني الحالية (DTI):** ${clientDti.toStringAsFixed(1)}% (الحد الأقصى للبنك المركزي 50%)
- **ميزانية القسط الشهري المتاح للتمويل الجديد (DBR Margin):** ${remainingBudget.toStringAsFixed(0)} ج.م شهرياً
- **الأصول الضامنة:** يملك وحدة بكمبوند: ${client.hasCompoundUnit ? "نعم" : "لا"} | يملك سيارة حديثة: ${client.hasModernCar ? "نعم" : "لا"}
''';
    }

    final String systemPrompt = '''
أنت "المستشار المالي والاقتصادي والبنكي الذكي" لشركة The Future Club (TFC) للاستشارات المالية والتمويلية في جمهورية مصر العربية.
أنت خبير اقتصادي ومصرفي رفيع المستوى وملم بكافة:
1. **تعليمات وقواعد البنك المركزي المصري (CBE)**، بما فيها نسب عبء الدين (DBR / DTI بحد أقصى 50% للتمويل الاستهلاكي والعقاري).
2. **القطاع المصرفي المصري وبرامج البنوك المصرية**: (البنك الأهلي المصري، بنك مصر، بنك القاهرة، CIB، QNB، بنك الإسكندرية، البنك العربي الإفريقي، بنك التعمير والإسكان، مصرف أبوظبي الإسلامي، وباقي البنوك العاملة في مصر).
3. **أنواع برامج التمويل والتسهيلات الائتمانية**: (قروض شخصية بتحويل وبدون تحويل راتب، برامج أصحاب المهن الحرة والأنشطة التجارية، برامج ملاك الوحدات بالكمبوندات والعقارات، برامج أصحاب السيارات الحديثة، بطاقات الائتمان، شراء المديونيات وتوحيد الأقساط، التمويل العقاري، وتمويل المشروعات).
4. **التحليل المالي والائتماني للعملاء**: قراءة كشوف الحسابات البنكية، مفردات المرتب، تقارير الآي سكور (I-Score)، واحتساب الحد الأقصى للقسط والمبلغ التمويلي المتاح.
5. **تقديم الاستشارات الاقتصادية**: أسعار الفائدة والشهادات والتضخم وتوجيه العملاء وموظفي الشركة نحو أفضل المنتجات والحلول المصرفية المناسبة لكل حالة.

$clientContext

${progs.isNotEmpty ? "قاعدة بيانات برامج البنوك المتاحة بالنظام:\n" + progs.map((p) {
  final b = p['banks'] as Map?;
  final bName = b?['bank_name'] ?? p['bank_name'] ?? '';
  final c = p['core_programs'] as Map?;
  final pName = c?['program_name'] ?? p['program_name'] ?? '';
  final rate = p['interest_rate'] ?? '';
  final max = p['max_loan_amount'] ?? '';
  final desc = p['description'] ?? '';
  return "- بنك: $bName | برنامج: $pName | فائدة: $rate% | حد أقصى: $max ج.م | الشروط: $desc";
}).join("\n") : ""}

**تعليمات الرد وطريقة التعامل:**
- تحدث بأسلوب خبير مصرفي واقتصادي ودود، واثق، ومحترف وبلغة عربية واضحة ومنسقة باستخدام Markdown الجميل.
- إذا سألك الموظف عن أي معلومة بنكية عامة، أو سعر فائدة، أو شروط بنك معين، أو استشارة اقتصادية؛ أجب بإسهاب ودقة واحترافية.
- إذا كان هناك عميل مرفق، قم بتحليل بياناته وتوجيه الموظف لأفضل البنوك والحلول المناسبة لحالته، وحساب أقصى تمويل وقسط ممكن له، وإعطاء نصائح لرفع فرصة الموافقة الائتمانية.
- إذا قام الموظف بكتابة بيانات عميل يدويًا داخل الشات، قم بدراستها وتحليلها فوراً وإعطائه تقريراً كاملاً ومقترحاً للبنوك.
''';

    // Call Gemini API if Key is provided, else fallback to expert local assistant
    if (settings.apiKey.trim().isNotEmpty) {
      try {
        final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/${settings.model}:generateContent?key=${settings.apiKey}');

        final contents = [
          {
            'parts': [{'text': systemPrompt}]
          },
          ...chatHistory.where((m) => (m['text']?.trim().isNotEmpty ?? false)).map((msg) => {
                'role': msg['role'] == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': msg['text'] ?? ''}
                ]
              }),
          {
            'role': 'user',
            'parts': [
              {'text': userQuestion}
            ]
          }
        ];

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'contents': contents}),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final candidates = responseData['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String;
            }
          }
        }
      } catch (e) {
        _logger.e('Gemini Chat API Error: $e');
      }
    }

    // Expert built-in fallback answers if API Key not provided or offline
    await Future.delayed(const Duration(milliseconds: 500));
    final q = userQuestion.toLowerCase();

    if (client != null) {
      final clientDti = _calculateDti(client);
      double totalSalary = 0.0;
      if (client.salaryTransferMethod == 'bank_transfer') {
        for (var b in client.salaryBankDetails) {
          totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
        }
      } else {
        totalSalary = client.cashSalaryAmount ?? 0.0;
      }
      final double totalLoans = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
      final double totalCardsFive = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);
      final double totalObligations = totalLoans + totalCardsFive;
      final double maxDbrObligation = totalSalary * 0.50;
      final double remainingBudget = (maxDbrObligation - totalObligations).clamp(0, maxDbrObligation);

      if (q.contains('قسط') || q.contains('dbr') || q.contains('dti') || q.contains('مبلغ') || q.contains('تمويل') || q.contains('تحليل') || q.contains('راتب')) {
        return '''
### 📊 التحليل المالي والائتماني الشامل للعميل (${client.fullName}):
- **إجمالي الدخل الموثق:** ${totalSalary.toStringAsFixed(0)} ج.م (${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'كاش / نقدي'})
- **إجمالي الالتزامات الشهرية القائمة:** ${totalObligations.toStringAsFixed(0)} ج.م (أقساط قروض: ${totalLoans.toStringAsFixed(0)} ج.م + بطاقات وتطبيقات 5%: ${totalCardsFive.toStringAsFixed(0)} ج.م)
- **نسبة العبء الائتماني الحالية (DTI):** ${clientDti.toStringAsFixed(1)}% (الحد الأقصى للبنك المركزي 50%)
- **ميزانية القسط الشهري المتاح للتمويل الجديد (DBR Margin):** 🟢 **${remainingBudget.toStringAsFixed(0)} ج.م شهرياً**.
- **المبلغ التمويلي المتاح بالدخل الحقيقي:** يتراوح بين **${(remainingBudget * 36).toStringAsFixed(0)} ج.م** إلى **${(remainingBudget * 60).toStringAsFixed(0)} ج.م**.
${client.hasCompoundUnit ? '- **بديل الدخل (كمبوند):** مؤهل للحصول على تمويل إضافي يصل من 1.5 إلى 3.5 مليون ج.م ببرامج ملاك الكمبوندات بدون اشتراط مفردات مرتب.' : ''}
${client.hasModernCar ? '- **بديل الدخل (سيارة):** مؤهل لقرض شخصي بضمان رخصة السيارة حتى 70% من القيمة السوقية.' : ''}
''';
      }
    }

    if (q.contains('dbr') || q.contains('عبء الدين') || q.contains('المركزي') || q.contains('حساب القسط')) {
      return '''
### 📌 القواعد المصرفية الشاملة للـ DBR (نسبة عبء الدين) في البنوك المصرية:
1. **الحد الأقصى المسموح:** 50% من إجمالي الدخل المعتمد للعميل (وفقاً لتعليمات البنك المركزي المصري CBE).
2. **عناصر الالتزام الشهري:**
   - كافة أقساط القروض الشخصية والسيارات والتمويل العقاري القائمة.
   - **5%** من إجمالي الحد الائتماني لجميع البطاقات الائتمانية المسجلة في الآي سكور (سواء كانت مستخدمة بالكامل أو غير مستخدمة).
   - أقساط تطبيقات التمويل الاستهلاكي (Valu, Sympl, Shahry, Aman, Contact, Forsa).
3. **معادلة حساب القسط التمويلي الجديد المتاح:**
   `المتاح = (الدخل الشهري × 50%) - إجمالي الأقساط الحالية - (5% من حدود البطاقات)`
''';
    } else if (q.contains('كمبوند') || q.contains('عقار') || q.contains('وحدة') || q.contains('ملاك')) {
      return '''
### 🏡 برامج ملاك الوحدات بالكمبوندات والعقارات (بديل الدخل الافتراضي):
تتيح كبرى البنوك المصرية (الأهلي، مصر، القاهرة، CIB، العربي الأفريقي، التعمير والإسكان، QNB) برامج تمويل بضمان ملكية عقار أو وحدة في كمبوند معتمد:
- **المميزات:** مبالغ تمويل تصل من **1,000,000 ج.م** إلى **5,000,000 ج.م** بدون اشتراط تحويل راتب أو مفردات مرتب تقليدية.
- **الشروط الأساسية:**
  1. عقد الوحدة (ابتدائي أو نهائي) مسجل باسم العميل.
  2. إيصالات سداد الأقساط تثبت سداد **20% فأكثر** من القيمة الإجمالية للوحدة.
  3. مرور **6 أشهر على الأقل** على تاريخ التعاقد والسداد المنتظم.
  4. كشف حساب بنكي يوضح حركة السداد أو المعاملات المالية.
''';
    } else if (q.contains('سيارة') || q.contains('سيارات') || q.contains('رخصة') || q.contains('مركبات')) {
      return '''
### 🚗 برامج أصحاب السيارات الحديثة (بديل الدخل):
- **فكرة البرنامج:** منح قرض شخصي بضمان رخصة سيارة حديثة يمتلكها العميل بدون حظر بيع في بعض البنوك أو برهن رسمي.
- **الشروط:** سيارة ملاكي حديثة (موديل آخر 3 إلى 5 سنوات) باسم العميل سارية الترخيص.
- **قيمة التمويل:** تمنح البنوك من **50% إلى 75%** من القيمة السوقية التقديرية للسيارة (تصل من 300,000 إلى 1,000,000 ج.م).
- **المستندات المطلوبة:** أصل وصورة رخصة السيارة + بطاقة الرقم القومي + كشف حساب بنكي 6 أشهر.
''';
    } else if (q.contains('شهادة') || q.contains('شهادات') || q.contains('وديعة') || q.contains('ودائع') || q.contains('توفير')) {
      return '''
### 💰 برامج التمويل بضمان الشهادات والودائع الادخارية:
- **المميزات:** أسرع موافقة ائتمانية (تصدر خلال 24-48 ساعة) وبأقل سعر فائدة (عادة فائدة الشهادة + 2% إلى 3%).
- **نسبة التمويل:** تصل إلى **80% - 90%** من القيمة الاسمية للشهادات أو الودائع.
- **أصل الوعاء الادخاري:** يظل كما هو ويستمر العميل في صرف العائد الشهري / الربع سنوي للشهادة بانتظام.
''';
    } else if (q.contains('تطبيق') || q.contains('تطبيقات') || q.contains('valu') || q.contains('shahry') || q.contains('sympl') || q.contains('أمان')) {
      return '''
### 📱 برامج تطبيقات التمويل الاستهلاكي والـ FinTech كبديل للدخل:
- البنوك وشركات التمويل تعتمد سجل سداد تطبيقات مثل (Valu, Aman, Contact, Shahry, Sympl, Forsa) كإثبات للجدارة الائتمانية والانتظام المالي.
- **أثرها على الـ DBR:** أقساط التطبيقات أو 5% من حدودها تُحتسب كالتزام شهري يخصم من ميزانية الـ DBR.
- **الاستفادة منها:** العميل الذي يملك حسابات نشطة وسداداً منتظماً تزيد فرصة قبوله في البرامج المفتوحة والبطاقات الائتمانية.
''';
    } else if (q.contains('i-score') || q.contains('اي سكور') || q.contains('تقرير ائتماني') || q.contains('تقييم')) {
      return '''
### 📈 درجات تقييم الآي سكور (I-Score) ودلالتها الائتمانية:
- **700 إلى 850 نقطة (ممتاز 🟢):** موافقة فورية، أعلى مبالغ تمويل، وأقل أسعار فائدة ومصاريف إدارية.
- **600 إلى 699 نقطة (جيد 🟡):** موافقة ائتمانية طبيعية مع مراجعة دقيقة لنسبة عبء الدين.
- **أقل من 600 نقطة (منخفض 🔴):** صعوبة في منح تمويل جديد، ويلزم تسوية المتأخرات وإغلاق بعض البطاقات لرفع التقييم.
''';
    }

    return '''
مرحباً بك! أنا **المستشار المالي والاقتصادي الذكي الشامل لـ The Future Club**. 🏦🇪🇬

أنا ملم بجميع أنظمة وبرامج البنوك المصرية:
1. **برامج الدخل الحقيقي:** تحويل رواتب حكومية وخاصة، مهن حرة، وسجلات تجارية.
2. **برامج الدخل الافتراضي (بدائل الدخل):** ملاك كمبوندات، سيارات حديثة، شهادات وودائع، وبطاقات ائتمانية.
3. **حسابات الـ DBR والـ DTI:** حساب أقصى قسط ومبلغ تمويلي متاح وفقاً لضوابط البنك المركزي بدقة.

*تفضل بطرح أي سؤال أو كتابة تفاصيل أي عميل وسأقوم بتحليله وتوجيهك فوراً.*
''';
  }

  return chatWithAi;
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

    int matchScore = 50;
    final List<String> reasons = [];

    final descLower = description.toLowerCase();
    final progLower = programName.toLowerCase();

    // 1. DBR & Remaining Installment Budget Match
    if (clientDti >= 50.0) {
      matchScore -= 50;
      reasons.add("⚠️ العبء الائتماني (DTI) وصل للحد الأقصى (50%) — التوصية بدمج الديون أو تسوية البطاقات.");
    } else {
      matchScore += 20;
      reasons.add("هامش الـ DBR المتبقي يسمح بقسط شهري حتى (${remainingAvailableInstallmentBudget.toStringAsFixed(0)} ج.م).");
    }

    // 2. Requested Amount Match
    if (client.requestedAmount <= maxAmount) {
      matchScore += 15;
      reasons.add("المبلغ المطلوب (${client.requestedAmount.toStringAsFixed(0)} ج.م) يقع ضمن الحد الأقصى للبرنامج (${maxAmount.toStringAsFixed(0)} ج.م).");
    } else {
      matchScore -= 20;
      reasons.add("المبلغ المطلوب يتجاوز سقف التمويل للبرنامج.");
    }

    // 3. Alternative Income & Assets Match (الكمبوند، السيارات، الشهادات)
    if (client.hasCompoundUnit && (descLower.contains('كمبوند') || descLower.contains('عقار') || descLower.contains('ملاك') || progLower.contains('كمبوند') || progLower.contains('عقاري'))) {
      matchScore += 50;
      reasons.add("🎯 مؤهل كـ (دخل افتراضي): يملك وحدة في كمبوند مما يتيح التمويل بضمان عقود وإيصالات الكمبوند بدون مفردات مرتب.");
    }

    if (client.hasModernCar && (descLower.contains('سيارة') || descLower.contains('سيارات') || descLower.contains('مركبات') || progLower.contains('سيارات') || progLower.contains('سيارة'))) {
      matchScore += 45;
      reasons.add("🎯 مؤهل كـ (دخل افتراضي): يملك سيارة حديثة مما يتيح التمويل بضمان رخصة السيارة بنسبة تصل 70% من قيمتها.");
    }

    // 4. Employment Type & Insurance Match
    if (client.employmentType == 'government_sector' || (client.employmentType == 'private_sector' && client.isInsured)) {
      if (descLower.contains('تحويل') || descLower.contains('موظف') || progLower.contains('شخصي') || progLower.contains('موظف')) {
        matchScore += 30;
        reasons.add("العميل قطاع عمل موثق ومؤمن عليه ومؤهل لبرامج التمويل الشخصي بتحويل / إثبات راتب.");
      }
    } else if (client.employmentType == 'freelance' || !client.isInsured) {
      if (descLower.contains('أعمال حرة') || descLower.contains('مهن حرة') || descLower.contains('بدون إثبات') || descLower.contains('سجل تجاري') || descLower.contains('بديل')) {
        matchScore += 40;
        reasons.add("البرنامج مخصص للمهن الحرة وبدائل الدخل بمرونة ائتمانية عالية.");
      } else if (descLower.contains('تحويل راتب')) {
        matchScore -= 30;
      }
    }

    // 5. Salary Transfer Method
    if (client.salaryTransferMethod == 'bank_transfer') {
      matchScore += 10;
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

  // Generate Comprehensive Analytical Report Markdown
  final dtiColor = clientDti >= 50 ? '🔴' : (clientDti >= 40 ? '🟡' : '🟢');
  final scoreColor = client.creditScore >= 700 ? '🟢' : (client.creditScore >= 600 ? '🟡' : '🔴');
  
  final buffer = StringBuffer();
  buffer.writeln('# 📋 تقرير التحليل الائتماني والتقييم المالي الشامل');
  buffer.writeln('**تاريخ الفحص:** ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}');
  buffer.writeln('**اسم العميل:** ${client.fullName} | **المحافظة:** ${client.governorate}');
  buffer.writeln('**جهة العمل:** ${client.companyName ?? "غير محدد"} (${client.jobTitle ?? "غير محدد"})');
  buffer.writeln('\n---');
  
  buffer.writeln('## 📊 أولاً: تحليل الدخل الحقيقي ومؤشرات الـ DBR والالتزامات');
  buffer.writeln('* **طبيعة الوظيفة والقطاع:** ${client.employmentType == 'government_sector' ? 'قطاع حكومي' : (client.employmentType == 'private_sector' ? 'قطاع خاص' : 'أعمال حرة')} (${client.isInsured ? "مؤمن عليه" : "غير مؤمن عليه"}).');
  buffer.writeln('* **إجمالي الراتب الموثق:** ${totalSalary.toStringAsFixed(0)} ج.م (${client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'كاش / نقدي'}).');
  buffer.writeln('* **التقييم الائتماني (I-Score):** $scoreColor **${client.creditScore}** نقطة.');
  buffer.writeln('* **إجمالي الالتزامات الشهرية القائمة:** ${totalMonthlyObligations.toStringAsFixed(0)} ج.م (أقساط قروض: ${totalExistingLoansInstallments.toStringAsFixed(0)} ج.م + استقطاع 5% بطاقات وتطبيقات: ${totalCardsFivePercentCalc.toStringAsFixed(0)} ج.م).');
  buffer.writeln('* **نسبة العبء الائتماني الحالية (DTI):** $dtiColor **${clientDti.toStringAsFixed(1)}%** من أصل الحد الأقصى 50%.');
  buffer.writeln('* **المتبقي المتاح من الـ DBR:** **${remainingDbrMarginPercent.toStringAsFixed(1)}%**.');
  buffer.writeln('* **ميزانية القسط الشهري المتاح للتمويل الجديد:** 🟢 **${remainingAvailableInstallmentBudget.toStringAsFixed(0)} ج.م / شهرياً**.');
  
  buffer.writeln('\n---');
  buffer.writeln('## 🏡🚗 ثانياً: تحليل مصادر الدخل الافتراضي (بدائل الدخل والأصول)');
  if (client.hasCompoundUnit) {
    buffer.writeln('* **وحدة في كمبوند / عقار:** ✅ متوفر (${client.compoundUnitsData.isNotEmpty ? client.compoundUnitsData.map((u) => u['compound_name'] ?? 'كمبوند').join('، ') : "مسجل بالملف"}) — يُتيح احتساب دخل افتراضي والتقديم في برامج ملاك العقارات والكمبوندات بدون اشتراط مفردات مرتب.');
  } else {
    buffer.writeln('* **وحدة في كمبوند:** ❌ غير متوفر.');
  }

  if (client.hasModernCar) {
    buffer.writeln('* **سيارة حديثة:** ✅ متوفر (${client.modernCarsData.isNotEmpty ? client.modernCarsData.map((c) => "${c['car_brand'] ?? ''} ${c['car_model'] ?? ''}").join('، ') : "مسجل بالملف"}) — يتيح تمويلاً بضمان رخصة السيارة.');
  } else {
    buffer.writeln('* **سيارة حديثة:** ❌ غير متوفر.');
  }

  if (client.creditCardsRequests.isNotEmpty) {
    buffer.writeln('* **بطاقات وتطبيقات تمويلية:** متوفر عدد (${client.creditCardsRequests.length}) بطاقة / تطبيق — تدعم احتساب السلوك الائتماني المنتظم كبديل دخل.');
  }

  buffer.writeln('\n---');
  buffer.writeln('## 💡 ثالثاً: البرامج الائتمانية للبنوك الموصى بها (دخل حقيقي وافتراضي)');
  if (matchingReasons.isEmpty) {
    buffer.writeln('⚠️ لم نجد برامج تتوافق مع بيانات العميل الائتمانية بشكل كامل حالياً. يرجى مراجعة معايير المطابقة في الإعدادات أو إضافة برامج جديدة بقاعدة البيانات.');
  } else {
    buffer.writeln('بناءً على معايير المطابقة المتقدمة والبيانات الكاملة للعميل، تم ترشيح أفضل البرامج التالية لضمان الحصول على أعلى نسبة موافقة ائتمانية:');
    buffer.writeln('');
    for (var reason in matchingReasons) {
      buffer.writeln(reason);
    }
  }

  buffer.writeln('\n---');
  buffer.writeln('## 🛠️ رابعاً: توصيات استشاري التمويل والخطوات اللاحقة');
  buffer.writeln('1. **تجهيز كشف الحساب**: تجهيز كشف حساب بنكي رسمي مختوم لآخر 6 أشهر يوضح الحركة المالية.');
  if (clientDti > 45) {
    buffer.writeln('2. **تخفيض نسبة الـ DTI**: ينصح العميل بسداد إحدى المديونيات القائمة أو غلق بعض بطاقات الائتمان غير المستخدمة لخفض نسبة العبء الائتماني من أجل رفع فرصة الموافقة على القرض الجديد.');
  }
  if (client.creditScore < 600) {
    buffer.writeln('3. **تحسين الـ I-Score**: يلزم مراجعة التقرير الائتماني والتأكد من عدم وجود متأخرات قائمة، وسداد أي مبالغ مستحقة فورا.');
  }
  if (client.hasCompoundUnit) {
    buffer.writeln('4. **مستندات الكمبوند**: استخراج إيصالات سداد الأقساط من شركة التطوير العقاري وعقد الوحدة للتقديم على برنامج ملاك الكمبوندات.');
  }
  if (client.hasModernCar) {
    buffer.writeln('5. **مستندات السيارة**: التأكد من سريان رخصة السيارة واستخراج شهادة بيانات موجهة للبنك.');
  }
  buffer.writeln('6. **مستندات العمل**: استخراج شهادة راتب (مفردات مرتب) حديثة موجهة للبنك المطلوب والتأكد من تطابق المسمى الوظيفي.');
  
  buffer.writeln('\n*💡 ملاحظة: هذا التقرير صادر من محرك التحليل الائتماني الذكي لـ The Future Club معتمداً على مؤشرات الدخل الحقيقي والافتراضي.*');

  return AiAnalysisResult(
    reportMarkdown: buffer.toString(),
    recommendedProgramIds: recommendedIds,
  );
}
