import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/interactive_hover_card.dart';

/// Interactive Default Credit Calculator Widget for Clients
class EstimatedCreditCalculatorWidget extends StatefulWidget {
  const EstimatedCreditCalculatorWidget({super.key});

  @override
  State<EstimatedCreditCalculatorWidget> createState() =>
      _EstimatedCreditCalculatorWidgetState();
}

class _EstimatedCreditCalculatorWidgetState
    extends State<EstimatedCreditCalculatorWidget> {
  final _salaryController = TextEditingController();

  // Loans list
  final List<TextEditingController> _loanInstallmentControllers = [];

  // Credit Cards list: limit & installment
  final List<Map<String, TextEditingController>> _cardControllers = [];

  // DTI Cap Target percentage (default 50%)
  double _maxDtiPercent = 50.0;

  @override
  void dispose() {
    _salaryController.dispose();
    for (var c in _loanInstallmentControllers) {
      c.dispose();
    }
    for (var card in _cardControllers) {
      card['limit']?.dispose();
      card['installment']?.dispose();
    }
    super.dispose();
  }

  void _addLoanRow() {
    setState(() {
      _loanInstallmentControllers.add(TextEditingController());
    });
  }

  void _removeLoanRow(int index) {
    setState(() {
      _loanInstallmentControllers[index].dispose();
      _loanInstallmentControllers.removeAt(index);
    });
  }

  void _addCardRow() {
    setState(() {
      _cardControllers.add({
        'limit': TextEditingController(),
        'installment': TextEditingController(),
      });
    });
  }

  void _removeCardRow(int index) {
    setState(() {
      _cardControllers[index]['limit']?.dispose();
      _cardControllers[index]['installment']?.dispose();
      _cardControllers.removeAt(index);
    });
  }

  void _resetAll() {
    setState(() {
      _salaryController.clear();
      for (var c in _loanInstallmentControllers) {
        c.dispose();
      }
      _loanInstallmentControllers.clear();
      for (var card in _cardControllers) {
        card['limit']?.dispose();
        card['installment']?.dispose();
      }
      _cardControllers.clear();
    });
  }

  String _formatNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Salary
    final double salary = double.tryParse(_salaryController.text) ?? 0.0;

    // 2. Calculate Loans total installments
    double totalLoansInstallments = 0.0;
    for (var ctrl in _loanInstallmentControllers) {
      totalLoansInstallments += double.tryParse(ctrl.text) ?? 0.0;
    }

    // 3. Calculate Cards total limit, 5% obligation, and manual installments
    double totalCardsLimit = 0.0;
    double totalCardsFivePercent = 0.0;
    double totalCardsManualInstallments = 0.0;

    for (var card in _cardControllers) {
      final double limit = double.tryParse(card['limit']?.text ?? '') ?? 0.0;
      final double inst =
          double.tryParse(card['installment']?.text ?? '') ?? 0.0;

      totalCardsLimit += limit;
      totalCardsFivePercent += (limit * 0.05);
      totalCardsManualInstallments += inst;
    }

    // Total Monthly Obligations (Loans Installments + 5% of Credit Cards limit)
    final double totalObligations =
        totalLoansInstallments + totalCardsFivePercent;

    // Current DTI %
    final double currentDti =
        salary > 0 ? (totalObligations / salary) * 100 : 0.0;

    // Allowed Max Monthly Obligation Capacity based on DTI Target Cap
    final double maxAllowedObligation = salary * (_maxDtiPercent / 100.0);

    // Available Monthly Installment Capacity for New Loan
    final double availableMonthlyMargin =
        (maxAllowedObligation - totalObligations).clamp(0.0, double.infinity);

    // Estimated Loan Amount Potential (approx 60 months multiplier as default estimate)
    final double estimatedAvailableLoan = availableMonthlyMargin * 50.0;

    return InteractiveHoverCard(
      glowColor: Colors.amberAccent,
      backgroundColor: const Color(0xFF1E1E38).withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(16),
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
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate_rounded,
                    color: Colors.amberAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      "حاسبة الدخل الائتماني الافتراضي 🧮",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.amberAccent,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    Text(
                      "احسب عبء الدين والسعة الائتمانية تلقائياً",
                      style: TextStyle(color: TfcColors.outline, fontSize: 11),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white70, size: 18),
                tooltip: "تصفير الحاسبة",
                onPressed: _resetAll,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Section 1: Income Input
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.attach_money_rounded,
                  color: Colors.greenAccent, size: 18),
              const SizedBox(width: 6),
              const Text(
                "صافي الراتب الشهري (ج.م):",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.rtl,
            child: TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: "أدخل إجمالي الراتب الشهري...",
                hintStyle:
                    const TextStyle(color: TfcColors.outline, fontSize: 11),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: Colors.greenAccent.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.greenAccent),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Existing Loans
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      color: Colors.cyanAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    "أقساط القروض القائمة:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white),
                  ),
                ],
              ),
              InkWell(
                onTap: _addLoanRow,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.cyanAccent, size: 16),
                      SizedBox(width: 4),
                      Text("إضافة قسط",
                          style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_loanInstallmentControllers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "لا توجد أقساط قروض مضافة حالياً",
                style: TextStyle(color: TfcColors.outline, fontSize: 11),
                textDirection: TextDirection.rtl,
              ),
            )
          else
            Column(
              children: _loanInstallmentControllers.asMap().entries.map((ent) {
                final idx = ent.key;
                final ctrl = ent.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: "قسط القرض #${idx + 1}...",
                              hintStyle: const TextStyle(
                                  color: TfcColors.outline, fontSize: 11),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.03),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.08)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 18),
                        onPressed: () => _removeLoanRow(idx),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),

          // Section 3: Credit Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(Icons.credit_card_rounded,
                      color: Colors.orangeAccent, size: 18),
                  SizedBox(width: 6),
                  Text(
                    "البطاقات الائتمانية (الليميت والقسط):",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white),
                  ),
                ],
              ),
              InkWell(
                onTap: _addCardRow,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.add_circle,
                          color: Colors.orangeAccent, size: 16),
                      SizedBox(width: 4),
                      Text("إضافة بطاقة",
                          style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_cardControllers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                "لا توجد بطاقات ائتمانية مضافة حالياً",
                style: TextStyle(color: TfcColors.outline, fontSize: 11),
                textDirection: TextDirection.rtl,
              ),
            )
          else
            Column(
              children: _cardControllers.asMap().entries.map((ent) {
                final idx = ent.key;
                final card = ent.value;
                final limitCtrl = card['limit']!;
                final instCtrl = card['installment']!;
                final double limitVal =
                    double.tryParse(limitCtrl.text) ?? 0.0;
                final double calc5Pct = limitVal * 0.05;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text("بطاقة #${idx + 1}",
                              style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.redAccent, size: 16),
                            onPressed: () => _removeCardRow(idx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: TextField(
                                controller: limitCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: "الليميت (الحد)",
                                  labelStyle: const TextStyle(
                                      color: TfcColors.outline, fontSize: 10),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.02),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: TextField(
                                controller: instCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: "القسط الفعلي",
                                  labelStyle: const TextStyle(
                                      color: TfcColors.outline, fontSize: 10),
                                  filled: true,
                                  fillColor:
                                      Colors.white.withValues(alpha: 0.02),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "عبء الدين المحسوب (5%): ${_formatNumber(calc5Pct)} ج.م",
                        style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Section 4: Target DTI Cap Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const Text("حد عبء الدين المستهدف (DTI Cap):",
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
              Text("${_maxDtiPercent.toInt()}%",
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Colors.amberAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.amberAccent,
              overlayColor: Colors.amber.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: _maxDtiPercent,
              min: 35.0,
              max: 65.0,
              divisions: 6,
              onChanged: (val) {
                setState(() {
                  _maxDtiPercent = val;
                });
              },
            ),
          ),
          const SizedBox(height: 10),

          // Section 5: Dynamic Credit Summary & Results Panel
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: currentDti > _maxDtiPercent
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Colors.amberAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("ملخص الالتزامات والدخل الائتماني 📊",
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.amberAccent)),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  "إجمالي أقساط القروض:",
                  "${_formatNumber(totalLoansInstallments)} ج.م",
                ),
                _buildSummaryRow(
                  "إجمالي عبء 5% للبطاقات:",
                  "${_formatNumber(totalCardsFivePercent)} ج.م",
                ),
                _buildSummaryRow(
                  "إجمالي الالتزامات الشهرية:",
                  "${_formatNumber(totalObligations)} ج.م",
                  isBold: true,
                  color: Colors.orangeAccent,
                ),
                const Divider(color: Colors.white10, height: 12),
                _buildSummaryRow(
                  "نسبة عبء الدين الحالي (DTI):",
                  "${currentDti.toStringAsFixed(1)}%",
                  isBold: true,
                  color: currentDti > _maxDtiPercent
                      ? Colors.redAccent
                      : Colors.greenAccent,
                ),
                const SizedBox(height: 6),
                _buildSummaryRow(
                  "القسط الشهري المتاح حالياً:",
                  "${_formatNumber(availableMonthlyMargin)} ج.م",
                  isBold: true,
                  color: Colors.greenAccent,
                ),
                _buildSummaryRow(
                  "الدخل الائتماني / التمويل التقديري:",
                  "${_formatNumber(estimatedAvailableLoan)} ج.م",
                  isBold: true,
                  color: Colors.amberAccent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: TextDirection.rtl,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isBold ? Colors.white : TfcColors.outline,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: isBold ? 12 : 11,
                  color: color ?? Colors.white,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
