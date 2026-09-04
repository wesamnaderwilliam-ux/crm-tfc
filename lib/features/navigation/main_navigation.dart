import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/widgets/interactive_hover_card.dart';
import '../../core/utils/web_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/employees_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/prospects_provider.dart';
import '../../providers/banks_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../client/new_client_screen.dart';
import '../client/client_details_screen.dart';
import '../client/all_distributions_screen.dart';
import '../client/all_operations_screen.dart';
import '../client/invoices_screen.dart';
import '../prospects/prospects_screen.dart';
import '../accounts/accounts_screen.dart';
import '../banks/banks_screen.dart';
import '../settings/settings_screen.dart';
import '../employees/employees_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../client/credit_calculator_screen.dart';
import '../reports/reports_screen.dart';

class _NavHistoryEntry {
  final int index;
  final String? clientId;
  final String? aiClientId;
  final bool showNewClientForm;

  _NavHistoryEntry({
    required this.index,
    this.clientId,
    this.aiClientId,
    this.showNewClientForm = false,
  });

  Map<String, dynamic> toJson() => {
    'index': index,
    'clientId': clientId,
    'aiClientId': aiClientId,
    'showNewClientForm': showNewClientForm,
  };

  factory _NavHistoryEntry.fromJson(Map<String, dynamic> json) => _NavHistoryEntry(
    index: json['index'] as int? ?? 0,
    clientId: json['clientId'] as String?,
    aiClientId: json['aiClientId'] as String?,
    showNewClientForm: json['showNewClientForm'] as bool? ?? false,
  );

  bool matches(int idx, String? cId, String? aiId, bool isNew) {
    return index == idx && clientId == cId && aiClientId == aiId && showNewClientForm == isNew;
  }
}

class MainNavigationWrapper extends ConsumerStatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  int _selectedIndex = 0;
  String? _selectedClientId;
  String? _aiClientId;
  bool _showNewClientForm = false;
  bool _headerVisible = true; // Toggle header visibility

  // Navigation History Stack for "Back" button across ANY section/details/forms
  final List<_NavHistoryEntry> _historyStack = [
    _NavHistoryEntry(index: 0)
  ];

  bool _isRestoringState = false;

  @override
  void initState() {
    super.initState();
    _restoreSavedState();
    listenToPopState(() {
      if (mounted) {
        _restoreStateFromUrlHash();
      }
    });
  }

  // ── Persistent & URL State Sync ───────────────────────────────────────────
  Future<void> _restoreSavedState() async {
    _isRestoringState = true;
    try {
      // 1. First priority: URL hash (e.g. #tab=2&client=123)
      final hash = getUrlHash();
      if (hash.isNotEmpty) {
        if (_applyHashState(hash)) {
          _isRestoringState = false;
          return;
        }
      }

      // 2. Second priority: Local storage (SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final savedIdx = prefs.getInt('nav_selected_index');
      final savedClientId = prefs.getString('nav_selected_client_id');
      final savedAiId = prefs.getString('nav_selected_ai_id');
      final savedNewClient = prefs.getBool('nav_show_new_client') ?? false;

      if (savedIdx != null) {
        setState(() {
          _selectedIndex = savedIdx;
          _selectedClientId = (savedClientId != null && savedClientId.isNotEmpty) ? savedClientId : null;
          _aiClientId = (savedAiId != null && savedAiId.isNotEmpty) ? savedAiId : null;
          _showNewClientForm = savedNewClient;
          _historyStack.clear();
          _historyStack.add(_NavHistoryEntry(
            index: _selectedIndex,
            clientId: _selectedClientId,
            aiClientId: _aiClientId,
            showNewClientForm: _showNewClientForm,
          ));
        });
        _syncStateToStorageAndUrl();
      }
    } catch (_) {
    } finally {
      _isRestoringState = false;
    }
  }

  void _restoreStateFromUrlHash() {
    final hash = getUrlHash();
    if (hash.isNotEmpty) {
      _applyHashState(hash);
    }
  }

  bool _applyHashState(String hash) {
    try {
      final uri = Uri.parse('app://tfc?$hash');
      final tabParam = uri.queryParameters['tab'];
      final clientParam = uri.queryParameters['client'];
      final aiParam = uri.queryParameters['ai'];
      final newParam = uri.queryParameters['new'];

      if (tabParam != null) {
        final parsedIdx = int.tryParse(tabParam) ?? 0;
        final cId = (clientParam != null && clientParam.isNotEmpty) ? clientParam : null;
        final aiId = (aiParam != null && aiParam.isNotEmpty) ? aiParam : null;
        final isNew = newParam == '1' || newParam == 'true';

        setState(() {
          _selectedIndex = parsedIdx;
          _selectedClientId = cId;
          _aiClientId = aiId;
          _showNewClientForm = isNew;

          if (_historyStack.isEmpty || !_historyStack.last.matches(parsedIdx, cId, aiId, isNew)) {
            _historyStack.add(_NavHistoryEntry(
              index: parsedIdx,
              clientId: cId,
              aiClientId: aiId,
              showNewClientForm: isNew,
            ));
          }
        });
        _saveToPrefs();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _syncStateToStorageAndUrl() {
    if (_isRestoringState) return;
    _saveToPrefs();

    // Build URL hash: e.g. tab=2&client=XYZ
    final params = <String>[];
    params.add('tab=$_selectedIndex');
    if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
      params.add('client=${Uri.encodeComponent(_selectedClientId!)}');
    }
    if (_aiClientId != null && _aiClientId!.isNotEmpty) {
      params.add('ai=${Uri.encodeComponent(_aiClientId!)}');
    }
    if (_showNewClientForm) {
      params.add('new=1');
    }

    setUrlHash(params.join('&'));
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('nav_selected_index', _selectedIndex);
      if (_selectedClientId != null && _selectedClientId!.isNotEmpty) {
        await prefs.setString('nav_selected_client_id', _selectedClientId!);
      } else {
        await prefs.remove('nav_selected_client_id');
      }
      if (_aiClientId != null && _aiClientId!.isNotEmpty) {
        await prefs.setString('nav_selected_ai_id', _aiClientId!);
      } else {
        await prefs.remove('nav_selected_ai_id');
      }
      await prefs.setBool('nav_show_new_client', _showNewClientForm);
    } catch (_) {}
  }

  void _pushHistory(int index, {String? clientId, String? aiClientId, bool showNew = false}) {
    if (_historyStack.isEmpty || !_historyStack.last.matches(index, clientId, aiClientId, showNew)) {
      _historyStack.add(_NavHistoryEntry(
        index: index,
        clientId: clientId,
        aiClientId: aiClientId,
        showNewClientForm: showNew,
      ));
    }
  }

  void selectClient(String id) {
    setState(() {
      _selectedClientId = id.isEmpty ? null : id;
      _showNewClientForm = false;
      _aiClientId = null;
      _pushHistory(_selectedIndex, clientId: _selectedClientId);
    });
    _syncStateToStorageAndUrl();
  }

  void selectAiClient(String id) {
    setState(() {
      _selectedClientId = null;
      _aiClientId = id.isEmpty ? null : id;
      _showNewClientForm = false;
      _pushHistory(_selectedIndex, aiClientId: _aiClientId);
    });
    _syncStateToStorageAndUrl();
  }

  void openNewClientForm() {
    setState(() {
      _showNewClientForm = true;
      _selectedClientId = null;
      _aiClientId = null;
      _pushHistory(_selectedIndex, showNew: true);
    });
    _syncStateToStorageAndUrl();
  }

  void navigateToTab(int index, {bool isBack = false}) {
    setState(() {
      _selectedClientId = null;
      _aiClientId = null;
      _showNewClientForm = false;
      _selectedIndex = index;
      if (!isBack) {
        _pushHistory(index);
      }
    });
    _syncStateToStorageAndUrl();
  }

  void _goBack() {
    if (_historyStack.length > 1) {
      setState(() {
        _historyStack.removeLast();
        final prev = _historyStack.last;
        _selectedIndex = prev.index;
        _selectedClientId = prev.clientId;
        _aiClientId = prev.aiClientId;
        _showNewClientForm = prev.showNewClientForm;
      });
      _syncStateToStorageAndUrl();
    } else {
      // If stack is at root, go to dashboard / home
      navigateToTab(0);
    }
  }

  void _goHome() {
    setState(() {
      _historyStack.clear();
      _selectedIndex = 0;
      _selectedClientId = null;
      _aiClientId = null;
      _showNewClientForm = false;
      _historyStack.add(_NavHistoryEntry(index: 0));
    });
    _syncStateToStorageAndUrl();
  }

  Map<String, bool> _resolveEffectivePermissions(
      String userId, String role, Map<String, Map<String, bool>> customPermsState) {
    if (role == 'admin') {
      return EmployeePermissionKeys.defaultsForRole('admin');
    }
    final custom = customPermsState[userId] ?? {};
    return EmployeePermissionKeys.resolve(role, custom);
  }

  void _syncCurrentUserPermissions(String? userId, String role) {
    if (userId == null) return;
    final empState = ref.read(employeesProvider);
    final userEmail = ref.read(authProvider).user?.email;
    final emps = empState.employees.where((e) => e.id == userId || e.email == userEmail);
    if (emps.isNotEmpty) {
      final currentEmp = emps.first;
      if (currentEmp.id.isNotEmpty && currentEmp.customPermissions != null) {
        final inMemory = ref.read(employeeCustomPermissionsProvider);
        if (!inMemory.containsKey(currentEmp.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(employeeCustomPermissionsProvider.notifier).loadForEmployee(
                  currentEmp.id,
                  currentEmp.customPermissions!,
                );
          });
        }
      }
    }
  }

  // Popover Main Menu Modal
  void _openMainMenuModal(BuildContext context, List<_NavItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF16162A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF6C5CE7), width: 2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.apps_rounded, color: Color(0xFFA29BFE), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "THE FUTURE CLUB 🧭",
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "اختر قسم التصفح والانتقال الأنسب لك",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedIndex == index && !_showNewClientForm;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InteractiveHoverCard(
                        onTap: () {
                          Navigator.pop(ctx);
                          navigateToTab(index);
                        },
                        glowColor: const Color(0xFF6C5CE7),
                        backgroundColor: isSelected
                            ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                            : const Color(0xFF1E1E38).withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected ? const Color(0xFF00CEC9) : Colors.white70,
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF00CEC9), size: 20)
                            else
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);
    final rolePerms = ref.watch(permissionsProvider)[authState.role] ??
        RolePermissions.fromDefaults(authState.role);

    final isAdmin = authState.role == 'admin';
    final userId = authState.user?.id ?? '';
    final perms = _resolveEffectivePermissions(userId, authState.role, customPermsState);

    _syncCurrentUserPermissions(authState.user?.id, authState.role);

    final bool isBankEmployee = authState.role == 'bank_employee';

    final List<_NavItem> navItems = [];

    if (isBankEmployee) {
      // 1. تفاصيل وإدارة العملاء (العملاء الموزعين عليه فقط وبدون هاتف)
      navItems.add(_NavItem(
        label: 'تفاصيل وإدارة العملاء',
        icon: Icons.person_search_rounded,
        screen: ClientDetailsScreen(
          key: ValueKey(_selectedClientId ?? 'none'),
          clientId: _selectedClientId,
          onBack: _goBack,
          onClientSelected: selectClient,
          onViewAiAnalysis: null,
          onOpenNewClientForm: null,
          bankEmployeeMode: true,
        ),
      ));

      // 2. التوزيعات العامة (توزيعاتي الخاصة)
      navItems.add(_NavItem(
        label: 'التوزيعات العامة',
        icon: Icons.account_tree_rounded,
        screen: AllDistributionsScreen(
          onViewClient: selectClient,
          bankEmployeeMode: true,
        ),
      ));

      // 3. العمليات (عملياتي الخاصة)
      navItems.add(_NavItem(
        label: 'العمليات',
        icon: Icons.settings_suggest_rounded,
        screen: AllOperationsScreen(
          onViewClient: selectClient,
          bankEmployeeMode: true,
        ),
      ));

      // 4. دليل البنوك والبرامج (كما هو)
      navItems.add(_NavItem(
        label: 'دليل البنوك والبرامج',
        icon: Icons.account_balance_rounded,
        screen: const BanksScreen(),
      ));

    } else {
      // ─── STANDARD MENU FOR ADMIN / MANAGER / COMPANY_EMPLOYEE ──────────────
      // Dashboard (0)
      if (isAdmin || (perms[EmployeePermissionKeys.viewDashboard] ?? true)) {
        navItems.add(_NavItem(
          label: 'لوحة التحكم الرئيسية',
          icon: Icons.analytics_rounded,
          screen: DashboardScreen(onViewClient: selectClient),
        ));
      }

      // Prospects (1)
      final bool showProspects = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
      if (showProspects) {
        navItems.add(_NavItem(
          label: 'العملاء المحتملين',
          icon: Icons.recent_actors_rounded,
          screen: ProspectsScreen(
            onNavigateToClientDetails: (convertedClientId) {
              selectClient(convertedClientId);
            },
          ),
        ));
      }

      // Client Details (2)
      final bool showClientDetails = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
      if (showClientDetails) {
        navItems.add(_NavItem(
          label: 'تفاصيل وإدارة العملاء',
          icon: Icons.person_search_rounded,
          screen: _showNewClientForm
              ? NewClientScreen(onComplete: () {
                  _goBack();
                })
              : ClientDetailsScreen(
                  key: ValueKey(_selectedClientId ?? 'none'),
                  clientId: _selectedClientId,
                  onBack: _goBack,
                  onClientSelected: selectClient,
                  onViewAiAnalysis: selectAiClient,
                  onOpenNewClientForm: openNewClientForm,
                ),
        ));
      }

      // All Distributions
      if (isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true)) {
        navItems.add(_NavItem(
          label: 'التوزيعات العامة',
          icon: Icons.account_tree_rounded,
          screen: AllDistributionsScreen(onViewClient: selectClient),
        ));
      }

      // All Operations
      if (isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true)) {
        navItems.add(_NavItem(
          label: 'العمليات العامة',
          icon: Icons.settings_suggest_rounded,
          screen: AllOperationsScreen(onViewClient: selectClient),
        ));
      }

      // Invoices - Admin
      if (isAdmin) {
        navItems.add(_NavItem(
          label: 'الفواتير والماليات',
          icon: Icons.receipt_long_rounded,
          screen: InvoicesScreen(onViewClient: selectClient),
        ));
      }

      // Accounts - Admin
      if (isAdmin) {
        navItems.add(_NavItem(
          label: 'الحسابات والميزانية',
          icon: Icons.account_balance_wallet_rounded,
          screen: AccountsScreen(onViewClient: selectClient),
        ));

        // Reports Center - Admin Only
        navItems.add(_NavItem(
          label: 'التقارير والإحصائيات',
          icon: Icons.analytics_rounded,
          screen: ReportsScreen(onViewClient: selectClient),
        ));
      }

      // Banks
      if (isAdmin || (perms[EmployeePermissionKeys.viewBanks] ?? true)) {
        navItems.add(_NavItem(
          label: 'دليل البنوك والبرامج',
          icon: Icons.account_balance_rounded,
          screen: const BanksScreen(),
        ));
      }

      // AI Assistant
      navItems.add(_NavItem(
        label: 'المساعد الذكي (AI)',
        icon: Icons.psychology_rounded,
        screen: AiAssistantScreen(initialClientId: _aiClientId),
      ));

      // Employees
      if (isAdmin || (perms[EmployeePermissionKeys.viewEmployees] ?? false)) {
        navItems.add(_NavItem(
          label: 'موظفي الشركة',
          icon: Icons.groups_rounded,
          screen: const EmployeesScreen(),
        ));
      }

      // Settings
      if (isAdmin || rolePerms.canManageRoles || (perms[EmployeePermissionKeys.viewSettings] ?? false)) {
        navItems.add(_NavItem(
          label: 'الإعدادات والصلاحيات',
          icon: Icons.settings_rounded,
          screen: const SettingsScreen(),
        ));
      }
    }

    // Ensure index matches if navigating to client details
    if (_selectedClientId != null || _showNewClientForm) {
      final detailsIdx = navItems.indexWhere((item) => item.label == 'تفاصيل وإدارة العملاء');
      if (detailsIdx != -1 && _selectedIndex != detailsIdx) {
        _selectedIndex = detailsIdx;
      }
    }

    // Ensure index matches if navigating to AI assistant
    if (_aiClientId != null) {
      final aiIdx = navItems.indexWhere((item) => item.label == 'المساعد الذكي (AI)');
      if (aiIdx != -1 && _selectedIndex != aiIdx) {
        _selectedIndex = aiIdx;
      }
    }

    if (_selectedIndex >= navItems.length) {
      _selectedIndex = navItems.isNotEmpty ? navItems.length - 1 : 0;
    }

    final currentNavItem = navItems.isNotEmpty ? navItems[_selectedIndex] : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _goBack();
      },
      child: LayoutBuilder(
        builder: (context, screenConstraints) {
          final isMobile = screenConstraints.maxWidth < 700;

          return Scaffold(
            backgroundColor: Colors.transparent,
            bottomNavigationBar: isMobile
                ? Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16162A).withValues(alpha: 0.96),
                      border: const Border(top: BorderSide(color: Colors.white10)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Home Button
                          IconButton(
                            icon: const Icon(Icons.home_rounded),
                            color: _selectedIndex == 0 ? const Color(0xFF00CEC9) : Colors.white60,
                            tooltip: "الرئيسية",
                            onPressed: _goHome,
                          ),
                          // Back Button
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: Colors.amberAccent,
                            tooltip: "رجوع",
                            onPressed: _goBack,
                          ),
                          // Quick Main Menu Button (Elevated)
                          InkWell(
                            onTap: () => _openMainMenuModal(context, navItems),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.menu_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 6),
                                  Text(
                                    "الأقسام",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Calculator Button
                          IconButton(
                            icon: const Icon(Icons.calculate_rounded),
                            color: Colors.amberAccent,
                            tooltip: "حاسبة الائتمان",
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: const Color(0xFF16162A),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (ctx) => DraggableScrollableSheet(
                                  initialChildSize: 0.85,
                                  minChildSize: 0.5,
                                  maxChildSize: 0.95,
                                  expand: false,
                                  builder: (_, scrollController) => SingleChildScrollView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(16),
                                    child: const CreditCalculatorScreen(),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Refresh Button
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            color: Colors.greenAccent,
                            tooltip: "تحديث",
                            onPressed: () {
                              final authState = ref.read(authProvider);
                              ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: authState.bankEmployeeId);
                              ref.read(prospectsProvider.notifier).fetchProspects();
                              ref.read(employeesProvider.notifier).fetchEmployees();
                              ref.invalidate(allBanksProvider);
                              ref.invalidate(coreProgramsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
            body: SafeArea(
              child: Column(
                children: [
                  // Universal Top Header
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16162A).withValues(alpha: 0.95),
                      border: const Border(bottom: BorderSide(color: Colors.white10)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _headerVisible
                        // ─── Full Header ─────────────────────────────────────
                        ? Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 16,
                              vertical: isMobile ? 8 : 10,
                            ),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                // Logo
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: isMobile ? 26 : 30,
                                    height: isMobile ? 26 : 30,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Page title
                                Expanded(
                                  child: Text(
                                    _showNewClientForm
                                        ? "طلب تمويل جديد 📝"
                                        : (currentNavItem?.label ?? "TFC FINANCIAL CONSULTING"),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 13 : 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ),
                                const SizedBox(width: 6),

                                // On Desktop: Show full menu button and actions
                                if (!isMobile) ...[
                                  // Popover Main Menu
                                  InteractiveHoverCard(
                                    onTap: () => _openMainMenuModal(context, navItems),
                                    glowColor: const Color(0xFF6C5CE7),
                                    backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.menu_rounded, color: Color(0xFFA29BFE), size: 22),
                                        SizedBox(width: 8),
                                        Text(
                                          "القائمة الرئيسية",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Back button
                                  InteractiveHoverCard(
                                    onTap: _goBack,
                                    glowColor: Colors.amber,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    padding: const EdgeInsets.all(8),
                                    child: const Tooltip(
                                      message: "عودة للخلف",
                                      child: Icon(Icons.arrow_back_rounded, color: Colors.amber, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Home button
                                  InteractiveHoverCard(
                                    onTap: _goHome,
                                    glowColor: Colors.cyan,
                                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    padding: const EdgeInsets.all(8),
                                    child: const Tooltip(
                                      message: "الصفحة الرئيسية",
                                      child: Icon(Icons.home_rounded, color: Colors.cyan, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Credit Calculator
                                  InteractiveHoverCard(
                                    onTap: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: const Color(0xFF16162A),
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                        ),
                                        builder: (ctx) => DraggableScrollableSheet(
                                          initialChildSize: 0.85,
                                          minChildSize: 0.5,
                                          maxChildSize: 0.95,
                                          expand: false,
                                          builder: (_, scrollController) => SingleChildScrollView(
                                            controller: scrollController,
                                            padding: const EdgeInsets.all(16),
                                            child: const CreditCalculatorScreen(),
                                          ),
                                        ),
                                      );
                                    },
                                    glowColor: Colors.amberAccent,
                                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    padding: const EdgeInsets.all(8),
                                    child: const Tooltip(
                                      message: "حاسبة الدخل الائتماني 🧮",
                                      child: Icon(Icons.calculate_rounded, color: Colors.amberAccent, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Global Refresh
                                  InteractiveHoverCard(
                                    onTap: () {
                                      final authState = ref.read(authProvider);
                                      ref.read(clientProvider.notifier).fetchClients(bankEmployeeId: authState.bankEmployeeId);
                                      ref.read(prospectsProvider.notifier).fetchProspects();
                                      ref.read(employeesProvider.notifier).fetchEmployees();
                                      ref.invalidate(allBanksProvider);
                                      ref.invalidate(coreProgramsProvider);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text("جاري تحديث جميع البيانات... ✅", textAlign: TextAlign.right),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Color(0xFF00CEC9),
                                        ),
                                      );
                                    },
                                    glowColor: Colors.greenAccent,
                                    backgroundColor: Colors.greenAccent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    padding: const EdgeInsets.all(8),
                                    child: const Tooltip(
                                      message: "تحديث البيانات 🔄",
                                      child: Icon(Icons.refresh_rounded, color: Colors.greenAccent, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Collapse Header Button
                                  Tooltip(
                                    message: "إخفاء الشريط العلوي",
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => setState(() => _headerVisible = false),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white38, size: 18),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],

                                // User Avatar or Name tag on Mobile
                                if (isMobile) ...[
                                  IconButton(
                                    icon: const Icon(Icons.menu_open_rounded, color: Color(0xFFA29BFE), size: 22),
                                    tooltip: "القائمة",
                                    onPressed: () => _openMainMenuModal(context, navItems),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 10),
                                ],

                                // Logout
                                IconButton(
                                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                                  tooltip: "تسجيل الخروج",
                                  padding: isMobile ? EdgeInsets.zero : const EdgeInsets.all(8),
                                  constraints: isMobile ? const BoxConstraints() : null,
                                  onPressed: () {
                                    ref.read(authProvider.notifier).signOut();
                                  },
                                ),
                              ],
                            ),
                          )
                        // ─── Collapsed Strip ──────────────────────────────────
                  : InkWell(
                      onTap: () => setState(() => _headerVisible = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                          border: Border(bottom: BorderSide(color: const Color(0xFF6C5CE7).withValues(alpha: 0.5))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.touch_app_rounded, color: Color(0xFF00CEC9), size: 18),
                            SizedBox(width: 8),
                            Text(
                              "اضغط هنا لإظهار الشريط العلوي والقائمة الرئيسية ⬇️",
                              style: TextStyle(
                                color: Color(0xFF00CEC9),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Active Screen Body (Item 1: Fully Responsive Container)
            Expanded(
              child: currentNavItem != null
                  ? currentNavItem.screen
                  : const Center(
                      child: Text(
                        "لا تملك صلاحيات لعرض هذا القسم",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  },
),
);
}
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;

  _NavItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}
