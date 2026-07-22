import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/interactive_hover_card.dart';
import 'estimated_credit_calculator_widget.dart';

/// Standalone Credit Calculator Screen
/// Accessible from the main navigation as an independent section.
class CreditCalculatorScreen extends StatelessWidget {
  const CreditCalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 40 : (isTablet ? 24 : 16),
          vertical: isDesktop ? 30 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            InteractiveHoverCard(
              glowColor: Colors.amberAccent,
              backgroundColor: const Color(0xFF1E1E38).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.all(20),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.3),
                          Colors.orange.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.calculate_rounded,
                      color: Colors.amberAccent,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      textDirection: TextDirection.rtl,
                      children: [
                        const Text(
                          "حاسبة الدخل الائتماني الافتراضي 🧮",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.amberAccent,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "أداة مستقلة لحساب القدرة الائتمانية التقديرية بناءً على بيانات افتراضية غير مسجلة في النظام",
                          style: TextStyle(
                            color: TfcColors.outline.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Info Chips
            Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildInfoChip(
                    icon: Icons.info_outline,
                    label: "بيانات افتراضية فقط",
                    color: Colors.cyanAccent,
                  ),
                  _buildInfoChip(
                    icon: Icons.save_outlined,
                    label: "لا يتم حفظ البيانات",
                    color: Colors.orangeAccent,
                  ),
                  _buildInfoChip(
                    icon: Icons.speed_rounded,
                    label: "حساب فوري تلقائي",
                    color: Colors.greenAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Calculator Widget (The main calculator)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 700 : double.infinity,
              ),
              child: const EstimatedCreditCalculatorWidget(),
            ),
            const SizedBox(height: 30),

            // Usage Guide Section
            InteractiveHoverCard(
              glowColor: Colors.cyanAccent,
              backgroundColor: const Color(0xFF1E1E38).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Icon(Icons.help_outline_rounded,
                          color: Colors.cyanAccent, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "دليل الاستخدام",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.cyanAccent,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep("1",
                      "أدخل صافي الراتب الشهري للعميل المحتمل"),
                  _buildGuideStep("2",
                      "أضف أقساط القروض القائمة (إن وُجدت) باستخدام زر إضافة قسط"),
                  _buildGuideStep("3",
                      "أضف البطاقات الائتمانية مع الليميت والقسط - سيتم حساب 5% تلقائياً"),
                  _buildGuideStep("4",
                      "اضبط حد عبء الدين المستهدف (DTI Cap) باستخدام شريط التمرير"),
                  _buildGuideStep("5",
                      "اطلع على الملخص: الالتزامات، نسبة DTI، والدخل الائتماني المتاح"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep(String number, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.amberAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
        ],
      ),
    );
  }
}
