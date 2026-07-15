import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/theme.dart';
import '../../models/client_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/employees_provider.dart';
import 'document_upload_helper.dart';

class NewClientScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const NewClientScreen({super.key, required this.onComplete});

  @override
  ConsumerState<NewClientScreen> createState() => _NewClientScreenState();
}

class _NewClientScreenState extends ConsumerState<NewClientScreen> {
  int _activeStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Page 1 Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  bool _showSecondaryPhone = false;
  final _nationalIdController = TextEditingController();
  final _birthDateController = TextEditingController();
  String _employmentType = "private_sector";
  final _customEmploymentTypeController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  bool _isInsured = true;
  String _salaryTransfer = "bank_transfer";
  final _requestDateController = TextEditingController();

  // Salary detail controllers
  final List<Map<String, TextEditingController>> _salaryBankEntries = [];
  final _cashSalaryController = TextEditingController();

  // Business owner details
  final List<Map<String, dynamic>> _businessEntries = [];

  // Medical details
  final List<Map<String, dynamic>> _medicalEntries = [];

  // Compound units and Modern cars
  bool _hasCompoundUnit = false;
  final List<Map<String, dynamic>> _compoundUnitsList = [];
  bool _hasModernCar = false;
  final List<Map<String, dynamic>> _modernCarsList = [];

  // Page 2 Form Lists
  final List<Map<String, dynamic>> _loansList =
      []; // {bank: textController, installment: textController, notes: textController}
  final List<Map<String, dynamic>> _cardsList =
      []; // {bank: textController, value: textController, type: 'card', duration: textController, installment: textController, highest: textController}

  // Page 3 Details
  final _amountController = TextEditingController();
  String _governorate = "القاهرة";
  final _repNameController = TextEditingController();

  // Documents list for creation
  final List<ClientDocumentModel> _uploadedDocuments = [];

  // Credit summary calculated values
  double _totalLoanInstallments = 0.0;
  double _totalCardFivePercent = 0.0;
  double _totalObligationsWithFivePercent = 0.0;
  double _totalCardHighest = 0.0;
  double _totalMonthlyObligations = 0.0;
  double _totalSalary = 0.0;
  double _dbrPercent = 0.0;
  double _availableForLoan = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize standard documents list
    _uploadedDocuments.addAll([
      ClientDocumentModel(id: 'id-front', documentName: "وجه بطاقة الرقم القومي", documentUrl: "", status: "pending"),
      ClientDocumentModel(id: 'id-back', documentName: "ظهر بطاقة الرقم القومي", documentUrl: "", status: "pending"),
      ClientDocumentModel(id: 'id-other', documentName: "مستندات أخرى (شهادة راتب / كشف حساب)", documentUrl: "", status: "pending"),
    ]);
    // Auto-fill request date with today
    _requestDateController.text =
        DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Start with one salary bank entry by default
    final initialAmountCtrl = TextEditingController();
    initialAmountCtrl.addListener(_recalculateAll);
    _salaryBankEntries.add({
      'bank': TextEditingController(),
      'amount': initialAmountCtrl,
    });
    _cashSalaryController.addListener(_recalculateAll);
    _addBusinessRow();
    _addMedicalRow();
    // Pre-populate representative name with active user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      _repNameController.text = user.fullName;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _secondaryPhoneController.dispose();
    _nationalIdController.dispose();
    _birthDateController.dispose();
    _companyNameController.dispose();
    _jobTitleController.dispose();
    _requestDateController.dispose();
    _cashSalaryController.dispose();
    for (var entry in _medicalEntries) {
      entry['specialization'].dispose();
      entry['practiceStartDate'].dispose();
      entry['licenseDate'].dispose();
    }
    for (var entry in _salaryBankEntries) {
      entry['bank']!.dispose();
      entry['amount']!.dispose();
    }
    _amountController.dispose();
    _repNameController.dispose();
    for (var l in _loansList) {
      l['bank'].dispose();
      l['installment'].dispose();
      l['notes'].dispose();
    }
    for (var c in _cardsList) {
      c['bank'].dispose();
      c['value'].dispose();
      c['fivePercent'].dispose();
      c['duration'].dispose();
      c['installment'].dispose();
      c['highest'].dispose();
      c['notes'].dispose();
    }
    for (var u in _compoundUnitsList) {
      u['compoundName'].dispose();
      u['developerName'].dispose();
      u['contractDate'].dispose();
      u['unitValue'].dispose();
      u['downPayment'].dispose();
      u['downPaymentPercent'].dispose();
      u['paidInstallmentsCount'].dispose();
      u['paidAmount'].dispose();
    }
    for (var car in _modernCarsList) {
      car['carType'].dispose();
      car['carModel'].dispose();
      car['carTodayValue'].dispose();
    }
    super.dispose();
  }

  void _addCompoundUnitRow() {
    final unitValCtrl = TextEditingController();
    final downPayCtrl = TextEditingController();
    final downPayPercentCtrl = TextEditingController(text: "0.0%");

    void calcPercent() {
      final unitVal = double.tryParse(unitValCtrl.text) ?? 0.0;
      final downPay = double.tryParse(downPayCtrl.text) ?? 0.0;
      if (unitVal > 0) {
        final pct = (downPay / unitVal) * 100;
        downPayPercentCtrl.text = "${pct.toStringAsFixed(1)}%";
      } else {
        downPayPercentCtrl.text = "0.0%";
      }
    }

    unitValCtrl.addListener(calcPercent);
    downPayCtrl.addListener(calcPercent);

    setState(() {
      _compoundUnitsList.add({
        'compoundName': TextEditingController(),
        'developerName': TextEditingController(),
        'contractDate': TextEditingController(),
        'unitValue': unitValCtrl,
        'downPayment': downPayCtrl,
        'downPaymentPercent': downPayPercentCtrl,
        'paidInstallmentsCount': TextEditingController(),
        'paidAmount': TextEditingController(),
        'unitContractFiles': <ClientDocumentModel>[],
      });
    });
  }

  void _removeCompoundUnitRow(int index) {
    setState(() {
      _compoundUnitsList[index]['compoundName'].dispose();
      _compoundUnitsList[index]['developerName'].dispose();
      _compoundUnitsList[index]['contractDate'].dispose();
      _compoundUnitsList[index]['unitValue'].dispose();
      _compoundUnitsList[index]['downPayment'].dispose();
      _compoundUnitsList[index]['downPaymentPercent'].dispose();
      _compoundUnitsList[index]['paidInstallmentsCount'].dispose();
      _compoundUnitsList[index]['paidAmount'].dispose();
      _compoundUnitsList.removeAt(index);
    });
  }

  void _addModernCarRow() {
    setState(() {
      _modernCarsList.add({
        'carType': TextEditingController(),
        'carModel': TextEditingController(),
        'carTodayValue': TextEditingController(),
        'licenseStatus': 'بدون حظر',
      });
    });
  }

  void _removeModernCarRow(int index) {
    setState(() {
      _modernCarsList[index]['carType'].dispose();
      _modernCarsList[index]['carModel'].dispose();
      _modernCarsList[index]['carTodayValue'].dispose();
      _modernCarsList.removeAt(index);
    });
  }

  void _addLoanRow() {
    final instCtrl = TextEditingController();
    instCtrl.addListener(_recalculateAll);
    setState(() {
      _loansList.add({
        'bank': TextEditingController(),
        'installment': instCtrl,
        'notes': TextEditingController(),
      });
    });
  }

  void _removeLoanRow(int index) {
    setState(() {
      _loansList[index]['bank'].dispose();
      _loansList[index]['installment'].dispose();
      _loansList[index]['notes'].dispose();
      _loansList.removeAt(index);
    });
    _recalculateAll();
  }

  void _addMedicalRow() {
    setState(() {
      _medicalEntries.add({
        'specialization': TextEditingController(),
        'practiceStartDate': TextEditingController(),
        'licenseDate': TextEditingController(),
        'documents': {
          'صورة كارنيه النقابة': false,
          'صورة مزاولة المهنة': false,
          'صورة رخصة العيادة/الصيدلية': false,
        },
      });
    });
  }

  void _removeMedicalRow(int index) {
    setState(() {
      _medicalEntries[index]['specialization'].dispose();
      _medicalEntries[index]['practiceStartDate'].dispose();
      _medicalEntries[index]['licenseDate'].dispose();
      _medicalEntries.removeAt(index);
    });
  }

  void _updateCreditSummary() {
    double loanInst = 0.0;
    double cardFiveP = 0.0;
    double cardHighest = 0.0;

    for (var loan in _loansList) {
      loanInst += double.tryParse(loan['installment'].text) ?? 0.0;
    }
    for (var card in _cardsList) {
      cardFiveP += double.tryParse(card['fivePercent'].text) ?? 0.0;
      cardHighest += double.tryParse(card['highest'].text) ?? 0.0;
    }

    final totalObl = loanInst + cardHighest;
    final totalOblWithFivePercent = loanInst + cardFiveP;

    // Calculate total salary from active source
    double salary = 0.0;
    if (_salaryTransfer == 'bank_transfer') {
      for (var entry in _salaryBankEntries) {
        salary += double.tryParse(entry['amount']!.text) ?? 0.0;
      }
    } else {
      salary = double.tryParse(_cashSalaryController.text) ?? 0.0;
    }

    final dbr = salary > 0 ? (totalObl / salary) * 100 : 0.0;
    final maxAllowed = salary * 0.50; // DBR ceiling at 50%
    final available = maxAllowed - totalObl;

    setState(() {
      _totalLoanInstallments = loanInst;
      _totalCardFivePercent = cardFiveP;
      _totalObligationsWithFivePercent = totalOblWithFivePercent;
      _totalCardHighest = cardHighest;
      _totalMonthlyObligations = totalObl;
      _totalSalary = salary;
      _dbrPercent = dbr;
      _availableForLoan = available > 0 ? available : 0.0;
    });
  }

  void _recalculateAll() {
    _updateCreditSummary();
  }

  void _addCardRow() {
    final valueController = TextEditingController();
    final fivePercentController = TextEditingController(text: '0.00');
    final installmentController = TextEditingController();
    final highestController = TextEditingController(text: '0.00');

    void recalculate() {
      final val = double.tryParse(valueController.text) ?? 0.0;
      final calc = val * 0.05;
      final calcStr = calc > 0 ? calc.toStringAsFixed(2) : '0.00';

      final inst = double.tryParse(installmentController.text) ?? 0.0;
      final highestVal = calc > inst ? calc : inst;
      final highestStr =
          highestVal > 0 ? highestVal.toStringAsFixed(2) : '0.00';

      setState(() {
        fivePercentController.text = calcStr;
        highestController.text = highestStr;
      });
      _recalculateAll();
    }

    valueController.addListener(recalculate);
    installmentController.addListener(recalculate);
    fivePercentController.addListener(_recalculateAll);
    highestController.addListener(_recalculateAll);

    setState(() {
      _cardsList.add({
        'bank': TextEditingController(text: 'بنك مصر'),
        'value': valueController,
        'fivePercent': fivePercentController,
        'type': 'card',
        'duration': TextEditingController(text: '12 شهر'),
        'installment': installmentController,
        'highest': highestController,
        'notes': TextEditingController(),
      });
    });
  }

  void _removeCardRow(int index) {
    setState(() {
      _cardsList[index]['bank'].dispose();
      _cardsList[index]['value'].dispose();
      _cardsList[index]['fivePercent'].dispose();
      _cardsList[index]['duration'].dispose();
      _cardsList[index]['installment'].dispose();
      _cardsList[index]['highest'].dispose();
      _cardsList[index]['notes'].dispose();
      _cardsList.removeAt(index);
    });
  }

  void _addBusinessRow() {
    setState(() {
      _businessEntries.add({
        'activity': TextEditingController(),
        'startDate': TextEditingController(),
        'place': TextEditingController(),
        'documents': {
          'سجل تجارى': false,
          'بطاقة ضربية': false,
          'كشف حساب': false,
          'ميزانيات': false,
          'فواتير': false,
          'رخصة مشروع او صناعية': false,
          'عقد ايجار او تمليك لمقر الشركة': false,
        },
        'taxCardFiles': <ClientDocumentModel>[],
        'otherAttachments': <ClientDocumentModel>[],
      });
    });
  }

  void _removeBusinessRow(int index) {
    if (_businessEntries.length <= 1) return;
    setState(() {
      _businessEntries[index]['activity']!.dispose();
      _businessEntries[index]['startDate']!.dispose();
      _businessEntries[index]['place']!.dispose();
      _businessEntries.removeAt(index);
    });
  }

  void _addSalaryBankRow() {
    final amtCtrl = TextEditingController();
    amtCtrl.addListener(_recalculateAll);
    setState(() {
      _salaryBankEntries.add({
        'bank': TextEditingController(),
        'amount': amtCtrl,
      });
    });
  }

  void _removeSalaryBankRow(int index) {
    if (_salaryBankEntries.length <= 1) return;
    setState(() {
      _salaryBankEntries[index]['bank']!.dispose();
      _salaryBankEntries[index]['amount']!.dispose();
      _salaryBankEntries.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final creditScore = 400 +
        (double.tryParse(_amountController.text) != null
            ? 250
            : 150); // Mocker score

    final newClient = ClientModel(
      id: '',
      fullName: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      secondaryPhoneNumber: _showSecondaryPhone &&
              _secondaryPhoneController.text.trim().isNotEmpty
          ? _secondaryPhoneController.text.trim()
          : null,
      nationalId: _nationalIdController.text.trim(),
      birthDate: _birthDateController.text.trim().isEmpty
          ? '1990-01-01'
          : _birthDateController.text,
      employmentType: _employmentType,
      companyName: _companyNameController.text.trim(),
      jobTitle: _jobTitleController.text.trim(),
      isInsured: _isInsured,
      salaryTransferMethod: _salaryTransfer,
      salaryBankDetails: _salaryTransfer == 'bank_transfer'
          ? _salaryBankEntries
              .where((e) =>
                  e['bank']!.text.isNotEmpty && e['amount']!.text.isNotEmpty)
              .map((e) => {
                    'bank': e['bank']!.text.trim(),
                    'amount': e['amount']!.text.trim(),
                  })
              .toList()
          : [],
      cashSalaryAmount: _salaryTransfer == 'cash'
          ? double.tryParse(_cashSalaryController.text)
          : null,
      creditScore: creditScore > 850 ? 850 : creditScore,
      requestedAmount: double.tryParse(_amountController.text) ?? 0.0,
      governorate: _governorate,
      representativeName: _repNameController.text.trim(),
      status: 'pending',
      createdAt: DateTime.now(),
      businessData: _employmentType == 'business_owner'
          ? _businessEntries.map((b) {
              return {
                'activity': b['activity']!.text.trim(),
                'startDate': b['startDate']!.text.trim(),
                'place': b['place']!.text.trim(),
                'documents': b['documents'],
              };
            }).toList()
          : ['doctor_clinic', 'doctor_hospital', 'pharmacist_owner'].contains(_employmentType)
              ? _medicalEntries.map((m) {
                  return {
                    'specialization': m['specialization']!.text.trim(),
                    'practiceStartDate': m['practiceStartDate']!.text.trim(),
                    'licenseDate': m['licenseDate']!.text.trim(),
                    'documents': m['documents'],
                  };
                }).toList()
              : [],
      hasCompoundUnit: _hasCompoundUnit,
      hasModernCar: _hasModernCar,
      compoundUnitsData: _hasCompoundUnit
          ? _compoundUnitsList.map((u) {
              return {
                'compoundName': u['compoundName']!.text.trim(),
                'developerName': u['developerName']!.text.trim(),
                'contractDate': u['contractDate']!.text.trim(),
                'unitValue': double.tryParse(u['unitValue']!.text) ?? 0.0,
                'downPayment': double.tryParse(u['downPayment']!.text) ?? 0.0,
                'paidInstallmentsCount': int.tryParse(u['paidInstallmentsCount']!.text) ?? 0,
                'paidAmount': double.tryParse(u['paidAmount']!.text) ?? 0.0,
                'unitContractFiles': (u['unitContractFiles'] as List<ClientDocumentModel>).map((file) => file.toJson()).toList(),
              };
            }).toList()
          : [],
      modernCarsData: _hasModernCar
          ? _modernCarsList.map((c) {
              return {
                'carType': c['carType']!.text.trim(),
                'carModel': c['carModel']!.text.trim(),
                'carTodayValue': double.tryParse(c['carTodayValue']!.text) ?? 0.0,
                'licenseStatus': c['licenseStatus'],
              };
            }).toList()
          : [],
      documents: <ClientDocumentModel>[
        ..._uploadedDocuments,
        if (_employmentType == 'business_owner')
          ..._businessEntries.expand((b) => <ClientDocumentModel>[
                ...(b['taxCardFiles'] as List<ClientDocumentModel>? ?? []),
                ...(b['otherAttachments'] as List<ClientDocumentModel>? ?? []),
              ]),
        if (_hasCompoundUnit)
          ..._compoundUnitsList.expand((u) => <ClientDocumentModel>[
                ...(u['unitContractFiles'] as List<ClientDocumentModel>? ?? []),
              ]),
      ].where((d) => d.documentUrl.isNotEmpty).toList(),
    );

    // Build submodels
    final List<ExistingLoanModel> loans = [];
    for (var l in _loansList) {
      if (l['bank'].text.isNotEmpty) {
        loans.add(
          ExistingLoanModel(
            id: '',
            bankName: l['bank'].text.trim(),
            installmentValue: double.tryParse(l['installment'].text) ?? 0.0,
            notes: l['notes'].text.trim(),
          ),
        );
      }
    }

    final List<CreditCardRequestModel> cards = [];
    for (var c in _cardsList) {
      if (c['bank'].text.isNotEmpty) {
        final val = double.tryParse(c['value'].text) ?? 0.0;
        cards.add(
          CreditCardRequestModel(
            id: '',
            bankName: c['bank'].text.trim(),
            value: val,
            fivePercentCalc: val * 0.05,
            type: c['type'],
            duration: c['duration'].text.trim(),
            installment: double.tryParse(c['installment'].text) ?? 0.0,
            highestValue: double.tryParse(c['highest'].text) ?? 0.0,
            notes: c['notes'].text.trim(),
          ),
        );
      }
    }

    // Build custom salary details log notes
    String customNotes = "";
    if (_employmentType == 'business_owner') {
      final bizDetails = _businessEntries.map((b) {
        final docs = (b['documents'] as Map<String, bool>)
            .entries
            .where((e) => e.value)
            .map((e) => e.key)
            .join(", ");
        return "النشاط: ${b['activity'].text.trim()} (بدء: ${b['startDate'].text.trim()}, مكان: ${b['place'].text.trim()}). الأوراق المتاحة: $docs";
      }).join(" | ");
      customNotes = "تفاصيل الأنشطة التجارية: $bizDetails. ";
    }

    if (_salaryTransfer == 'bank_transfer') {
      final entries = _salaryBankEntries
          .where(
              (e) => e['bank']!.text.isNotEmpty && e['amount']!.text.isNotEmpty)
          .map((e) =>
              "${e['bank']!.text.trim()} (${e['amount']!.text.trim()} ج.م)")
          .join(", ");
      customNotes +=
          "طريقة تحويل الراتب: تحويل بنكي على الحسابات: $entries";
    } else {
      customNotes +=
          "طريقة تحويل الراتب: إيداع نقدي بمبلغ: ${_cashSalaryController.text.trim()} ج.م";
    }

    final errorMsg = await ref
        .read(clientProvider.notifier)
        .addClient(newClient, loans, cards, customNotes: customNotes);

    if (errorMsg == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("تم حفظ ومتابعة العميل بنجاح", textAlign: TextAlign.right),
            backgroundColor: TfcColors.primary,
          ),
        );
        widget.onComplete();
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("خطأ في حفظ العميل",
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(errorMsg, textAlign: TextAlign.right),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("حسناً"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Wizard Header Title
              const Text(
                "تقديم ملف تمويل جديد",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: TfcColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Stepper Selector Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  _buildStepIndicator(0, "البيانات الشخصية"),
                  _buildStepLine(0),
                  _buildStepIndicator(1, "البيانات الائتمانية"),
                  _buildStepLine(1),
                  _buildStepIndicator(2, "المستندات والطلب"),
                ],
              ),
              const SizedBox(height: 36),

              // Step Page Content Switcher
              IndexedStack(
                index: _activeStep,
                children: [
                  _buildPersonalDataStep(),
                  _buildCreditDataStep(),
                  _buildDocumentsStep(),
                ],
              ),
              const SizedBox(height: 40),

              // Footer Buttons Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  if (_activeStep < 2)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TfcColors.primary,
                        foregroundColor: TfcColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          _activeStep++;
                        });
                      },
                      child: const Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Text("التالي",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_back, size: 16),
                        ],
                      ),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TfcColors.primary,
                        foregroundColor: TfcColors.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        shadowColor:
                            TfcColors.primary.withAlpha((0.4 * 255).toInt()),
                        elevation: 6,
                      ),
                      onPressed: _submitForm,
                      child: const Text("حفظ ومتابعة",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  if (_activeStep > 0)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: TfcColors.outline),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      onPressed: () {
                        setState(() {
                          _activeStep--;
                        });
                      },
                      child: const Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Icon(Icons.arrow_forward,
                              size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text("السابق", style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    )
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      onPressed: widget.onComplete,
                      child: const Text("إلغاء",
                          style: TextStyle(color: Colors.white)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String label) {
    final isActive = _activeStep == stepIndex;
    final isDone = _activeStep > stepIndex;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive
                // ignore: deprecated_member_use
                ? TfcColors.primary.withValues(alpha: 0.2)
                : (isDone ? TfcColors.primary : Colors.transparent),
            shape: BoxShape.circle,
            border: Border.all(
              color: (isActive || isDone)
                  ? TfcColors.primary
                  : Colors.white.withAlpha((0.2 * 255).toInt()),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: TfcColors.onPrimary, size: 20)
                : Text(
                    (stepIndex + 1).toString(),
                    style: TextStyle(
                      color: isActive
                          ? TfcColors.primary
                          : (isDone ? TfcColors.onPrimary : Colors.white60),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? TfcColors.primary : TfcColors.outline,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int index) {
    final isDone = _activeStep > index;
    return Container(
      width: 48,
      height: 1,
      margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
      color: isDone
          ? TfcColors.primary
          : Colors.white.withAlpha((0.1 * 255).toInt()),
    );
  }

  // Phase 1: Personal Data UI Card
  Widget _buildPersonalDataStep() {
    return InteractiveGlowWidget(
      child: GlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.person, color: TfcColors.primary),
              const SizedBox(width: 12),
              Text("البيانات الشخصية للعميل",
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 24),

          // Name and Phone
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildFormField(
                  label: "الاسم الكامل (ثلاثي كما في البطاقة)",
                  child: TextFormField(
                    controller: _nameController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                        hintText: "أحمد بن عبد الله القحطاني"),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: "رقم الهاتف المحمول",
                  child: TextFormField(
                    controller: _phoneController,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: "05XXXXXXXX"),
                    validator: (v) => v!.isEmpty ? "مطلوب" : null,
                  ),
                ),
              ),
            ],
          ),

          // Add secondary phone button or field
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showSecondaryPhone
                ? Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Expanded(
                        child: _buildFormField(
                          label: "رقم الهاتف الإضافي",
                          child: TextFormField(
                            controller: _secondaryPhoneController,
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: "05XXXXXXXX",
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.redAccent, size: 20),
                                tooltip: "إزالة الرقم الإضافي",
                                onPressed: () {
                                  setState(() {
                                    _showSecondaryPhone = false;
                                    _secondaryPhoneController.clear();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox()),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: TfcColors.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        setState(() {
                          _showSecondaryPhone = true;
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text("إضافة رقم هاتف آخر",
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // ID and Birthday
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildFormField(
                  label: "الرقم القومي (14 رقم)",
                  child: TextFormField(
                    controller: _nationalIdController,
                    textAlign: TextAlign.right,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(hintText: "10029384758694"),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (v.trim().length < 10) return "يرجى كتابة رقم صحيح";
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: "تاريخ الميلاد",
                  child: TextFormField(
                    controller: _birthDateController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(hintText: "YYYY-MM-DD"),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Job structure
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildFormField(
                  label: "نوع التوظيف",
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.04 * 255).toInt()),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withAlpha((0.08 * 255).toInt())),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _employmentType,
                        dropdownColor: TfcColors.surfaceDim,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(
                              value: "government_employee",
                              child: Text("موظف حكومى",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "private_sector",
                              child: Text("موظف قطاع خاص",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "business_owner",
                              child: Text("صاحب عمل",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "doctor_clinic",
                              child: Text("دكتور عيادة",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "doctor_hospital",
                              child: Text("دكتور مستشفى",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "pharmacist",
                              child: Text("صيدلى",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "pharmacist_owner",
                              child: Text("صيدلى صاحب صيدلية",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "military",
                              child: Text("قوات مسلحة",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "faculty",
                              child: Text("هيئة تدريس",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "teacher",
                              child: Text("مدرس",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "freelance",
                              child: Text("فريلانس",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "retired",
                              child: Text("معاش",
                                  textDirection: TextDirection.rtl)),
                          DropdownMenuItem(
                              value: "other",
                              child: Text("أخرى",
                                  textDirection: TextDirection.rtl)),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _employmentType = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              if (_employmentType == "other") ...[
                const SizedBox(width: 16),
                Expanded(
                  child: _buildFormField(
                    label: "حدد نوع التوظيف",
                    child: TextFormField(
                      controller: _customEmploymentTypeController,
                      textAlign: TextAlign.right,
                      decoration:
                          const InputDecoration(hintText: "اكتب نوع التوظيف"),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: "اسم جهة العمل / الشركة",
                  child: TextFormField(
                    controller: _companyNameController,
                    textAlign: TextAlign.right,
                    decoration:
                        const InputDecoration(hintText: "مثال: أرامكو للخدمات"),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Job Title & Insurance
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: _buildFormField(
                  label: "المسمى الوظيفي الحالي",
                  child: TextFormField(
                    controller: _jobTitleController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                        hintText: "مثال: مهندس برمجيات رئيسي"),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: "حالة التأمين الاجتماعي",
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Radio<bool>(
                        value: true,
                        // ignore: deprecated_member_use
                        groupValue: _isInsured,
                        activeColor: TfcColors.primary,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) setState(() => _isInsured = val);
                        },
                      ),
                      const Text("مؤمن عليه"),
                      const SizedBox(width: 16),
                      Radio<bool>(
                        value: false,
                        // ignore: deprecated_member_use
                        groupValue: _isInsured,
                        activeColor: TfcColors.primary,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) setState(() => _isInsured = val);
                        },
                      ),
                      const Text("غير مؤمن"),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_employmentType == "business_owner") ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  "تفاصيل الأنشطة التجارية",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TfcColors.secondary),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                  onPressed: _addBusinessRow,
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text("إضافة نشاط تجاري آخر", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _businessEntries.length,
              itemBuilder: (context, idx) {
                final entry = _businessEntries[idx];
                final docsMap = entry['documents'] as Map<String, bool>;
                final taxFiles = entry['taxCardFiles'] as List<ClientDocumentModel>;
                final otherFiles = entry['otherAttachments'] as List<ClientDocumentModel>;

                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text("النشاط #${idx + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                          if (_businessEntries.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeBusinessRow(idx),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Activity & Start Date
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: "النشاط",
                              child: TextFormField(
                                controller: entry['activity'],
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(hintText: "مثال: تجارة مواد البناء"),
                                validator: (v) => v!.isEmpty ? "مطلوب" : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildFormField(
                              label: "تاريخ بدء النشاط",
                              child: TextFormField(
                                controller: entry['startDate'],
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(hintText: "سنة البدء أو تاريخ كامل"),
                                validator: (v) => v!.isEmpty ? "مطلوب" : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Place of Activity
                      _buildFormField(
                        label: "مكان النشاط",
                        child: TextFormField(
                          controller: entry['place'],
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(hintText: "العنوان بالكامل أو المحافظة والحي"),
                          validator: (v) => v!.isEmpty ? "مطلوب" : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Available Documents Checkboxes
                      const Text(
                        "الأوراق المتاحة",
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 14, color: TfcColors.secondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: docsMap.keys.map((docName) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: docsMap[docName],
                                  activeColor: TfcColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      docsMap[docName] = val ?? false;
                                    });
                                  },
                                ),
                                Text(docName, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Commercial Register & Tax Card uploads
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "صور السجل والبطاقة الضريبية",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: TfcColors.secondary),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    DocumentUploadHelper.showUploadDialog(
                                      context,
                                      onUploadComplete: (name, url) {
                                        setState(() {
                                          taxFiles.add(
                                            ClientDocumentModel(
                                              id: "tax-doc-${DateTime.now().millisecondsSinceEpoch}",
                                              documentName: "سجل/بطاقة ضريبية: $name",
                                              documentUrl: url,
                                              status: "pending",
                                            ),
                                          );
                                        });
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                                    foregroundColor: TfcColors.primary,
                                  ),
                                  icon: const Icon(Icons.upload_file, size: 14),
                                  label: const Text("رفع ملف", style: TextStyle(fontSize: 12)),
                                ),
                                if (taxFiles.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ...taxFiles.map((file) => Row(
                                    textDirection: TextDirection.rtl,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          file.documentName.replaceAll("سجل/بطاقة ضريبية: ", ""),
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                        onPressed: () => setState(() => taxFiles.remove(file)),
                                      )
                                    ],
                                  )),
                                ]
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  "مرفقات أخرى للنشاط",
                                  textAlign: TextAlign.right,
                                  style: TextStyle(fontSize: 12, color: TfcColors.secondary),
                                ),
                                const SizedBox(height: 6),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    DocumentUploadHelper.showUploadDialog(
                                      context,
                                      onUploadComplete: (name, url) {
                                        setState(() {
                                          otherFiles.add(
                                            ClientDocumentModel(
                                              id: "other-activity-doc-${DateTime.now().millisecondsSinceEpoch}",
                                              documentName: "مرفق نشاط: $name",
                                              documentUrl: url,
                                              status: "pending",
                                            ),
                                          );
                                        });
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                                    foregroundColor: TfcColors.primary,
                                  ),
                                  icon: const Icon(Icons.upload_file, size: 14),
                                  label: const Text("رفع ملف", style: TextStyle(fontSize: 12)),
                                ),
                                if (otherFiles.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  ...otherFiles.map((file) => Row(
                                    textDirection: TextDirection.rtl,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          file.documentName.replaceAll("مرفق نشاط: ", ""),
                                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                        onPressed: () => setState(() => otherFiles.remove(file)),
                                      )
                                    ],
                                  )),
                                ]
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          if (['doctor_clinic', 'doctor_hospital', 'pharmacist_owner'].contains(_employmentType)) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                const Text(
                  "تفاصيل النشاط الطبي",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: TfcColors.secondary),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                  onPressed: _addMedicalRow,
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text("إضافة نشاط طبي آخر", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _medicalEntries.length,
              itemBuilder: (context, idx) {
                final entry = _medicalEntries[idx];
                final docsMap = entry['documents'] as Map<String, bool>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Text("النشاط الطبي #${idx + 1}",
                              style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                          if (_medicalEntries.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                              onPressed: () => _removeMedicalRow(idx),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (['doctor_clinic', 'doctor_hospital'].contains(_employmentType))
                        _buildFormField(
                          label: "التخصص",
                          child: TextFormField(
                            controller: entry['specialization'],
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(hintText: "مثال: باطنة، أسنان..."),
                            validator: (v) => v!.isEmpty ? "مطلوب" : null,
                          ),
                        ),
                      if (['doctor_clinic', 'doctor_hospital'].contains(_employmentType))
                        const SizedBox(height: 16),
                      Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: "تاريخ مزاولة المهنة",
                              child: TextFormField(
                                controller: entry['practiceStartDate'],
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(hintText: "مثال: 2015-05-01"),
                                validator: (v) => v!.isEmpty ? "مطلوب" : null,
                              ),
                            ),
                          ),
                          if (['doctor_clinic', 'pharmacist_owner'].contains(_employmentType)) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildFormField(
                                label: "تاريخ الترخيص",
                                child: TextFormField(
                                  controller: entry['licenseDate'],
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(hintText: "مثال: 2018-01-01"),
                                  validator: (v) => v!.isEmpty ? "مطلوب" : null,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "الأوراق المتاحة",
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 14, color: TfcColors.secondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: docsMap.keys.map((docName) {
                            if (docName == 'صورة رخصة العيادة/الصيدلية' && _employmentType == 'doctor_hospital') {
                              return const SizedBox.shrink();
                            }
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: docsMap[docName],
                                  activeColor: TfcColors.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      docsMap[docName] = val ?? false;
                                    });
                                  },
                                ),
                                Text(docName, style: const TextStyle(fontSize: 12)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // Salary Transfer
          _buildFormField(
            label: "طريقة تحويل الراتب",
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Radio<String>(
                  value: "bank_transfer",
                  // ignore: deprecated_member_use
                  groupValue: _salaryTransfer,
                  activeColor: TfcColors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) setState(() => _salaryTransfer = val);
                  },
                ),
                const Text("تحويل راتب للبنك"),
                const SizedBox(width: 32),
                Radio<String>(
                  value: "cash",
                  // ignore: deprecated_member_use
                  groupValue: _salaryTransfer,
                  activeColor: TfcColors.primary,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    if (val != null) setState(() => _salaryTransfer = val);
                  },
                ),
                const Text("إيداع نقدي / شيك"),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _salaryTransfer == "bank_transfer"
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          const Text(
                            "تفاصيل الحسابات البنكية المحول عليها الراتب",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TfcColors.secondary),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                                foregroundColor: TfcColors.primary),
                            onPressed: _addSalaryBankRow,
                            icon: const Icon(Icons.add_circle, size: 16),
                            label: const Text("إضافة حساب بنكي",
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _salaryBankEntries.length,
                        itemBuilder: (context, idx) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _buildFormField(
                                    label: "اسم البنك",
                                    child: TextFormField(
                                      controller: _salaryBankEntries[idx]
                                          ['bank'],
                                      textAlign: TextAlign.right,
                                      decoration: const InputDecoration(
                                          hintText: "اسم البنك"),
                                      validator: (v) =>
                                          v!.isEmpty ? "مطلوب" : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: _buildFormField(
                                    label: "المبلغ (ج.م)",
                                    child: TextFormField(
                                      controller: _salaryBankEntries[idx]
                                          ['amount'],
                                      textAlign: TextAlign.right,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                          hintText: "0.00"),
                                      validator: (v) =>
                                          v!.isEmpty ? "مطلوب" : null,
                                    ),
                                  ),
                                ),
                                if (_salaryBankEntries.length > 1) ...[
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24.0),
                                    child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.redAccent, size: 20),
                                      onPressed: () =>
                                          _removeSalaryBankRow(idx),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormField(
                        label: "المبلغ (ج.م)",
                        child: TextFormField(
                          controller: _cashSalaryController,
                          textAlign: TextAlign.right,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              hintText: "قيمة الراتب النقدي"),
                          validator: (v) => v!.isEmpty ? "مطلوب" : null,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    ),
    );
  }

  // Phase 2: Credit Data UI Lists
  Widget _buildCreditDataStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Loans Subtable card
        InteractiveGlowWidget(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  const Text("القروض والتسهيلات الائتمانية القائمة",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: TfcColors.primary),
                    onPressed: _addLoanRow,
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text("إضافة قرض قائم"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loansList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text("لا توجد قروض مسجلة حالياً",
                          style: TextStyle(color: TfcColors.outline))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _loansList.length,
                  itemBuilder: (context, idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _loansList[idx]['bank'],
                              textAlign: TextAlign.right,
                              decoration:
                                  const InputDecoration(hintText: "اسم البنك"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _loansList[idx]['installment'],
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  hintText: "قيمة القسط الشهري"),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _loansList[idx]['notes'],
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                  hintText: "ملاحظات إضافية"),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.redAccent),
                            onPressed: () => _removeLoanRow(idx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        )),
        const SizedBox(height: 24),

        // Credit Cards list card
        InteractiveGlowWidget(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  const Text("البطاقات الائتمانية والطلبات المفتوحة",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                        foregroundColor: TfcColors.primary),
                    onPressed: _addCardRow,
                    icon: const Icon(Icons.add_circle, size: 16),
                    label: const Text("إضافة بطاقة / طلب"),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_cardsList.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                      child: Text("لا توجد بطاقات ائتمانية مسجلة",
                          style: TextStyle(color: TfcColors.outline))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _cardsList.length,
                  itemBuilder: (context, idx) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  const Icon(Icons.credit_card,
                                      size: 18, color: TfcColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    "بطاقة / طلب رقم ${idx + 1}",
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: TfcColors.primary),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () => _removeCardRow(idx),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 1: Bank Name, Limit/Value, 5%
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildFormField(
                                      label: "اسم البنك",
                                      child: TextFormField(
                                        controller: _cardsList[idx]['bank'],
                                        textAlign: TextAlign.right,
                                        decoration: const InputDecoration(
                                            hintText: "اسم البنك"),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "قيمة الليمت",
                                      child: TextFormField(
                                        controller: _cardsList[idx]['value'],
                                        textAlign: TextAlign.right,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                            hintText: "0.00"),
                                        onChanged: (val) {
                                          final parsed =
                                              double.tryParse(val) ?? 0.0;
                                          final calc = parsed * 0.05;
                                          setState(() {
                                            _cardsList[idx]['fivePercent']
                                                    .text =
                                                calc > 0
                                                    ? calc.toStringAsFixed(2)
                                                    : '0.00';
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "قيمة الـ 5%",
                                      child: TextFormField(
                                        controller: _cardsList[idx]
                                            ['fivePercent'],
                                        textAlign: TextAlign.right,
                                        readOnly: true,
                                        style: const TextStyle(
                                            color: TfcColors.secondary,
                                            fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                          hintText: "0.00",
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 2: Type, Duration, Installment (conditional), Highest Value
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "النوع",
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.08)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _cardsList[idx]['type'],
                                            dropdownColor: TfcColors.surfaceDim,
                                            isExpanded: true,
                                            items: const [
                                              DropdownMenuItem(
                                                  value: 'card',
                                                  child: Text("بطاقة")),
                                              DropdownMenuItem(
                                                  value: 'request',
                                                  child: Text("أبلكيشن")),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setState(() {
                                                  _cardsList[idx]['type'] = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "المدة",
                                      child: TextFormField(
                                        controller: _cardsList[idx]['duration'],
                                        textAlign: TextAlign.right,
                                        decoration: const InputDecoration(
                                            hintText: "12 شهر"),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (_cardsList[idx]['type'] == 'request') ...[
                                    Expanded(
                                      flex: 2,
                                      child: _buildFormField(
                                        label: "قيمة القسط",
                                        child: TextFormField(
                                          controller: _cardsList[idx]
                                              ['installment'],
                                          textAlign: TextAlign.right,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(
                                              hintText: "0.00"),
                                          onChanged: (val) {
                                            final instVal =
                                                double.tryParse(val) ?? 0.0;
                                            final limitVal = double.tryParse(
                                                    _cardsList[idx]['value']
                                                        .text) ??
                                                0.0;
                                            final fiveP = limitVal * 0.05;
                                            final highest = instVal > fiveP
                                                ? instVal
                                                : fiveP;
                                            setState(() {
                                              _cardsList[idx]['highest'].text =
                                                  highest > 0
                                                      ? highest
                                                          .toStringAsFixed(2)
                                                      : '0.00';
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "الحد الأعلى",
                                      child: TextFormField(
                                        controller: _cardsList[idx]['highest'],
                                        textAlign: TextAlign.right,
                                        readOnly: true,
                                        style: const TextStyle(
                                            color: Colors.amberAccent,
                                            fontWeight: FontWeight.bold),
                                        decoration: const InputDecoration(
                                            hintText: "0.00"),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 3: Additional Notes
                              _buildFormField(
                                label: "ملاحظات إضافية",
                                child: TextFormField(
                                  controller: _cardsList[idx]['notes'],
                                  textAlign: TextAlign.right,
                                  decoration: const InputDecoration(
                                      hintText:
                                          "تفاصيل أو ملاحظات إضافية بخصوص البطاقة أو الطلب..."),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        )),
        const SizedBox(height: 24),
        // Compound unit section
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    "امتلاك وحدة في كمبوند",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TfcColors.secondary),
                  ),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _hasCompoundUnit,
                        activeColor: TfcColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _hasCompoundUnit = val;
                              if (_compoundUnitsList.isEmpty) {
                                _addCompoundUnitRow();
                              }
                            });
                          }
                        },
                      ),
                      const Text("نعم"),
                      const SizedBox(width: 12),
                      Radio<bool>(
                        value: false,
                        groupValue: _hasCompoundUnit,
                        activeColor: TfcColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _hasCompoundUnit = val;
                            });
                          }
                        },
                      ),
                      const Text("لا"),
                    ],
                  ),
                ],
              ),
              if (_hasCompoundUnit) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      "تفاصيل الوحدات",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TfcColors.primary),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                      onPressed: _addCompoundUnitRow,
                      icon: const Icon(Icons.add_circle, size: 16),
                      label: const Text("إضافة وحدة أخرى", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _compoundUnitsList.length,
                  itemBuilder: (context, idx) {
                    final entry = _compoundUnitsList[idx];
                    final files = entry['unitContractFiles'] as List<ClientDocumentModel>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text("الوحدة #${idx + 1}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                              if (_compoundUnitsList.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                  onPressed: () => _removeCompoundUnitRow(idx),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "اسم الكمبوند",
                                  child: TextFormField(
                                    controller: entry['compoundName'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "مثال: بيفيرلي هيلز"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "اسم المطور",
                                  child: TextFormField(
                                    controller: entry['developerName'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "مثال: سوديك"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "تاريخ التعاقد",
                                  child: TextFormField(
                                    controller: entry['contractDate'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "مثال: 2022-01-01"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "قيمة الوحدة",
                                  child: TextFormField(
                                    controller: entry['unitValue'],
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: "0.00"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "المقدم المدفوع",
                                  child: TextFormField(
                                    controller: entry['downPayment'],
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: "0.00"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "نسبة المقدم",
                                  child: TextFormField(
                                    controller: entry['downPaymentPercent'],
                                    textAlign: TextAlign.right,
                                    readOnly: true,
                                    style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold),
                                    decoration: const InputDecoration(hintText: "0.0%"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "عدد الأقساط المدفوعة",
                                  child: TextFormField(
                                    controller: entry['paidInstallmentsCount'],
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: "0"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "قيمة ما تم دفعه",
                                  child: TextFormField(
                                    controller: entry['paidAmount'],
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: "0.00"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                "صورة عقد الوحدة",
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, color: TfcColors.secondary),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                onPressed: () {
                                  DocumentUploadHelper.showUploadDialog(
                                    context,
                                    onUploadComplete: (name, url) {
                                      setState(() {
                                        files.add(
                                          ClientDocumentModel(
                                            id: "unit-doc-${DateTime.now().millisecondsSinceEpoch}",
                                            documentName: "عقد وحدة: $name",
                                            documentUrl: url,
                                            status: "pending",
                                          ),
                                        );
                                      });
                                    },
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                                  foregroundColor: TfcColors.primary,
                                ),
                                icon: const Icon(Icons.upload_file, size: 14),
                                label: const Text("رفع ملف العقد", style: TextStyle(fontSize: 12)),
                              ),
                              if (files.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                ...files.map((file) => Row(
                                  textDirection: TextDirection.rtl,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        file.documentName.replaceAll("عقد وحدة: ", ""),
                                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                                      onPressed: () => setState(() => files.remove(file)),
                                    )
                                  ],
                                )),
                              ]
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        // Modern Car section
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                textDirection: TextDirection.rtl,
                children: [
                  const Text(
                    "امتلاك سيارة حديثة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: TfcColors.secondary),
                  ),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _hasModernCar,
                        activeColor: TfcColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _hasModernCar = val;
                              if (_modernCarsList.isEmpty) {
                                _addModernCarRow();
                              }
                            });
                          }
                        },
                      ),
                      const Text("نعم"),
                      const SizedBox(width: 12),
                      Radio<bool>(
                        value: false,
                        groupValue: _hasModernCar,
                        activeColor: TfcColors.primary,
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _hasModernCar = val;
                            });
                          }
                        },
                      ),
                      const Text("لا"),
                    ],
                  ),
                ],
              ),
              if (_hasModernCar) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      "تفاصيل السيارات",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: TfcColors.primary),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: TfcColors.primary),
                      onPressed: _addModernCarRow,
                      icon: const Icon(Icons.add_circle, size: 16),
                      label: const Text("إضافة سيارة أخرى", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _modernCarsList.length,
                  itemBuilder: (context, idx) {
                    final entry = _modernCarsList[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text("السيارة #${idx + 1}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: TfcColors.primary)),
                              if (_modernCarsList.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                  onPressed: () => _removeModernCarRow(idx),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "نوع السيارة",
                                  child: TextFormField(
                                    controller: entry['carType'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "مثال: هيونداي توسان"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "موديل كام",
                                  child: TextFormField(
                                    controller: entry['carModel'],
                                    textAlign: TextAlign.right,
                                    decoration: const InputDecoration(hintText: "مثال: 2022"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Expanded(
                                child: _buildFormField(
                                  label: "قيمة سعر السيارة اليوم",
                                  child: TextFormField(
                                    controller: entry['carTodayValue'],
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(hintText: "0.00"),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildFormField(
                                  label: "الرخصة",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: entry['licenseStatus'],
                                        dropdownColor: TfcColors.surfaceDim,
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'عليها حظر',
                                            child: Text("عليها حظر"),
                                          ),
                                          DropdownMenuItem(
                                            value: 'بدون حظر',
                                            child: Text("بدون حظر"),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              entry['licenseStatus'] = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),
        // Credit Summary Card
        _buildCreditSummaryCard(),
      ],
    );
  }

  // Phase 3: Documents and Financial Request details
  Widget _buildDocumentsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Required Finance amount
        InteractiveGlowWidget(
          child: GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("تفاصيل التمويل المطلوب والجهة المسؤول",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textDirection: TextDirection.rtl),
              const SizedBox(height: 20),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: "مبلغ التمويل المطلوب (ج.م)",
                      child: TextFormField(
                        controller: _amountController,
                        textAlign: TextAlign.right,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: "0.00"),
                        validator: (v) => v!.isEmpty ? "مطلوب" : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      label: "المحافظة",
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _governorate,
                            dropdownColor: TfcColors.surfaceDim,
                            isExpanded: true,
                            items: const [
                              "القاهرة",
                              "الجيزة",
                              "الإسكندرية",
                              "الدقهلية",
                              "البحر الأحمر",
                              "البحيرة",
                              "الفيوم",
                              "الغربية",
                              "الإسماعيلية",
                              "المنوفية",
                              "المنيا",
                              "القليوبية",
                              "الوادي الجديد",
                              "السويس",
                              "أسوان",
                              "أسيوط",
                              "بني سويف",
                              "بورسعيد",
                              "دمياط",
                              "الشرقية",
                              "جنوب سيناء",
                              "كفر الشيخ",
                              "مطروح",
                              "الأقصر",
                              "قنا",
                              "شمال سيناء",
                              "سوهاج"
                            ]
                                .map((g) =>
                                    DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _governorate = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: "امتلاك وحدة في كمبوند",
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _hasCompoundUnit ? "نعم" : "لا",
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: _hasCompoundUnit ? Colors.greenAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      label: "امتلاك سيارة حديثة",
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          _hasModernCar ? "نعم" : "لا",
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: _hasModernCar ? Colors.greenAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(
                    child: _buildFormField(
                      label: "اسم المندوب المسؤول",
                      child: Builder(
                        builder: (context) {
                          final empState = ref.watch(employeesProvider);
                          final companyStaff = empState.employees
                              .where((e) =>
                                  e.isConfirmed &&
                                  (e.role == 'admin' ||
                                      e.role == 'manager' ||
                                      e.role == 'company_employee'))
                              .toList();
                          return DropdownButtonFormField<String>(
                            initialValue: companyStaff.any((e) =>
                                    e.fullName == _repNameController.text)
                                ? _repNameController.text
                                : null,
                            dropdownColor: TfcColors.surfaceContainer,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: "اختر المندوب المسؤول",
                              prefixIcon: Icon(Icons.person_search,
                                  color: TfcColors.outline),
                            ),
                            items: companyStaff
                                .map((e) => DropdownMenuItem(
                                      value: e.fullName,
                                      child: Text(e.fullName,
                                          textDirection: TextDirection.rtl),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _repNameController.text = v);
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      label: "تاريخ تقديم الطلب",
                      child: TextFormField(
                        controller: _requestDateController,
                        textAlign: TextAlign.right,
                        readOnly: true,
                        decoration: const InputDecoration(
                          hintText: "YYYY-MM-DD",
                          prefixIcon: Icon(Icons.calendar_today,
                              color: TfcColors.primary, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        )),
        const SizedBox(height: 24),

        // Files Upload Card
        InteractiveGlowWidget(
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    const Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Icon(Icons.upload_file, color: TfcColors.secondary),
                        SizedBox(width: 12),
                        Text("رفع المستندات الائتمانية",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        DocumentUploadHelper.showUploadDialog(
                          context,
                          onUploadComplete: (name, url) {
                            setState(() {
                              _uploadedDocuments.add(
                                ClientDocumentModel(
                                  id: "doc-${DateTime.now().millisecondsSinceEpoch}",
                                  documentName: name,
                                  documentUrl: url,
                                  status: "pending",
                                ),
                              );
                            });
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TfcColors.primary.withValues(alpha: 0.1),
                        foregroundColor: TfcColors.primary,
                        side: const BorderSide(color: TfcColors.primary, width: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text("إضافة مستند", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_uploadedDocuments.isEmpty)
                  const Text("لا توجد مستندات مدرجة",
                      style: TextStyle(color: TfcColors.outline, fontSize: 12),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl)
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _uploadedDocuments.length,
                    itemBuilder: (context, idx) {
                      final d = _uploadedDocuments[idx];
                      final isUploaded = d.documentUrl.isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isUploaded
                                ? TfcColors.primary.withValues(alpha: 0.03)
                                : Colors.white.withValues(alpha: 0.01),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUploaded
                                  ? TfcColors.primary.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              // Doc info
                              Expanded(
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Icon(
                                      isUploaded ? Icons.cloud_done : Icons.cloud_off,
                                      color: isUploaded ? TfcColors.primary : TfcColors.outline,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        d.documentName,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: isUploaded ? FontWeight.bold : FontWeight.normal,
                                          color: isUploaded ? Colors.white : TfcColors.onSurfaceVariant,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        textDirection: TextDirection.rtl,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Doc Actions
                              Row(
                                children: [
                                  // Upload Button
                                  ElevatedButton(
                                    onPressed: () {
                                      DocumentUploadHelper.showUploadDialog(
                                        context,
                                        initialName: d.documentName,
                                        onUploadComplete: (name, url) {
                                          setState(() {
                                            _uploadedDocuments[idx] = ClientDocumentModel(
                                              id: d.id,
                                              documentName: name,
                                              documentUrl: url,
                                              status: "pending",
                                            );
                                          });
                                        },
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isUploaded ? Colors.transparent : TfcColors.secondary.withValues(alpha: 0.1),
                                      foregroundColor: isUploaded ? Colors.white70 : TfcColors.secondary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        side: BorderSide(
                                          color: isUploaded ? Colors.white24 : TfcColors.secondary,
                                          width: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      isUploaded ? "تغيير الملف" : "رفع الملف",
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Delete Button
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _uploadedDocuments.removeAt(idx);
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: "حذف المستند",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCreditSummaryCard() {
    final hasData = _loansList.isNotEmpty || _cardsList.isNotEmpty;
    if (!hasData) return const SizedBox.shrink();

    Color dbrColor = _dbrPercent > 50
        ? const Color(0xFFFF6B6B)
        : (_dbrPercent > 35 ? Colors.amberAccent : TfcColors.primary);

    return InteractiveGlowWidget(
      child: GlassCard(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TfcColors.primary.withAlpha((0.15 * 255).toInt()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.analytics_outlined,
                    color: TfcColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text("ملخص الالتزامات الائتمانية",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _buildSummaryTile(
                  "إجمالي أقساط القروض",
                  _totalLoanInstallments.toStringAsFixed(2),
                  Icons.account_balance,
                  TfcColors.secondary),
              _buildSummaryTile(
                  "إجمالي 5% البطاقات",
                  _totalCardFivePercent.toStringAsFixed(2),
                  Icons.credit_card,
                  const Color(0xFF7B68EE)),
              _buildSummaryTile(
                  "إجمالي الالتزامات بـ 5%",
                  _totalObligationsWithFivePercent.toStringAsFixed(2),
                  Icons.account_balance_wallet,
                  const Color(0xFF8E44AD)),
              _buildSummaryTile(
                  "الحد الأعلى للبطاقات",
                  _totalCardHighest.toStringAsFixed(2),
                  Icons.trending_up,
                  Colors.amberAccent),
              _buildSummaryTile(
                  "إجمالي الالتزامات",
                  _totalMonthlyObligations.toStringAsFixed(2),
                  Icons.payments,
                  const Color(0xFFFF6B6B)),
              _buildSummaryTile(
                  "حد الـ DBR المسموح (50%)",
                  (_totalSalary / 2).toStringAsFixed(2),
                  Icons.monetization_on,
                  TfcColors.primary),
              _buildSummaryTile("نسبة عبء الدين DBR",
                  "${_dbrPercent.toStringAsFixed(1)}%", Icons.speed, dbrColor),
              _buildSummaryTile(
                  "المتاح لقسط جديد",
                  _availableForLoan.toStringAsFixed(2),
                  Icons.savings,
                  _availableForLoan > 0
                      ? TfcColors.primary
                      : const Color(0xFFFF6B6B)),
            ],
          ),
          if (_totalSalary > 0 && _dbrPercent > 0) ...[
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "مؤشر عبء الدين (DBR): ${_dbrPercent.toStringAsFixed(1)}% من الحد الأقصى 50%",
                  style: TextStyle(fontSize: 12, color: dbrColor),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (_dbrPercent / 100).clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor:
                        Colors.white.withAlpha((0.08 * 255).toInt()),
                    valueColor: AlwaysStoppedAnimation<Color>(dbrColor),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ));
  }

  Widget _buildSummaryTile(
      String label, String value, IconData icon, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).toInt()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha((0.2 * 255).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 11, color: color),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 13,
              color: TfcColors.onSurfaceVariant,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
