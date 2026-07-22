import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/client_model.dart';

class ClientPdfGenerator {
  static Future<Uint8List> generateClientPdf(ClientModel client) async {
    final pdf = pw.Document();

    // Load custom Arabic font for PDF rendering
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // Calculate totals
    double totalSalary = 0.0;
    if (client.salaryTransferMethod == 'bank_transfer') {
      for (var b in client.salaryBankDetails) {
        totalSalary += double.tryParse(b['amount'] ?? '0') ?? 0.0;
      }
    } else {
      totalSalary = client.cashSalaryAmount ?? 0.0;
    }

    double totalLoansInstallments = client.existingLoans.fold(0.0, (prev, l) => prev + l.installmentValue);
    double totalCardsFivePercent = client.creditCardsRequests.fold(0.0, (prev, c) => prev + c.fivePercentCalc);
    double totalMonthlyObligations = totalLoansInstallments + totalCardsFivePercent;
    double dtiPercent = totalSalary > 0 ? (totalMonthlyObligations / totalSalary) * 100 : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            // Header Title
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey900,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'The Future Club - تقرير الملف الائتماني والمالي',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'مستند رسمي مخصص للمشاركة والمطابقة البنكية',
                    style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // 1. SECTION: Personal & Employment Details (EXCLUDING Phone, Rep, I-Score, Requested Amount)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('👤 البيانات الشخصية والوظيفية', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildPdfInfoTile('الاسم الكامل', client.fullName),
                      _buildPdfInfoTile('الرقم القومي', client.nationalId),
                      _buildPdfInfoTile('تاريخ الميلاد', client.birthDate),
                      _buildPdfInfoTile('القطاع الوظيفي', client.employmentType == 'government_sector' ? 'قطاع حكومي' : (client.employmentType == 'private_sector' ? 'قطاع خاص' : 'أعمال حرة')),
                      _buildPdfInfoTile('جهة العمل / الشركة', client.companyName ?? 'غير محدد'),
                      _buildPdfInfoTile('المسمى الوظيفي', client.jobTitle ?? 'غير محدد'),
                      _buildPdfInfoTile('التأمينات الاجتماعية', client.isInsured ? 'مؤمن عليه' : 'غير مؤمن عليه'),
                      _buildPdfInfoTile('طريقة استلام الراتب', client.salaryTransferMethod == 'bank_transfer' ? 'تحويل بنكي' : 'نقدي / كاش'),
                      _buildPdfInfoTile('المحافظة', client.governorate),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 2. SECTION: Complete Tables for Loans & Credit Cards
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('💳 تفاصيل القروض والبطاقات المصرفية', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 6),

                  // Existing Loans Complete Table
                  pw.Text('• القروض القائمة (${client.existingLoans.length}):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  client.existingLoans.isEmpty
                      ? pw.Text('لا توجد قروض قائمة مسجلة.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
                      : pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                          cellStyle: const pw.TextStyle(fontSize: 9),
                          cellPadding: const pw.EdgeInsets.all(5),
                          headers: ['م', 'البنك / الجهة', 'قيمة القسط الشهري', 'ملاحظات وتفاصيل'],
                          data: List.generate(client.existingLoans.length, (index) {
                            final l = client.existingLoans[index];
                            return [
                              '${index + 1}',
                              l.bankName,
                              '${l.installmentValue.toStringAsFixed(0)} ج.م',
                              (l.notes != null && l.notes!.isNotEmpty) ? l.notes! : '-',
                            ];
                          }),
                        ),
                  pw.SizedBox(height: 12),

                  // Credit Cards Complete Table
                  pw.Text('• بطاقات الائتمان والطلبات (${client.creditCardsRequests.length}):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  client.creditCardsRequests.isEmpty
                      ? pw.Text('لا توجد بطاقات ائتمان مسجلة.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
                      : pw.TableHelper.fromTextArray(
                          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
                          cellStyle: const pw.TextStyle(fontSize: 9),
                          cellPadding: const pw.EdgeInsets.all(5),
                          headers: ['م', 'البنك / الجهة', 'نوع البند', 'الحد الائتماني / القيمة', 'استقطاع الـ DTI (5%)'],
                          data: List.generate(client.creditCardsRequests.length, (index) {
                            final c = client.creditCardsRequests[index];
                            return [
                              '${index + 1}',
                              c.bankName,
                              c.type == 'card' ? 'بطاقة قائمة' : 'طلب جديد',
                              '${c.value.toStringAsFixed(0)} ج.م',
                              '${c.fivePercentCalc.toStringAsFixed(0)} ج.م',
                            ];
                          }),
                        ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 3. SECTION: Financial Obligations Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('📊 ملخص الالتزامات الائتمانية والعبء المالي', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Divider(color: PdfColors.grey400),
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _buildPdfInfoTile('إجمالي الراتب الشهر الموثق', '${totalSalary.toStringAsFixed(0)} ج.م'),
                      _buildPdfInfoTile('إجمالي أقساط القروض', '${totalLoansInstallments.toStringAsFixed(0)} ج.م'),
                      _buildPdfInfoTile('إجمالي استقطاع البطاقات (5%)', '${totalCardsFivePercent.toStringAsFixed(0)} ج.م'),
                      _buildPdfInfoTile('إجمالي الالتزامات الشهرية القائمة', '${totalMonthlyObligations.toStringAsFixed(0)} ج.م'),
                      _buildPdfInfoTile('نسبة العبء الائتماني (DTI)', '${dtiPercent.toStringAsFixed(1)}%'),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // 4. SECTION: Uploaded Documents List (EXCLUDING document status)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('📁 المستندات والوثائق المرفقة', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Divider(color: PdfColors.grey300),
                  pw.SizedBox(height: 6),
                  client.documents.isEmpty
                      ? pw.Text('لم يتم رفع مستندات حتى الآن.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
                      : pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: client.documents.map((d) {
                            return pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(vertical: 2),
                              child: pw.Text('• ${d.documentName}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfInfoTile(String title, String value) {
    return pw.Container(
      width: 220,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Text('$title: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.black)),
        ],
      ),
    );
  }

  // Trigger cross-platform share across apps (WhatsApp, Messenger, Instagram, Email, etc.)
  static Future<void> shareClientPdf(ClientModel client) async {
    final pdfBytes = await generateClientPdf(client);
    final String filename = 'Client_Profile_${client.fullName.replaceAll(' ', '_')}.pdf';

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: filename,
      subject: 'تقرير ملف العميل الائتماني: ${client.fullName}',
    );
  }
}
