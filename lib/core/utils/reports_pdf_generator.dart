import 'dart:typed_data';
import 'package:intl/intl.dart' as intl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsPdfGenerator {
  static pw.Font? _cairoFont;
  static pw.Font? _cairoBoldFont;

  static Future<void> _loadFonts() async {
    _cairoFont ??= await PdfGoogleFonts.cairoMedium();
    _cairoBoldFont ??= await PdfGoogleFonts.cairoBold();
  }

  static String _formatNumber(double amount) {
    return intl.NumberFormat('#,##0.##').format(amount);
  }

  static pw.Widget _buildHeader(String reportTitle, String periodLabel, pw.Font font, pw.Font boldFont) {
    final now = DateTime.now();
    final dateStr = "${now.day}/${now.month}/${now.year}";

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      margin: const pw.EdgeInsets.only(bottom: 20),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFF16162A),
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFD4AF37), width: 1.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'THE FUTURE CLUB (TFC)',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 16,
                  color: const PdfColor.fromInt(0xFFD4AF37),
                ),
              ),
              pw.Text(
                'نظام إدارة علاقات العملاء والوساطة المالية والائتمانية',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey300),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'تاريخ إصدار التقرير: $dateStr',
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey400),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                reportTitle,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 15,
                  color: PdfColors.white,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const pw.EdgeInsets.only(top: 4),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFF6C5CE7),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  'الفترة: $periodLabel',
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: boldFont, fontSize: 9, color: PdfColors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. تقرير المحاسبة والماليات PDF
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateFinancialReportPdf({
    required String periodLabel,
    required double totalInvoicesFees,
    required double collectedFees,
    required double uncollectedFees,
    required double totalExpenses,
    required double netProfit,
    required int operationsCount,
    required List<Map<String, dynamic>> operationsList,
    required List<Map<String, dynamic>> expensesList,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final font = _cairoFont!;
    final boldFont = _cairoBoldFont!;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader("📊 التقرير المالي والمحاسبي للشركة", periodLabel, font, boldFont),

          // Summary KPI Cards
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            margin: const pw.EdgeInsets.only(bottom: 16),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiBox("إجمالي الأتعاب", "${_formatNumber(totalInvoicesFees)} ج.م", PdfColors.blue800, font, boldFont),
                _buildKpiBox("المحصل الفعلي", "${_formatNumber(collectedFees)} ج.م", PdfColors.green800, font, boldFont),
                _buildKpiBox("غير المحصل", "${_formatNumber(uncollectedFees)} ج.م", PdfColors.orange800, font, boldFont),
                _buildKpiBox("إجمالي المصروفات", "${_formatNumber(totalExpenses)} ج.م", PdfColors.red800, font, boldFont),
                _buildKpiBox("صافي الأرباح", "${_formatNumber(netProfit)} ج.م", netProfit >= 0 ? PdfColors.green800 : PdfColors.red800, font, boldFont),
              ],
            ),
          ),

          // Section 1: Invoices and Revenues
          pw.Text("💳 تفاصيل فواتير وعمليات التمويل الناجحة ($operationsCount عملية)", 
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          operationsList.isEmpty
              ? pw.Text("لا توجد فواتير أو عمليات منفذة في هذه الفترة.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
              : pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E1E38)),
                  cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                  headers: ['الحالة', 'التحصيل', 'الأتعاب', 'النسبة', 'المبلغ المعتمد', 'البنك', 'العميل'],
                  data: operationsList.map((op) => [
                    op['status'] == 'approved' ? 'موافق عليه' : op['status'],
                    op['collected'] == 'collected' ? 'تم التحصيل' : 'مستحق',
                    "${_formatNumber(op['fees'] ?? 0)} ج.م",
                    "${op['percentage'] ?? 0}%",
                    "${_formatNumber(op['approved_amount'] ?? 0)} ج.م",
                    op['bank'] ?? '—',
                    op['client'] ?? '—',
                  ]).toList(),
                ),

          pw.SizedBox(height: 16),

          // Section 2: Expenses
          pw.Text("💸 تفاصيل المصروفات التشغيلية والعمومية (${expensesList.length} بند)", 
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          expensesList.isEmpty
              ? pw.Text("لا توجد مصروفات مسجلة في هذه الفترة.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
              : pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF374151)),
                  cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                  headers: ['ملاحظات', 'التاريخ', 'القيمة', 'بند المصروف'],
                  data: expensesList.map((exp) => [
                    exp['notes'] ?? '—',
                    exp['date'] ?? '—',
                    "${_formatNumber(exp['amount'] ?? 0)} ج.م",
                    exp['title'] ?? '—',
                  ]).toList(),
                ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. تقرير الموظفين وفرق العمل وتارجت المبيعات PDF
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateEmployeesReportPdf({
    required String periodLabel,
    required List<Map<String, dynamic>> employeeStats,
    required List<Map<String, dynamic>> teamStats,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final font = _cairoFont!;
    final boldFont = _cairoBoldFont!;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader("👥 تقرير أداء الموظفين والتارجت ومقارنة الفرق", periodLabel, font, boldFont),

          // Team summary if available
          if (teamStats.isNotEmpty) ...[
            pw.Text("🏆 مقارنة أداء فرق العمل والمجموعات", 
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF4C1D95)),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              cellAlignment: pw.Alignment.center,
              headers: ['نسبة الإنجاز', 'المحقق الكلي', 'التارجت الكلي', 'عدد الأعضاء', 'قائد الفريق / المشرف', 'الفريق'],
              data: teamStats.map((t) => [
                "${(t['achievement_rate'] as double).toStringAsFixed(1)}%",
                "${_formatNumber(t['total_achieved'] ?? 0)} ج.م",
                "${_formatNumber(t['total_target'] ?? 0)} ج.م",
                "${t['members_count']}",
                t['leader_name'] ?? '—',
                t['team_name'] ?? '—',
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Individual Employee Performance
          pw.Text("👤 تقييم وتصنيف أداء الموظفين الفردي (${employeeStats.length} موظف)", 
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 6),
          employeeStats.isEmpty
              ? pw.Text("لا توجد بيانات موظفين مسجلة في هذه الفترة.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
              : pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 8, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E1E38)),
                  cellStyle: pw.TextStyle(font: font, fontSize: 8),
                  cellAlignment: pw.Alignment.center,
                  headers: ['نسبة الإنجاز', 'المبيعات المنفذة', 'التارجت المستهدف', 'العمليات الناجحة', 'العملاء المسجلين', 'الدور / الفريق', 'اسم الموظف'],
                  data: employeeStats.map((e) => [
                    "${(e['achievement_rate'] as double).toStringAsFixed(1)}%",
                    "${_formatNumber(e['achieved_amount'] ?? 0)} ج.م",
                    "${_formatNumber(e['target_amount'] ?? 0)} ج.م",
                    "${e['operations_count']}",
                    "${e['clients_count']}",
                    e['role_or_team'] ?? '—',
                    e['name'] ?? '—',
                  ]).toList(),
                ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. تقرير أداء البنوك والموظفين الأكثر تعاملاً PDF
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateBanksReportPdf({
    required String periodLabel,
    required List<Map<String, dynamic>> bankStats,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final font = _cairoFont!;
    final boldFont = _cairoBoldFont!;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader("🏦 تقرير أداء البنوك الشامل (توزيعات + عمليات)", periodLabel, font, boldFont),

          pw.Text("🏛️ مؤشرات أداء البنوك وحجم التمويلات (${bankStats.length} بنك)",
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 8),

          bankStats.isEmpty
              ? pw.Text("لا توجد توزيعات أو عمليات مسجلة بالبنوك في هذه الفترة.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
              : pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F766E)),
                  cellStyle: pw.TextStyle(font: font, fontSize: 7),
                  cellAlignment: pw.Alignment.center,
                  headers: [
                    'اسم البنك',
                    'عملاء التوزيع',
                    'قبول التوزيع',
                    'نسبة قبول التوزيع',
                    'عملاء العمليات',
                    'موافقة العمليات',
                    'نسبة قبول العمليات',
                    'إجمالي التمويل المعتمد',
                    'أكثر موظف بنكي',
                  ],
                  data: bankStats.map((b) => [
                    b['bank_name'] ?? '—',
                    "${b['total_dists_count']}",
                    "${b['accepted_dists_count']}",
                    "${(b['dist_acceptance_rate'] as double).toStringAsFixed(1)}%",
                    "${b['total_ops_count']}",
                    "${b['approved_ops_count']}",
                    "${(b['ops_approval_rate'] as double).toStringAsFixed(1)}%",
                    "${_formatNumber(b['total_approved_amount'] ?? 0)} ج.م",
                    b['top_bank_employee'] ?? '—',
                  ]).toList(),
                ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 4. تقرير البرامج التمويلية ونسب الاستخدام حسب البنك PDF
  // ─────────────────────────────────────────────────────────────────────────────
  static Future<Uint8List> generateProgramsReportPdf({
    required String periodLabel,
    required List<Map<String, dynamic>> programStats,
  }) async {
    await _loadFonts();
    final pdf = pw.Document();
    final font = _cairoFont!;
    final boldFont = _cairoBoldFont!;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader("📈 تقرير البرامج التمويلية الأكثر طلباً ونسب الاستخدام", periodLabel, font, boldFont),

          pw.Text("🏷️ تفاصيل استهلاك وتوزيع البرامج الائتمانية والتمويلية (${programStats.length} برنامج)", 
            textDirection: pw.TextDirection.rtl,
            style: pw.TextStyle(fontSize: 12, font: boldFont, color: PdfColors.blueGrey900),
          ),
          pw.SizedBox(height: 8),

          programStats.isEmpty
              ? pw.Text("لا توجد بيانات برامج منفذة في هذه الفترة.", textDirection: pw.TextDirection.rtl, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
              : pw.TableHelper.fromTextArray(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 7, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
                  cellStyle: pw.TextStyle(font: font, fontSize: 7),
                  cellAlignment: pw.Alignment.center,
                  headers: [
                    'اسم البرنامج',
                    'عملاء التوزيع',
                    'قبول التوزيع',
                    'نسبة قبول التوزيع',
                    'العمليات المنفذة',
                    'موافقة العمليات',
                    'نسبة موافقة العمليات',
                    'إجمالي مبالغ التمويل',
                    'توزيع الاستخدام على البنوك',
                  ],
                  data: programStats.map((p) => [
                    p['program_name'] ?? '—',
                    "${p['total_dists']}",
                    "${p['accepted_dists']}",
                    "${(p['dist_acceptance_rate'] as double).toStringAsFixed(1)}%",
                    "${p['total_ops']}",
                    "${p['approved_ops']}",
                    "${(p['ops_approval_rate'] as double).toStringAsFixed(1)}%",
                    "${_formatNumber(p['total_amount'] ?? 0)} ج.م",
                    p['banks_distribution'] ?? '—',
                  ]).toList(),
                ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiBox(String label, String value, PdfColor color, pw.Font font, pw.Font boldFont) {
    return pw.Column(
      children: [
        pw.Text(label, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(value, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: boldFont, fontSize: 9, color: color)),
      ],
    );
  }
}
